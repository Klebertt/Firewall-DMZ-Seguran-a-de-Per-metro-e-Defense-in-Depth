#!/bin/sh
set -eu

# POLÍTICA FINAL DE SEGURANÇA DE PERÍMETRO
# Princípio: default deny + menor privilégio + filtragem stateful.

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Tráfego local do próprio firewall.
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Respostas pertencentes a fluxos já autorizados.
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# LAN -> Internet: permitido.
iptables -A FORWARD -i eth1 -o eth0 -s 10.0.1.0/24 \
    -m conntrack --ctstate NEW -j ACCEPT

# LAN -> servidor Web da DMZ: HTTP/HTTPS.
iptables -A FORWARD -i eth1 -o eth2 -s 10.0.1.0/24 -d 10.0.2.10 \
    -p tcp -m multiport --dports 80,443 \
    -m conntrack --ctstate NEW -j ACCEPT

# LAN -> servidor DNS da DMZ: UDP/TCP 53.
iptables -A FORWARD -i eth1 -o eth2 -s 10.0.1.0/24 -d 10.0.2.11 \
    -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -s 10.0.1.0/24 -d 10.0.2.11 \
    -p tcp --dport 53 -m conntrack --ctstate NEW -j ACCEPT

# Internet -> Web da DMZ: o DNAT ocorre no r0; no fw o destino já é 10.0.2.10.
iptables -A FORWARD -i eth0 -o eth2 -d 10.0.2.10 \
    -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT

# Não há regras NEW para Internet -> LAN nem DMZ -> LAN.
# Esses fluxos são bloqueados pelo FORWARD DROP.

# Log limitado dos descartes para apoiar os experimentos.
iptables -A FORWARD -m limit --limit 6/min --limit-burst 10 \
    -j LOG --log-prefix 'FW-DROP: ' --log-level 4

echo 'Política de perímetro aplicada: FORWARD DROP + permissões explícitas.'
