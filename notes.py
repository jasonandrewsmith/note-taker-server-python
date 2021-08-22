from http.server import BaseHTTPRequestHandler, HTTPServer, SimpleHTTPRequestHandler

class GetHandler(SimpleHTTPRequestHandler):

        def do_GET(self):
            SimpleHTTPRequestHandler.do_GET(self)

        def do_POST(self):
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.data_string = self.rfile.read(int(self.headers['Content-Length']))

            data = b'<html><body><h1>POST!</h1></body></html>'
            self.wfile.write(bytes(data))
            return

Handler=GetHandler

httpd=HTTPServer(("localhost", 8080), Handler)
httpd.serve_forever()