#!/bin/sh
set -eu

# BASELINE: sem regras restritivas no fw.
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo 'Baseline aplicada: INPUT/FORWARD/OUTPUT = ACCEPT.'
