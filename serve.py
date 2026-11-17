# -*- coding: utf-8 -*-
"""指尖花开 · 本地服务
- 正确送出 .wasm (application/wasm) / .js (text/javascript) / .task / .mp4 的 MIME
- 附带 COOP/COEP 头，开启跨源隔离，确保 MediaPipe wasm 稳定运行
- 对 html 禁用缓存，保证每次都是最新页面
运行：python serve.py  然后浏览器打开 http://127.0.0.1:8000/
"""
import http.server
import socketserver
import os

# 本地默认：127.0.0.1:8000（摄像头需要 localhost 安全源）
# 云端部署：自动改为 0.0.0.0:$PORT（平台会注入 PORT）
_env_port = os.environ.get("PORT")
PORT = int(_env_port) if _env_port else 8000
HOST = "0.0.0.0" if _env_port else "127.0.0.1"


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".mjs": "text/javascript",
        ".js": "text/javascript",
        ".task": "application/octet-stream",
        ".mp4": "video/mp4",
        ".html": "text/html; charset=utf-8",
    }

    def end_headers(self):
        # 跨源隔离（部分 wasm 需要 SharedArrayBuffer）
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        # html 不缓存，保证拿到最新页面；逐帧图/静态资源长缓存，避免每帧都回源
        if self.path.endswith("/") or self.path.endswith(".html"):
            self.send_header("Cache-Control", "no-store")
        else:
            self.send_header("Cache-Control", "public, max-age=86400")
        super().end_headers()

    def log_message(self, fmt, *args):
        # 安静模式，少刷屏
        pass


if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer((HOST, PORT), Handler) as httpd:
        print("Serving http://%s:%d  (Ctrl+C 退出)" % (HOST, PORT))
        httpd.serve_forever()
