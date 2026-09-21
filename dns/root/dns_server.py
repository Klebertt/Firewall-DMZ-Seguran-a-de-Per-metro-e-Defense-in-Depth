#!/usr/bin/env python3
"""DNS mínimo para o laboratório: responde A lab.test = 10.0.2.10 em UDP e TCP."""
import socket
import struct
import threading

BIND = "0.0.0.0"
PORT = 53
ANSWER_IP = socket.inet_aton("10.0.2.10")
TARGET = "lab.test"


def parse_question(data):
    if len(data) < 12:
        raise ValueError("pacote curto")
    pos = 12
    labels = []
    while True:
        if pos >= len(data):
            raise ValueError("nome inválido")
        ln = data[pos]
        pos += 1
        if ln == 0:
            break
        labels.append(data[pos:pos + ln].decode("ascii", "ignore"))
        pos += ln
    if pos + 4 > len(data):
        raise ValueError("questão incompleta")
    qtype, qclass = struct.unpack("!HH", data[pos:pos + 4])
    end = pos + 4
    return ".".join(labels).lower(), qtype, qclass, data[12:end]


def build_reply(data):
    txid = data[:2]
    name, qtype, qclass, question = parse_question(data)
    query_flags = struct.unpack("!H", data[2:4])[0]
    rd = query_flags & 0x0100
    if name == TARGET and qtype == 1 and qclass == 1:
        # QR=1, AA=1, RD preservado, RA=0.
        flags = struct.pack("!H", 0x8400 | rd)
        header = txid + flags + struct.pack("!HHHH", 1, 1, 0, 0)
        # NAME usa ponteiro para offset 12; TYPE A; CLASS IN; TTL 60; RDLENGTH 4.
        answer = b"\xc0\x0c" + struct.pack("!HHIH", 1, 1, 60, 4) + ANSWER_IP
        return header + question + answer
    flags = struct.pack("!H", 0x8403 | rd)  # QR=1, AA=1, NXDOMAIN
    header = txid + flags + struct.pack("!HHHH", 1, 0, 0, 0)
    return header + question


def udp_loop():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind((BIND, PORT))
    while True:
        data, addr = s.recvfrom(4096)
        try:
            s.sendto(build_reply(data), addr)
        except Exception:
            pass


def handle_tcp(conn):
    try:
        raw_len = conn.recv(2)
        if len(raw_len) != 2:
            return
        length = struct.unpack("!H", raw_len)[0]
        data = b""
        while len(data) < length:
            chunk = conn.recv(length - len(data))
            if not chunk:
                return
            data += chunk
        reply = build_reply(data)
        conn.sendall(struct.pack("!H", len(reply)) + reply)
    finally:
        conn.close()


def tcp_loop():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((BIND, PORT))
    s.listen(16)
    while True:
        conn, _ = s.accept()
        threading.Thread(target=handle_tcp, args=(conn,), daemon=True).start()


threading.Thread(target=udp_loop, daemon=True).start()
tcp_loop()
