#!/usr/bin/env python3
import socket
import threading
import select
import sys
import time
import getopt

LISTENING_ADDR = '127.0.0.1'
LISTENING_PORT = 1230
PASS = ''
BUFLEN = 4096 * 4
TIMEOUT = 60
DEFAULT_HOST = '127.0.0.1:90'
RESPONSE = (
    'HTTP/1.1 101 Switching Protocol\r\n'
    'Upgrade: websocket\r\n'
    'Connection: Upgrade\r\n\r\n'
)

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threads_lock = threading.Lock()
        self.log_lock = threading.Lock()
        self.soc = None

    def run(self):
        self.soc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, int(self.port)))
        self.soc.listen(5)
        self.running = True

        try:
            while self.running:
                try:
                    client_sock, addr = self.soc.accept()
                    client_sock.setblocking(True)
                except socket.timeout:
                    continue

                conn = ConnectionHandler(client_sock, self, addr)
                conn.start()
                self.add_conn(conn)
        finally:
            self.running = False
            self.soc.close()

    def print_log(self, log):
        with self.log_lock:
            print(log)

    def add_conn(self, conn):
        with self.threads_lock:
            if self.running:
                self.threads.append(conn)

    def remove_conn(self, conn):
        with self.threads_lock:
            if conn in self.threads:
                self.threads.remove(conn)

    def close(self):
        self.running = False
        with self.threads_lock:
            threads = list(self.threads)
        for c in threads:
            c.close()


class ConnectionHandler(threading.Thread):
    def __init__(self, sock_client, server, addr):
        threading.Thread.__init__(self)
        self.client_closed = False
        self.target_closed = True
        self.client = sock_client
        self.target = None
        self.client_buffer = b''
        self.server = server
        self.log = 'Connection: ' + str(addr)

    def close(self):
        try:
            if not self.client_closed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except OSError:
            pass
        finally:
            self.client_closed = True

        try:
            if not self.target_closed and self.target is not None:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except OSError:
            pass
        finally:
            self.target_closed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)

            host_port = self.find_header(self.client_buffer, 'X-Real-Host')

            if host_port == '':
                host_port = DEFAULT_HOST

            split = self.find_header(self.client_buffer, 'X-Split')
            if split != '':
                self.client.recv(BUFLEN)

            if host_port != '':
                passwd = self.find_header(self.client_buffer, 'X-Pass')

                if len(PASS) != 0 and passwd == PASS:
                    self.method_connect(host_port)
                elif len(PASS) != 0 and passwd != PASS:
                    self.client.send(b'HTTP/1.1 400 WrongPass!\r\n\r\n')
                elif host_port.startswith('127.0.0.1') or host_port.startswith('localhost'):
                    self.method_connect(host_port)
                else:
                    self.client.send(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
            else:
                print('- No X-Real-Host!')
                self.client.send(b'HTTP/1.1 400 NoXRealHost!\r\n\r\n')

        except Exception as e:
            self.log += ' - error: ' + str(e)
            self.server.print_log(self.log)
        finally:
            self.close()
            self.server.remove_conn(self)

    def find_header(self, head, header):
        head_str = head.decode('latin-1', errors='ignore')
        needle = header + ': '
        idx = head_str.find(needle)

        if idx == -1:
            return ''

        idx = head_str.find(':', idx)
        rest = head_str[idx + 2:]
        end = rest.find('\r\n')

        if end == -1:
            return ''

        return rest[:end]

    def connect_target(self, host):
        i = host.find(':')
        if i != -1:
            port = int(host[i + 1:])
            host = host[:i]
        else:
            port = int(LISTENING_PORT)

        addrinfo = socket.getaddrinfo(host, port)[0]
        soc_family, soc_type, proto, _, address = addrinfo

        self.target = socket.socket(soc_family, soc_type, proto)
        self.target_closed = False
        self.target.connect(address)

    def method_connect(self, path):
        self.log += ' - CONNECT ' + path

        self.connect_target(path)
        self.client.sendall(RESPONSE.encode())
        self.client_buffer = b''

        self.server.print_log(self.log)
        self.do_connect()

    def do_connect(self):
        socs = [self.client, self.target]
        count = 0
        error = False

        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)

            if err:
                error = True

            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target:
                                self.client.send(data)
                            else:
                                while data:
                                    sent = self.target.send(data)
                                    data = data[sent:]
                            count = 0
                        else:
                            error = True
                            break
                    except OSError:
                        error = True
                        break

            if count == TIMEOUT:
                error = True
            if error:
                break


def print_usage():
    print('Usage: proxy.py -p <port>')
    print('       proxy.py -b <bindAddr> -p <port>')
    print('       proxy.py -b 0.0.0.0 -p 80')


def parse_args(argv):
    global LISTENING_ADDR
    global LISTENING_PORT

    try:
        opts, _ = getopt.getopt(argv, 'hb:p:', ['bind=', 'port='])
    except getopt.GetoptError:
        print_usage()
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print_usage()
            sys.exit()
        elif opt in ('-b', '--bind'):
            LISTENING_ADDR = arg
        elif opt in ('-p', '--port'):
            LISTENING_PORT = int(arg)


def main():
    print('\n:-------PythonProxy (Python 3)-------:\n')
    print('Listening addr: ' + LISTENING_ADDR)
    print('Listening port: ' + str(LISTENING_PORT) + '\n')
    print(':-------------------------:\n')

    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()

    while True:
        try:
            time.sleep(2)
        except KeyboardInterrupt:
            print('Stopping...')
            server.close()
            break


if __name__ == '__main__':
    parse_args(sys.argv[1:])
    main()
