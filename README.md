# Lab Kathará: Firewall Stateful e DMZ

Projeto de segurança de redes simulado via Kathará no Docker/WSL2. O objetivo foi criar uma arquitetura dividida em zonas (LAN, DMZ, MGMT e WAN) e aplicar regras de firewall com `iptables` cobrindo inspeção de estado e filtros de Camada 2, 3 e 4.

---

## 1. Topologia e Política de Perímetro

### Estrutura da Rede
* **`r0`**: Roteador com NAT para saída da internet.
* **`fw`**: Firewall central intermediando os 4 segmentos.
* **LAN (`10.0.1.0/24`)**: Rede interna (`pc1` e `pc2`).
* **DMZ (`10.0.2.0/24`)**: Servidores públicos (`web` em `10.0.2.10` e `dns` em `10.0.2.11`).
* **MGMT (`10.0.3.0/24`)**: Rede de administração (`adm`).

### Regras do Perímetro
* **Bloqueio Padrão (Default DROP):** O tráfego não explicitamente liberado é descartado (`FORWARD DROP` e `INPUT DROP`).
* **Inspeção de Estado:** Retornos de conexões iniciadas pela LAN são permitidos automaticamente via `ESTABLISHED,RELATED`.
* **Isolamento da DMZ:** A DMZ responde a requisições, mas não pode iniciar conexões para a LAN ou MGMT.
* **Acesso Limitado:** A LAN só acessa a DMZ nas portas de serviços essenciais (HTTP/HTTPS e DNS).

---

## 2. Testes e Evidências (L2, L3 e L4)

### Experimento L2: Bloqueio por Endereço MAC
* **Antes:** O `pc2` acessava o servidor Web normalmente (`curl http://10.0.2.10`).
* **Regra no `fw`:**
  ```bash
  iptables -A FORWARD -i eth1 -m mac --mac-source 02:42:0a:00:01:0b -j DROP
