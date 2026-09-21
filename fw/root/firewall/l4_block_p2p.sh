#!/bin/sh
set -eu
# Faixa tradicional usada aqui apenas para representar a política P2P/BitTorrent.
iptables -I FORWARD 1 -p tcp --dport 6881:6889 -j DROP
iptables -I FORWARD 1 -p udp --dport 6881:6889 -j DROP
echo 'L4: TCP/UDP 6881:6889 bloqueados.'
