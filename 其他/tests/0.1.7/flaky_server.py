"""Serves a web build but sabotages first requests: drops pck.00 mid-transfer
and stalls pck.03 for 45 s, like the itch.io CDN failures seen on alpha.5."""
import sys, time, http.server, functools, threading
root, port = sys.argv[1], int(sys.argv[2])
seen = {}
lock = threading.Lock()

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        name = self.path.split('?')[0].rsplit('/', 1)[-1]
        with lock:
            seen[name] = seen.get(name, 0) + 1
            count = seen[name]
        print(f"GET {name} #{count}", flush=True)
        if name in ('game.pck.00.bin', 'game.pck.03.bin') and count == 1:
            data = open(f"{root}/data/{name}", 'rb').read()
            self.send_response(200)
            self.send_header('Content-Type', 'application/octet-stream')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data[:1_000_000])
            self.wfile.flush()
            if name == 'game.pck.03.bin':
                time.sleep(45)
            self.close_connection = True
            try:
                self.connection.shutdown(2)
            except OSError:
                pass
            print(f"SABOTAGED {name}", flush=True)
            return
        return super().do_GET()

http.server.ThreadingHTTPServer(('127.0.0.1', port), functools.partial(Handler, directory=root)).serve_forever()
