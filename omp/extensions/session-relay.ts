/**
 * session-relay: move resumable omp sessions between machines over SSH.
 *
 * `/send <host|local> <name> [--snapshot]` moves this terminal to a new
 * session, then packs the session it left and pushes it to
 * `<host>:~/.omp/relay/<name>.bundle.tgz` (or stages it in the local
 * `~/.omp/relay/` for `local`). `/receive [host] <name>` installs a bundle,
 * pulled from `<host>` when given, and switches this terminal to it.
 * Servers cannot SSH to workstations, so the receiving side does the
 * fetching: a server stages with `/send local`, a workstation pulls.
 *
 * Session packing and unpacking is omp's own `omp session pack|unpack`
 * implementation (session/session-transfer): it carries artifacts and
 * blobs, rewrites the header cwd, and replaces an older local copy of the
 * same session or lands a diverged one as a fork.
 *
 * Bundles are gzipped tars:
 *   session.tar   omp session archive (packSession)
 *   workdir/...   optional snapshot of the sender's cwd (--snapshot)
 *   relay.json    RelayManifest
 */

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { packSession, unpackSession, type UnpackMode, type UnpackSessionResult } from "@oh-my-pi/pi-coding-agent/session/session-transfer";
import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const REMOTE_RELAY_DIR = ".omp/relay";
const LOCAL_RELAY_DIR = path.join(os.homedir(), ".omp", "relay");
const NAME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const SNAPSHOT_SKIP: Record<string, true> = { ".git": true, node_modules: true, result: true, target: true, ".next": true, ".cache": true };

const UNPACK_NOTE: Record<UnpackMode, string> = {
	created: "",
	replaced: "; replaced the older local copy",
	forked: "; the local copy had diverged, so this is a fork with a new id",
};

interface ProcResult {
	code: number;
	stderr: string;
}

interface RelayManifest {
	name: string;
	sessionId: string;
	sender: string;
	snapshot: boolean;
	createdAt: string;
}

type NotifyCtx = { ui: { notify(message: string, type?: "info" | "warning" | "error"): void } };

/** Notify, then throw. Print mode prints thrown command errors on stderr. */
function fail(ctx: NotifyCtx, message: string): never {
	ctx.ui.notify(message, "error");
	throw new Error(message);
}

function run(cmd: string, args: string[]): Promise<ProcResult> {
	const { promise, resolve } = Promise.withResolvers<ProcResult>();
	const child = spawn(cmd, args, { stdio: ["ignore", "ignore", "pipe"] });
	let stderr = "";
	child.stderr.on("data", (d) => (stderr += d));
	child.on("close", (code) => resolve({ code: code ?? -1, stderr }));
	child.on("error", (err) => resolve({ code: -1, stderr: String(err) }));
	return promise;
}

function procError(prefix: string, result: ProcResult): Error {
	return new Error(`${prefix}: ${result.stderr.trim() || `exit ${result.code}`}`);
}

/** ssh takes one remote command string, so quote it for the remote shell. */
function shQuote(s: string): string {
	return `'${s.replaceAll("'", `'\\''`)}'`;
}

/** Relative to the remote home; never assume the remote user's layout. */
function remoteBundlePath(name: string): string {
	return `${REMOTE_RELAY_DIR}/${name}.bundle.tgz`;
}

function sshArgs(dest: string, remoteCommand: string): string[] {
	return ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", dest, remoteCommand];
}

/** Push a local file to `<dest>:<remotePath>`; the remote move is atomic. */
function sshPushFile(dest: string, localPath: string, remotePath: string): Promise<ProcResult> {
	const { promise, resolve } = Promise.withResolvers<ProcResult>();
	const tmp = `${remotePath}.tmp.${process.pid}`;
	const remote = `install -d ${shQuote(REMOTE_RELAY_DIR)} && cat > ${shQuote(tmp)} && mv ${shQuote(tmp)} ${shQuote(remotePath)}`;
	const child = spawn("ssh", sshArgs(dest, remote), { stdio: ["pipe", "ignore", "pipe"] });
	let stderr = "";
	child.stderr.on("data", (d) => (stderr += d));
	// ssh can exit mid-upload (unknown host, remote failure); its stdin then
	// errors with EPIPE. Stop reading and report ssh's own exit and stderr.
	let stdinError: Error | undefined;
	child.stdin.on("error", (err) => {
		stdinError = err;
		input.destroy();
	});
	child.on("close", (code) => resolve({ code: code || (stdinError ? -1 : 0), stderr: stderr || String(stdinError ?? "") }));
	child.on("error", (err) => resolve({ code: -1, stderr: String(err) }));
	const input = fs.createReadStream(localPath);
	input.on("error", (err) => {
		child.kill();
		resolve({ code: -1, stderr: String(err) });
	});
	input.pipe(child.stdin);
	return promise;
}

/** Fetch `<dest>:<remotePath>` into a local file; resolves after ssh exits and the file is flushed. */
async function sshPullFile(dest: string, remotePath: string, localPath: string): Promise<ProcResult> {
	const child = spawn("ssh", sshArgs(dest, `cat ${shQuote(remotePath)}`), { stdio: ["ignore", "pipe", "pipe"] });
	let stderr = "";
	child.stderr.on("data", (d) => (stderr += d));
	const out = fs.createWriteStream(localPath);
	// Settle the write outcome up front so an early write error is never unhandled.
	const written = Promise.withResolvers<Error | undefined>();
	out.on("finish", () => written.resolve(undefined));
	out.on("error", written.resolve);
	child.stdout.pipe(out);
	const exited = Promise.withResolvers<number>();
	child.on("close", (code) => exited.resolve(code ?? -1));
	child.on("error", (err) => {
		stderr += String(err);
		out.end();
		exited.resolve(-1);
	});
	const code = await exited.promise;
	const writeError = await written.promise;
	if (writeError) return { code: -1, stderr: String(writeError) };
	return { code, stderr };
}

function parseArgs(args: string): { flags: Set<string>; positional: string[] } {
	const flags = new Set<string>();
	const positional: string[] = [];
	for (const part of args.trim().split(/\s+/).filter(Boolean)) {
		if (part.startsWith("--")) flags.add(part);
		else positional.push(part);
	}
	return { flags, positional };
}

/**
 * Copy the session file and its artifacts into `dir` without the header
 * fields that point into the sender's filesystem: workspace roots, the
 * seance artifact source, and the parent session id. Returns the copy.
 */
function copyWithoutSenderPaths(sessionFile: string, dir: string): string {
	const copy = path.join(dir, path.basename(sessionFile));
	const artifacts = sessionFile.slice(0, -".jsonl".length);
	if (fs.existsSync(artifacts)) fs.cpSync(artifacts, copy.slice(0, -".jsonl".length), { recursive: true });
	const lines = fs.readFileSync(sessionFile, "utf8").split("\n");
	for (let index = 0; index < Math.min(lines.length, 3); index++) {
		if (!lines[index].trim()) continue;
		const parsed: unknown = JSON.parse(lines[index]);
		if (typeof parsed !== "object" || parsed === null || !("type" in parsed) || parsed.type !== "session") continue;
		const { additionalDirectories: _dirs, seanceSource: _seance, parentSession: _parent, ...header } = parsed as Record<string, unknown>;
		lines[index] = JSON.stringify(header);
		fs.writeFileSync(copy, lines.join("\n"));
		return copy;
	}
	throw new Error(`no session header in ${sessionFile}`);
}

/** Write the bundle for `sessionFile` into `workDir` and return the archive path. */
async function buildBundle(
	ctx: NotifyCtx,
	workDir: string,
	sessionFile: string,
	name: string,
	cwd: string,
	snapshot: boolean,
): Promise<{ archivePath: string; manifest: RelayManifest }> {
	const bundleDir = path.join(workDir, "bundle");
	const cleanDir = path.join(workDir, "clean");
	fs.mkdirSync(bundleDir, { recursive: true });
	fs.mkdirSync(cleanDir);
	const packed = await packSession(copyWithoutSenderPaths(sessionFile, cleanDir), path.join(bundleDir, "session.tar"));
	if (packed.missingBlobs.length > 0) {
		ctx.ui.notify(`${packed.missingBlobs.length} referenced blob(s) are missing locally; those images will not load on the receiver`, "warning");
	}

	if (snapshot) {
		fs.cpSync(cwd, path.join(bundleDir, "workdir"), {
			recursive: true,
			filter: (src) => src === cwd || !SNAPSHOT_SKIP[path.basename(src)],
		});
	}

	const manifest: RelayManifest = { name, sessionId: packed.id, sender: os.hostname(), snapshot, createdAt: new Date().toISOString() };
	fs.writeFileSync(path.join(bundleDir, "relay.json"), JSON.stringify(manifest, null, 2));

	const archivePath = path.join(workDir, "bundle.tgz");
	const tar = await run("tar", ["-czf", archivePath, "-C", bundleDir, "."]);
	if (tar.code !== 0) throw procError("tar failed", tar);
	return { archivePath, manifest };
}

export default function sessionRelay(pi: ExtensionAPI) {
	pi.setLabel("session-relay");

	pi.registerCommand("send", {
		description: "Pack the current session and push it to a host over SSH (or stage it with `local`)",
		handler: async (args, ctx) => {
			const { flags, positional } = parseArgs(args);
			const [host, name] = positional;
			if (!host || !name) fail(ctx, "usage: /send <host|local> <name> [--snapshot]");
			if (!NAME_RE.test(name)) fail(ctx, `invalid name "${name}": letters, digits, dot, dash, underscore only`);

			ctx.ui.notify("waiting for the current turn to end...", "info");
			await ctx.waitForIdle();
			// Persistence is lazy: a fresh session has a path but no file yet.
			const sessionFile = ctx.sessionManager.getSessionFile();
			if (!sessionFile || !(fs.statSync(sessionFile, { throwIfNoEntry: false })?.size ?? 0)) {
				fail(ctx, "nothing to send: this session is not saved yet");
			}
			const sessionId = ctx.sessionManager.getSessionId();
			// Leave the session before packing. omp appends to the current session
			// until it leaves it (session_exit on quit, for example), and any entry
			// added after the pack makes a later return land as a fork.
			const left = await ctx.newSession();
			if (left.cancelled) fail(ctx, "send cancelled: could not leave the current session");

			const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "omp-relay-"));
			try {
				const { archivePath, manifest } = await buildBundle(ctx, workDir, sessionFile, name, ctx.cwd, flags.has("--snapshot"));
				if (host === "local") {
					fs.mkdirSync(LOCAL_RELAY_DIR, { recursive: true });
					const stagingPath = path.join(LOCAL_RELAY_DIR, `${name}.bundle.tgz`);
					const tmpPath = `${stagingPath}.tmp.${process.pid}`;
					fs.copyFileSync(archivePath, tmpPath);
					fs.renameSync(tmpPath, stagingPath);
					ctx.ui.notify(`staged session "${name}" (${manifest.sessionId}) in ${stagingPath}; this terminal is now in a new session`, "info");
				} else {
					const push = await sshPushFile(host, archivePath, remoteBundlePath(name));
					if (push.code !== 0) throw procError(`ssh push to ${host} failed`, push);
					ctx.ui.notify(`sent session "${name}" (${manifest.sessionId}) to ${host}; this terminal is now in a new session`, "info");
				}
			} catch (err) {
				fail(ctx, `send failed: ${err instanceof Error ? err.message : String(err)}. The session is unchanged; /resume ${sessionId} to continue it`);
			} finally {
				fs.rmSync(workDir, { recursive: true, force: true });
			}
		},
	});

	pi.registerCommand("receive", {
		description: "Install a session bundle (staged locally or pulled from a host) and switch to it",
		handler: async (args, ctx) => {
			const positional = parseArgs(args).positional;
			if (positional.length < 1 || positional.length > 2) fail(ctx, "usage: /receive [host] <name>");
			const host = positional.length === 2 ? positional[0] : undefined;
			const name = positional[positional.length - 1];
			if (!NAME_RE.test(name)) fail(ctx, `invalid name "${name}": letters, digits, dot, dash, underscore only`);

			await ctx.waitForIdle();
			const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "omp-relay-"));
			try {
				const archivePath = path.join(workDir, "bundle.tgz");
				if (host) {
					ctx.ui.notify(`pulling "${name}" from ${host}...`, "info");
					const pull = await sshPullFile(host, remoteBundlePath(name), archivePath);
					if (pull.code !== 0) throw procError(`ssh pull from ${host} failed`, pull);
				} else {
					const stagingPath = path.join(LOCAL_RELAY_DIR, `${name}.bundle.tgz`);
					if (!fs.existsSync(stagingPath)) throw new Error(`no staged bundle: ${stagingPath}`);
					fs.copyFileSync(stagingPath, archivePath);
				}

				const bundleDir = path.join(workDir, "bundle");
				fs.mkdirSync(bundleDir);
				const tar = await run("tar", ["-xzf", archivePath, "-C", bundleDir]);
				if (tar.code !== 0) throw procError("tar failed", tar);
				const manifest = JSON.parse(fs.readFileSync(path.join(bundleDir, "relay.json"), "utf8")) as RelayManifest;

				// The extension switchSession cannot change the terminal's cwd, so
				// a snapshot restores into this cwd. Never merge into existing files.
				const snapshotDir = path.join(bundleDir, "workdir");
				const hasSnapshot = fs.existsSync(snapshotDir);
				if (hasSnapshot && fs.readdirSync(ctx.cwd).length > 0) {
					throw new Error(`the bundle has a workdir snapshot, which restores into the current directory, and ${ctx.cwd} is not empty. Start omp in an empty directory and receive again`);
				}

				// Unpacking replaces local copies of the same id; leave this session
				// first so the live session manager does not hold a replaced file.
				if (ctx.sessionManager.getSessionId() === manifest.sessionId) {
					const fresh = await ctx.newSession();
					if (fresh.cancelled) throw new Error("could not leave the current session, which has the same id as the incoming one");
				}

				if (hasSnapshot) fs.cpSync(snapshotDir, ctx.cwd, { recursive: true });
				const sessionDir = ctx.sessionManager.getSessionDir();
				let unpacked: UnpackSessionResult;
				try {
					unpacked = await unpackSession(path.join(bundleDir, "session.tar"), sessionDir ? { cwd: ctx.cwd, sessionDir } : { cwd: ctx.cwd });
				} catch (err) {
					// The cwd was empty before the restore, so empty it again.
					if (hasSnapshot) for (const entry of fs.readdirSync(ctx.cwd)) fs.rmSync(path.join(ctx.cwd, entry), { recursive: true, force: true });
					throw err;
				}

				const switched = await ctx.switchSession(unpacked.sessionFile);
				if (switched.cancelled) throw new Error(`session installed at ${unpacked.sessionFile}, but the switch to it was cancelled`);
				const snapshotNote = hasSnapshot ? `; workdir restored into ${ctx.cwd}` : "";
				ctx.ui.notify(`received session "${name}" (${unpacked.id}) from ${manifest.sender}${UNPACK_NOTE[unpacked.mode]}${snapshotNote}`, "info");
			} catch (err) {
				fail(ctx, `receive failed: ${err instanceof Error ? err.message : String(err)}`);
			} finally {
				fs.rmSync(workDir, { recursive: true, force: true });
			}
		},
	});
}
