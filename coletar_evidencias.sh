#!/bin/sh
# Helper opcional: executa uma sequência de testes e grava saídas reais em shared/evidencias.
# Rode DEPOIS de "kathara lstart". Não substitui a conferência manual/tcpdump.
set -u

DIR="shared/evidencias"
mkdir -p "$DIR"

capture() {
    file="$1"
    device="$2"
    command="$3"
    echo "### $device: $command" > "$DIR/$file"
    kathara exec --wait "$device" "$command" >> "$DIR/$file" 2>&1 || true
}

# Estado inicial e endereçamento.
capture 00_enderecos_fw.txt fw "ip -br addr; echo; ip route"
capture 00_enderecos_r0.txt r0 "ip -br addr; echo; ip route"

# BASELINE.
kathara exec --wait fw "/root/firewall/baseline.sh" >/dev/null 2>&1 || true
capture 01_baseline_web.txt pc1 "curl --connect-timeout 3 -v http://10.0.2.10"
capture 01_baseline_ping_dmz.txt pc1 "ping -c 3 -W 1 10.0.2.10"
capture 01_baseline_internet.txt pc1 "ping -c 3 -W 1 8.8.8.8"

# PERÍMETRO.
kathara exec --wait fw "/root/firewall/perimeter.sh" >/dev/null 2>&1 || true
capture 02_perimetro_regras.txt fw "/root/firewall/show_rules.sh"
capture 02_perimetro_web.txt pc1 "curl --connect-timeout 3 -v http://10.0.2.10"
capture 02_dmz_para_lan_bloqueado.txt web "ping -c 3 -W 1 10.0.1.10"

# L2: pc1 e pc2 funcionam antes; pc2 deixa de funcionar depois.
kathara exec --wait fw "/root/firewall/baseline.sh" >/dev/null 2>&1 || true
capture 03_l2_antes_pc1.txt pc1 "curl --connect-timeout 3 -v http://10.0.2.10"
capture 03_l2_antes_pc2.txt pc2 "curl --connect-timeout 3 -v http://10.0.2.10"
kathara exec --wait fw "/root/firewall/l2_block_pc2.sh" >/dev/null 2>&1 || true
capture 03_l2_depois_pc1.txt pc1 "curl --connect-timeout 3 -v http://10.0.2.10"
capture 03_l2_depois_pc2.txt pc2 "curl --connect-timeout 3 -v http://10.0.2.10"
capture 03_l2_regras.txt fw "iptables -L FORWARD -n -v --line-numbers"

# L3 ICMP.
kathara exec --wait fw "/root/firewall/baseline.sh" >/dev/null 2>&1 || true
capture 04_l3_icmp_antes.txt pc1 "ping -c 3 -W 1 10.0.2.10"
kathara exec --wait fw "/root/firewall/l3_block_icmp.sh" >/dev/null 2>&1 || true
capture 04_l3_icmp_depois.txt pc1 "ping -c 3 -W 1 10.0.2.10"
capture 04_l3_icmp_regras.txt fw "iptables -L FORWARD -n -v --line-numbers"

# L3 destino.
kathara exec --wait fw "/root/firewall/baseline.sh" >/dev/null 2>&1 || true
capture 05_l3_destino_antes.txt pc1 "curl --connect-timeout 3 -v http://10.0.2.10"
kathara exec --wait fw "/root/firewall/l3_block_destino.sh" >/dev/null 2>&1 || true
capture 05_l3_destino_depois.txt pc1 "curl --connect-timeout 3 -v http://10.0.2.10"

# L4. Inicia servidor de teste e compara antes/depois.
kathara exec --wait web "pkill -f l4_test_server.py 2>/dev/null || true; nohup python3 /root/l4_test_server.py >/tmp/l4-test.log 2>&1 &" >/dev/null 2>&1 || true
sleep 1
kathara exec --wait fw "/root/firewall/baseline.sh" >/dev/null 2>&1 || true
capture 06_l4_antes.txt pc1 "python3 /root/test_l4.py"
kathara exec --wait fw "/root/firewall/l4_block_p2p.sh" >/dev/null 2>&1 || true
capture 06_l4_depois.txt pc1 "python3 /root/test_l4.py"
capture 06_l4_regras.txt fw "iptables -L FORWARD -n -v --line-numbers"

# Restaura a política final.
kathara exec --wait fw "/root/firewall/perimeter.sh" >/dev/null 2>&1 || true

echo "Evidências gravadas em $DIR"
echo "Confira os arquivos antes de entregar; falhas de Internet podem depender do ambiente do host."
