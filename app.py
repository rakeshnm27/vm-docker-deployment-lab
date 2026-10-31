from http.server import BaseHTTPRequestHandler, HTTPServer

class AppHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Application is healthy")

        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Welcome to VM Docker Deployment Lab! version 1.1")

server = HTTPServer(("0.0.0.0", 5000), AppHandler)

print("Application running on port 5000")

server.serve_forever()
