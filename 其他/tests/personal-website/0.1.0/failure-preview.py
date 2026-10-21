"""Test-only origin: reject the first binary chunk, then serve normally."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json, time

root=Path(__file__).resolve().parent
class Handler(SimpleHTTPRequestHandler):
    failed=False
    def do_GET(self):
        if '/data/' in self.path and not Handler.failed:
            Handler.failed=True
            self.send_error(503,'Intentional QA failure: retry should recover')
        else:
            super().do_GET()
    def log_message(self, fmt, *args):
        with (root/'failure-preview-requests.jsonl').open('a') as f:
            f.write(json.dumps({'time':time.time(),'request':fmt%args})+'\n')
server=ThreadingHTTPServer(('127.0.0.1',65111),partial(Handler,directory=str(root/'site'/'dist')))
print('QA preview: http://127.0.0.1:65111',flush=True)
server.serve_forever()
