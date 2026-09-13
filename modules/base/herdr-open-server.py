import mimetypes
import shutil
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

file = Path(sys.argv[1])
mount = sys.argv[2]
port = sys.argv[3]
tailscale = sys.argv[4]


class PreviewHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.respond(body=True)

    def do_HEAD(self):
        self.respond(body=False)

    def respond(self, body):
        if self.path != mount:
            self.send_error(404)
            return
        try:
            stream = file.open("rb")
        except OSError:
            self.send_error(404)
            return
        with stream:
            self.send_response(200)
            content_type = mimetypes.guess_type(file)[0] or "application/octet-stream"
            self.send_header("Content-Type", content_type)
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            if body:
                shutil.copyfileobj(stream, self.wfile)

    def log_message(self, *_args):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), PreviewHandler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    result = subprocess.run(
        [
            tailscale, "serve", "--yes", "--bg=false", f"--http={port}",
            f"http://127.0.0.1:{server.server_port}",
        ]
    )
    sys.exit(result.returncode)
finally:
    server.shutdown()
    server.server_close()
