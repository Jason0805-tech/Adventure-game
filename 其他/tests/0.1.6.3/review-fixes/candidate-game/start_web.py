#!/usr/bin/env python3
"""Run only this game's static website; no dependencies or installation."""
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from functools import partial
import argparse, socket, webbrowser
parser=argparse.ArgumentParser()
parser.add_argument('--lan',action='store_true',help='Allow phones on the same Wi-Fi to open the game.')
args=parser.parse_args()
root=Path(__file__).resolve().parent/'web-share'
server=ThreadingHTTPServer(('0.0.0.0' if args.lan else '127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(root)))
port=server.server_address[1]
url=f'http://127.0.0.1:{port}/'
print('\nForest Wanderer 0.1.6.3\n电脑打开：'+url,flush=True)
if args.lan:
 try:
  with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as probe:
   probe.connect(('192.0.2.1',80));address=probe.getsockname()[0]
  print(f'iPhone（同一Wi-Fi）打开：http://{address}:{port}/',flush=True)
 except OSError:
  print('未找到局域网地址，请确认电脑和手机连接同一个Wi-Fi。',flush=True)
print('保持这个终端窗口打开。按 Control+C 停止服务器。\n',flush=True)
webbrowser.open(url)
try:server.serve_forever()
except KeyboardInterrupt:pass
finally:server.server_close()
