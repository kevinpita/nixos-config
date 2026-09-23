#!/usr/bin/env python3
"""Forward Grafana alerts and successful Comin deployments to Matrix."""

import hashlib
from html import escape
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import logging
import os
from pathlib import Path
import sys
import threading
import time
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


MATRIX_URL = "https://matrix.org/_matrix/client/v3/rooms/"
PROMETHEUS_URL = "http://127.0.0.1:9090/api/v1/query"
DEPLOYMENT_QUERY = 'comin_last_successful_deployment_timestamp_seconds{job="node",host=~"fium|minidesk"}'
HOSTS = {"fium", "minidesk"}


def request_json(url, payload=None, headers=None, method=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(url, data=data, headers=headers or {}, method=method)
    with urlopen(request, timeout=15) as response:
        return json.load(response)


class Notifier:
    def __init__(self, token_file, room_file, state_dir):
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
        url = PROMETHEUS_URL + "?" + urlencode({"query": DEPLOYMENT_QUERY})
        result = request_json(url)
        if result.get("status") != "success":
            raise ValueError("Prometheus query failed")
        for sample in result["data"]["result"]:
            host = sample["metric"].get("host")
            if host not in HOSTS:
                continue
            timestamp = int(float(sample["value"][1]))
            if timestamp <= 0:
                continue
            previous = self.state["last"].get(host)
            if previous is not None and timestamp <= previous:
                continue
            if previous is not None or timestamp > self.state["baseline"]:
                self.send(f"{host} completed a Comin deployment.", f"comin-{host}-{timestamp}")
                logging.info("Notified successful Comin deployment on %s", host)
            self.state["last"][host] = timestamp
            self.save_state()

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
    notifier = Notifier(sys.argv[1], sys.argv[2], sys.argv[3])

    def poll_forever():
        while True:
            try:
                notifier.poll_deployments()
            except Exception:
                logging.exception("Comin deployment poll failed")
            time.sleep(30)

    threading.Thread(target=poll_forever, daemon=True).start()
    HTTPServer(("127.0.0.1", 9187), handler_for(notifier)).serve_forever()


if __name__ == "__main__":
    main()
