#!/bin/sh
set -eu
# Bloqueia ICMP da LAN para a DMZ.
iptables -I FORWARD 1 -i eth1 -o eth2 -s 10.0.1.0/24 -d 10.0.2.0/24 -p icmp -j DROP
echo 'L3: ICMP LAN -> DMZ bloqueado.'
