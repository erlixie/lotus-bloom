#!/bin/bash
cd "$(dirname "$0")"
echo "================================================"
echo "  指尖花开 · 本地服务"
echo "  地址： http://localhost:8000"
echo "  使用期间请勿关闭本窗口；关闭即停止服务。"
echo "  用 Chrome / Edge 打开上面这个地址。"
echo "================================================"
if command -v python3 >/dev/null 2>&1; then
  python3 serve.py
elif command -v python >/dev/null 2>&1; then
  python serve.py
else
  echo "未找到 Python。请先安装 Python 3（https://www.python.org），"
  echo "或在终端执行： python3 -m http.server 8000"
fi
