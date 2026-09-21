#!/bin/sh
set -eu
# Destino controlado do laboratório usado para representar um IP proibido.
DESTINO='10.0.2.10'
iptables -I FORWARD 1 -i eth1 -s 10.0.1.0/24 -d "$DESTINO" -j DROP
echo "L3: destino $DESTINO bloqueado para a LAN."
