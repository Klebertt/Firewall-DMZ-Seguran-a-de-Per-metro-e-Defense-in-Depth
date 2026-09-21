#!/usr/bin/env python3
"""Servidor TCP+UDP simples para o experimento L4 na porta 6881."""
import select
import socket

HOST = "0.0.0.0"
PORT = 6881

tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
tcp.bind((HOST, PORT))
tcp.listen(5)
tcp.setblocking(False)

udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udp.bind((HOST, PORT))
udp.setblocking(False)

print(f"Servidor de teste L4 ativo em TCP/UDP {PORT}", flush=True)

while True:
    readable, _, _ = select.select([tcp, udp], [], [])
    for sock in readable:
        if sock is tcp:
            conn, addr = tcp.accept()
            conn.sendall(b"TCP 6881 OK\n")
            conn.close()
        else:
            data, addr = udp.recvfrom(2048)
            udp.sendto(b"UDP 6881 OK\n", addr)
