"""Serve only this release's web files on this computer, without third-party packages."""
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import argparse
import webbrowser


def main():
    parser = argparse.ArgumentParser(description="Open the local Forest Wanderer game")
    parser.add_argument("--no-open", action="store_true", help="Run without opening a browser")
    args = parser.parse_args()
    folder = Path(__file__).resolve().parent / "web-share"
    if not (folder / "index.html").is_file():
        raise SystemExit("Missing web-share/index.html. Keep the complete release folder together.")
    handler = partial(SimpleHTTPRequestHandler, directory=str(folder))
    with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
        url = f"http://127.0.0.1:{server.server_port}/"
        print(f"Forest Wanderer v0.1.6-alpha.4\n{url}\nKeep this window open. Ctrl+C stops the game server.", flush=True)
        if not args.no_open:
            webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
