#!/usr/bin/env python3
"""Cliente TCP+UDP para testar a porta 6881 do servidor web."""
import socket

HOST = "10.0.2.10"
PORT = 6881
TIMEOUT = 2

try:
    with socket.create_connection((HOST, PORT), timeout=TIMEOUT) as s:
        print("TCP:", s.recv(128).decode(errors="replace").strip())
except Exception as exc:
    print("TCP: FALHOU -", exc)

try:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.settimeout(TIMEOUT)
        s.sendto(b"teste", (HOST, PORT))
        data, _ = s.recvfrom(128)
        print("UDP:", data.decode(errors="replace").strip())
except Exception as exc:
    print("UDP: FALHOU -", exc)
