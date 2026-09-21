#!/bin/sh
set -eu
PC2_MAC='02:42:0a:00:01:0b'
# Deve ser usado após baseline.sh para o ciclo Antes -> Regra -> Depois.
iptables -I FORWARD 1 -i eth1 -m mac --mac-source "$PC2_MAC" -j DROP
echo "L2: bloqueando pc2 pelo MAC $PC2_MAC na entrada da LAN."
