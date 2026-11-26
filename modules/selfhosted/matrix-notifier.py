#!/usr/bin/env python3
"""Forward Grafana alerts, successful Comin deployments, and Kubernetes pod changes to Matrix."""

import hashlib
from datetime import datetime
from html import escape
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import logging
import os
from pathlib import Path
import ssl
import sys
import threading
import time
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


MATRIX_URL = "https://matrix.org/_matrix/client/v3/rooms/"
PROMETHEUS_URL = "http://127.0.0.1:9090/api/v1/query"
KUBERNETES_PODS_URL = "https://127.0.0.1:6443/api/v1/pods"
# A container that runs this long after its last restart is stable again.
POD_STABLE_SECONDS = 600
# A pod that has not started a container after this time is reported.
POD_START_SECONDS = 300


def request_json(url, payload=None, headers=None, method=None, context=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(url, data=data, headers=headers or {}, method=method)
    with urlopen(request, timeout=15, context=context) as response:
        return json.load(response)


def workload_of(pod):
    """Return the owner kind and a name that stays the same when the pod is replaced."""
    metadata = pod["metadata"]
    owner = (metadata.get("ownerReferences") or [{}])[0]
    name = owner.get("name") or metadata["name"]
    if owner.get("kind") == "ReplicaSet":
        # A Deployment names its ReplicaSets "<deployment>-<pod-template-hash>".
        name = name.removesuffix("-" + metadata.get("labels", {}).get("pod-template-hash", ""))
    return owner.get("kind"), f"{metadata['namespace']}/{name}"


def age(timestamp, now):
    return now - datetime.fromisoformat(timestamp).timestamp()


def pod_changes(known, pods, now):
    """Compare the pods with the known state. Return the messages and the new state.

    The state holds, for each workload, the images of its containers and the restart
    state of each container in each pod. It also holds the pods that were reported
    as not started.
    """
    workloads = {}
    stuck = []
    lines = {}
    for pod in pods:
        kind, workload = workload_of(pod)
        if kind == "Job":
            # Each run of a Job is a new pod by design.
            continue
        uid = pod["metadata"]["uid"]
        pod_status = pod.get("status", {})
        statuses = {status["name"]: status for status in pod_status.get("containerStatuses", [])}
        if not any(
            status["restartCount"] or "waiting" not in status.get("state", {"waiting": {}})
            for status in statuses.values()
        ):
            # No container has started yet, for example while the image is pulled or
            # when the pull fails. Report the image only when the pod runs it.
            if uid in known["stuck"]:
                stuck.append(uid)
            elif age(pod["metadata"]["creationTimestamp"], now) >= POD_START_SECONDS:
                reasons = [
                    status["state"]["waiting"].get("reason")
                    for status in pod_status.get("initContainerStatuses", []) + list(statuses.values())
                    if "waiting" in status.get("state", {})
                ]
                lines[f"{workload}: not started ({next(filter(None, reasons), pod_status.get('phase', 'unknown'))})"] = None
                stuck.append(uid)
            continue
        entry = workloads.setdefault(workload, {"images": {}, "pods": {}})
        restarts = entry["pods"][uid] = {}
        before = known["workloads"].get(workload)
        containers = pod["spec"]["containers"]
        if before is None:
            lines[f"{workload}: started ({', '.join(container['image'] for container in containers)})"] = None
        for container in containers:
            name, image = container["name"], container["image"]
            status = statuses.get(name, {})
            count = status.get("restartCount", 0)
            images = entry["images"].setdefault(name, [])
            if image not in images:
                images.append(image)
            label = workload if len(containers) == 1 else f"{workload} ({name})"
            old = (before or {"pods": {}})["pods"].get(uid, {}).get(name)
            # "loop" counts the restarts that were not reported. None means stable.
            loop = old["loop"] if old else None
            if before is None:
                pass
            elif image not in before["images"].get(name, []):
                lines[f"{label}: image {' / '.join(before['images'].get(name, [])) or 'none'} -> {image}"] = None
            elif old is None:
                lines[f"{label}: new pod"] = None
            elif count > old["count"]:
                if loop is None:
                    reason = status.get("lastState", {}).get("terminated", {}).get("reason", "unknown reason")
                    lines[f"{label}: restarted ({old['count']} -> {count}, {reason})"] = None
                    loop = 0
                else:
                    # Report only the first restart of a crash loop.
                    loop += 1
            elif loop is not None and "running" in status.get("state", {}):
                finished = status.get("lastState", {}).get("terminated", {}).get("finishedAt")
                if finished is None or age(finished, now) >= POD_STABLE_SECONDS:
                    if loop:
                        lines[f"{label}: stable again after {loop + 1} restarts"] = None
                    loop = None
            restarts[name] = {"count": count, "loop": loop}
    for workload, entry in known["workloads"].items():
        # A workload can have no pod for a moment while its pod is replaced.
        # Keep its images, so the new pod is compared with them.
        workloads.setdefault(workload, {"images": entry["images"], "pods": {}})
    return list(lines), {"workloads": workloads, "stuck": stuck}


class Notifier:
    def __init__(self, token_file, room_file, state_dir, hosts, kubernetes_token_file=None, kubernetes_ca_file=None):
        timestamp = f'comin_last_successful_deployment_timestamp_seconds{{job="node",host=~"{hosts}"}}'
        # Add the package changes of the deployment for the hosts that report them.
        self.deployment_query = (
            f"{timestamp} * on(host, instance) group_left(changes) comin_last_successful_deployment_changes_info"
            f" or on(host, instance) {timestamp}"
        )
        self.token = Path(token_file).read_text(encoding="utf-8").strip()
        if not self.token:
            raise ValueError("Matrix token is empty")
        self.room_id = Path(room_file).read_text(encoding="utf-8").strip()
        if not self.room_id.startswith("!") or any(character.isspace() for character in self.room_id):
            raise ValueError("Invalid Matrix room ID")
        self.state_file = Path(state_dir) / "last-deployments.json"
        if self.state_file.exists():
            self.state = json.loads(self.state_file.read_text(encoding="utf-8"))
        else:
            # Do not notify about deployments that preceded the first installation.
            self.state = {"baseline": int(time.time()), "last": {}}
        if not isinstance(self.state.get("baseline"), int) or not isinstance(self.state.get("last"), dict):
            raise ValueError("Invalid deployment state")
        self.pods_file = Path(state_dir) / "pods.json"
        self.kubernetes_token = None
        if kubernetes_token_file is not None:
            self.kubernetes_token = Path(kubernetes_token_file).read_text(encoding="utf-8").strip()
            if not self.kubernetes_token:
                raise ValueError("Kubernetes token is empty")
            self.kubernetes_tls = ssl.create_default_context(cafile=kubernetes_ca_file)

    def send(self, text, transaction_id, formatted_html=None):
        url = (
            MATRIX_URL
            + quote(self.room_id, safe="")
            + "/send/m.room.message/"
            + quote(transaction_id, safe="")
        )
        content = {"msgtype": "m.text", "body": text}
        if formatted_html is not None:
            content.update({"format": "org.matrix.custom.html", "formatted_body": formatted_html})
        response = request_json(
            url,
            content,
            {"Authorization": "Bearer " + self.token, "Content-Type": "application/json"},
            method="PUT",
        )
        if not response.get("event_id"):
            raise ValueError("Matrix did not confirm the message")

    def save_state(self):
        temporary = self.state_file.with_suffix(".tmp")
        temporary.write_text(json.dumps(self.state, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(temporary, self.state_file)

    def poll_deployments(self):
        url = PROMETHEUS_URL + "?" + urlencode({"query": self.deployment_query})
        result = request_json(url)
        if result.get("status") != "success":
            raise ValueError("Prometheus query failed")
        for sample in result["data"]["result"]:
            host = sample["metric"]["host"]
            timestamp = int(float(sample["value"][1]))
            if timestamp <= 0:
                continue
            previous = self.state["last"].get(host)
            if previous is not None and timestamp <= previous:
                continue
            if previous is not None or timestamp > self.state["baseline"]:
                changes = sample["metric"].get("changes", "")
                self.send(f"{host} completed a Comin deployment.\n{changes}".rstrip(), f"comin-{host}-{timestamp}")
                logging.info("Notified successful Comin deployment on %s", host)
            self.state["last"][host] = timestamp
            self.save_state()

    def poll_pods(self):
        result = request_json(
            KUBERNETES_PODS_URL,
            headers={"Authorization": "Bearer " + self.kubernetes_token},
            context=self.kubernetes_tls,
        )
        known = json.loads(self.pods_file.read_text(encoding="utf-8")) if self.pods_file.exists() else {}
        if "workloads" in known:
            lines, current = pod_changes(known, result["items"], time.time())
        else:
            # No state, or the state of the first version of this poll. Do not
            # notify about the pods that preceded this state.
            lines, current = pod_changes({"workloads": {}, "stuck": []}, result["items"], time.time())
            lines = []
        serialized = json.dumps(current, sort_keys=True)
        if lines:
            # The state identifies the message: a retry reuses the transaction ID,
            # and the same text at a later time gets a new one.
            self.send("\n".join(lines), "pods-" + hashlib.sha256(serialized.encode()).hexdigest())
            logging.info("Notified %d pod changes", len(lines))
        temporary = self.pods_file.with_suffix(".tmp")
        temporary.write_text(serialized + "\n", encoding="utf-8")
        os.replace(temporary, self.pods_file)

    def notify_alerts(self, payload):
        if not isinstance(payload, dict) or not isinstance(payload.get("alerts"), list):
            raise ValueError("Invalid Grafana webhook")
        lines = []
        formatted_lines = []
        for alert in payload["alerts"]:
            if not isinstance(alert, dict):
                raise ValueError("Invalid Grafana alert")
            labels = alert.get("labels") or {}
            annotations = alert.get("annotations") or {}
            if not isinstance(labels, dict) or not isinstance(annotations, dict):
                raise ValueError("Invalid Grafana alert labels or annotations")
            status = alert.get("status", payload.get("status"))
            if status not in ("firing", "resolved"):
                raise ValueError("Invalid Grafana alert status")
            heading = (
                f"{status.upper()} [{labels.get('severity', 'unknown')}] "
                f"{labels.get('alertname') or payload.get('title') or 'Grafana alert'} "
                f"on {labels.get('host', labels.get('instance', 'unknown'))}"
            )
            text = "\n".join(filter(None, [
                heading,
                annotations.get("summary") or payload.get("title", ""),
                annotations.get("description", ""),
            ]))
            lines.append(text)
            formatted_lines.append(
                f"<strong>{status.upper()}</strong>"
                + escape(text[len(status):]).replace("\n", "<br>")
            )
        if not lines:
            return
        # Reuse the transaction ID on retries, so a lost HTTP response does not
        # cause a second Matrix message.
        transaction_id = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
        self.send("\n\n".join(lines), transaction_id, "<br><br>".join(formatted_lines))


def handler_for(notifier):
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != "/grafana":
                self.send_error(404)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if length < 1 or length > 1048576:
                    self.send_error(413)
                    return
                payload = json.loads(self.rfile.read(length))
                notifier.notify_alerts(payload)
            except (ValueError, KeyError, TypeError) as error:
                logging.warning("Grafana webhook rejected: %s", error)
                self.send_error(400)
                return
            except Exception:
                logging.exception("Matrix delivery failed")
                self.send_error(502)
                return
            self.send_response(200)
            self.end_headers()

    return Handler


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    notifier = Notifier(*sys.argv[1:])
    polls = {"Comin deployment": notifier.poll_deployments}
    if notifier.kubernetes_token is not None:
        polls["Kubernetes pod"] = notifier.poll_pods

    def poll_forever():
        while True:
            for name, poll in polls.items():
                try:
                    poll()
                except Exception:
                    logging.exception("%s poll failed", name)
            time.sleep(30)

    threading.Thread(target=poll_forever, daemon=True).start()
    HTTPServer(("127.0.0.1", 9187), handler_for(notifier)).serve_forever()


if __name__ == "__main__":
    main()
