import http.server
import socketserver
import mimetypes

PORT = 8090

# Force the mimetypes registry to recognize .jsp and .jspf as html
mimetypes.add_type('text/html', '.jsp')
mimetypes.add_type('text/html', '.jspf')

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Force cache clearing
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

class MyTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

with MyTCPServer(("", PORT), Handler) as httpd:
    print(f"Serving at port {PORT}")
    httpd.serve_forever()
