#!/usr/bin/env python3
import socket
import threading
import select
import sys
import time
import getopt

# KONFIGURASI
LISTENING_ADDR = "127.0.0.1"
LISTENING_PORT = 1230  # Port Default
PASS = ""  # Password header (X-Pass)

# Default Host jika tidak ada header X-Real-Host (Format IP:PORT)
DEFAULT_HOST = "127.0.0.1:90"

# Buffer & Timeout
BUFLEN = 8192  # Ukuran buffer
TIMEOUT = 60  # Detik

# Response Fake 101 (Harus dalam format BYTES)
RESPONSE = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"


# CLASS SERVER
class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
        self.logLock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        try:
            self.soc.bind((self.host, int(self.port)))
            self.soc.listen(0)
            self.running = True
            self.printLog(f"[*] Server Started on {self.host}:{self.port}")
        except Exception as e:
            self.printLog(f"[!] Gagal bind port: {e}")
            self.running = False
            return

        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                    conn = ConnectionHandler(c, self, addr)
                    conn.start()
                    self.addConn(conn)
                except socket.timeout:
                    continue
                except Exception as e:
                    self.printLog(f"[!] Error accept: {e}")
        finally:
            self.running = False
            self.soc.close()

    def printLog(self, log):
        with self.logLock:
            print(log)

    def addConn(self, conn):
        with self.threadsLock:
            if self.running:
                self.threads.append(conn)

    def removeConn(self, conn):
        with self.threadsLock:
            try:
                self.threads.remove(conn)
            except ValueError:
                pass

    def close(self):
        self.running = False
        with self.threadsLock:
            for c in self.threads:
                c.close()


# CLASS CONNECTION HANDLER
class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.client_buffer = b""  # Inisialisasi sebagai BYTES
        self.server = server
        self.log = f"Connection: {addr}"
        self.target = None

    def close(self):
        if not self.clientClosed:
            try:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
            except:
                pass
            self.clientClosed = True

        if not self.targetClosed:
            try:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
            except:
                pass
            self.targetClosed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            if not self.client_buffer:
                self.close()
                return

            hostPort = self.findHeader(self.client_buffer, b"X-Real-Host")

            if hostPort == "":
                hostPort = DEFAULT_HOST

            split = self.findHeader(self.client_buffer, b"X-Split")
            if split != "":
                self.client.recv(BUFLEN)

            if hostPort != "":
                passwd = self.findHeader(self.client_buffer, b"X-Pass")

                if len(PASS) != 0 and passwd == PASS:
                    self.method_CONNECT(hostPort)
                elif len(PASS) != 0 and passwd != PASS:
                    self.client.send(b"HTTP/1.1 400 WrongPass!\r\n\r\n")
                elif hostPort.startswith("127.0.0.1") or hostPort.startswith(
                    "localhost"
                ):
                    self.method_CONNECT(hostPort)
                else:
                    self.client.send(b"HTTP/1.1 403 Forbidden!\r\n\r\n")
            else:
                print("- No X-Real-Host!")
                self.client.send(b"HTTP/1.1 400 NoXRealHost!\r\n\r\n")

        except Exception as e:
            pass
        finally:
            self.close()
            self.server.removeConn(self)

    def findHeader(self, head, header_name):
        aux = head.find(header_name + b": ")
        if aux == -1:
            return ""

        aux = head.find(b":", aux)
        head_slice = head[aux + 2 :]
        aux = head_slice.find(b"\r\n")

        if aux == -1:
            return ""

        return head_slice[:aux].decode("utf-8", errors="ignore").strip()

    def connect_target(self, host):
        if ":" in host:
            ip, port = host.split(":")
            port = int(port)
        else:
            ip = host
            port = 443

        (soc_family, soc_type, proto, _, address) = socket.getaddrinfo(ip, port)[0]

        self.target = socket.socket(soc_family, soc_type, proto)
        self.targetClosed = False
        self.target.connect(address)

    def method_CONNECT(self, path):
        try:
            self.connect_target(path)
            self.client.sendall(RESPONSE)
            self.client_buffer = b""

            self.doCONNECT()
        except Exception as e:
            self.close()

    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)

            if err:
                break

            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target:
                                self.client.send(data)
                            else:
                                while data:
                                    byte = self.target.send(data)
                                    data = data[byte:]
                            count = 0
                        else:
                            return
                    except:
                        return

            if count == TIMEOUT:
                break


# MAIN FUNCTION
def print_usage():
    print("Usage: python3 ws-py3.py [PORT]")
    print("Example: python3 ws-py3.py 880")


def main():
    global LISTENING_PORT

    if len(sys.argv) > 1:
        try:
            LISTENING_PORT = int(sys.argv[1])
        except ValueError:
            print_usage()
            sys.exit(1)

    print(f"\n:-------Python3 Proxy (Refactored)-------:")
    print(f"Listening addr: {LISTENING_ADDR}")
    print(f"Listening port: {LISTENING_PORT}")
    print(f":----------------------------------------:\n")

    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()

    try:
        while True:
            time.sleep(2)
    except KeyboardInterrupt:
        print("\n[!] Stopping Server...")
        server.close()


if __name__ == "__main__":
    main()
