#!/usr/bin/env python3
"""Serve this static release only on loopback, with no third-party dependencies."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Timer
import webbrowser

root = Path(__file__).resolve().parent / 'dist'
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory=str(root)))
url = f'http://127.0.0.1:{server.server_port}/'
print(f'Jason personal website: {url}', flush=True)
print('Press Control+C to stop.', flush=True)
Timer(0.5, lambda: webbrowser.open(url)).start()
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
