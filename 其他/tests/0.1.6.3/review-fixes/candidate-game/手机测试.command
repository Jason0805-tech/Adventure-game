#!/bin/zsh
GAME_DIR="${0:A:h}"
if command -v python3 >/dev/null 2>&1; then
  python3 "$GAME_DIR/start_web.py" --lan
else
  print '需要 Python 3 才能启动本机网页服务器。'
  read '?按回车关闭。'
fi
