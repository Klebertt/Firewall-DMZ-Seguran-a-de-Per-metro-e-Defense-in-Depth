# Laboratório Kathará — Firewall + DMZ + Segurança de Perímetro

## 1. Objetivo

Este repositório implementa a topologia da atividade e contém a política de Segurança de Perímetro, os experimentos L2/L3/L4, uma proposta L7 e a discussão de Defense in Depth.

A configuração final usa **default deny** no firewall e filtragem **stateful** para permitir respostas de conexões autorizadas.

## 2. Topologia e endereçamento

A WAN foi ajustada para seguir o plano da figura: **r0 = 198.51.100.2/30** e **fw = 198.51.100.1/30**.

| Nó/interface | Endereço | Função |
|---|---:|---|
| `r0/eth0` | `198.51.100.2/30` | Gateway WAN do firewall |
| `r0/eth1` | dinâmico (bridged) | Saída para rede do host/Internet |
| `fw/eth0` | `198.51.100.1/30` | WAN |
| `fw/eth1` | `10.0.1.1/24` | Gateway LAN |
| `fw/eth2` | `10.0.2.1/24` | Gateway DMZ |
| `fw/eth3` | `10.0.3.1/24` | Gateway MGMT |
| `pc1` | `10.0.1.10/24` | Cliente LAN |
| `pc2` | `10.0.1.11/24` | Cliente LAN |
| `web` | `10.0.2.10/24` | Servidor HTTP da DMZ |
| `dns` | `10.0.2.11/24` | Servidor DNS da DMZ |
| `adm` | `10.0.3.10/24` | Gerenciamento opcional |

MACs fixados para o experimento L2:

- `pc1`: `02:42:0a:00:01:0a`
- `pc2`: `02:42:0a:00:01:0b`

O `r0[bridged]="true"` adiciona uma interface ligada à rede do host via NAT. O mapeamento `localhost:8080 -> r0:80` foi mantido apenas para facilitar o teste externo do Web publicado; ele não altera o plano de endereçamento da topologia.

## 3. Estrutura dos arquivos de firewall

Dentro do nó `fw`, os arquivos desta pasta do repositório aparecem em `/root/firewall/`:

- `baseline.sh` — deixa o firewall sem filtragem restritiva;
- `perimeter.sh` — aplica a política final de perímetro;
- `l2_block_pc2.sh` — bloqueia o MAC fixo de `pc2`;
- `l3_block_icmp.sh` — bloqueia ICMP LAN → DMZ;
- `l3_block_destino.sh` — bloqueia o destino de teste `10.0.2.10`;
- `l4_block_p2p.sh` — bloqueia TCP/UDP `6881:6889`;
- `show_rules.sh` — mostra regras e contadores.

O `fw.startup` sobe o laboratório com a **política final de perímetro ativa**. Para reproduzir a etapa inicial da atividade, execute `baseline.sh` antes dos testes da baseline.

## 4. Inicialização

Na pasta do laboratório:

```bash
kathara lstart
```

Para abrir um nó:

```bash
kathara connect fw
kathara connect pc1
kathara connect pc2
kathara connect web
kathara connect dns
kathara connect r0
```

Ao terminar:

```bash
kathara lclean
```

## 5. Baseline — antes das regras restritivas

No `fw`:

```bash
/root/firewall/baseline.sh
```

### Testes

No `pc1`:

```bash
ping -c 3 10.0.2.10
curl -v http://10.0.2.10
```

DNS:

```bash
dig @10.0.2.11 lab.test A
```

Se `dig` não estiver disponível, use:

```bash
nslookup lab.test 10.0.2.11
```

Internet:

```bash
ping -c 3 8.8.8.8
curl -I http://example.com
```

No `fw`, confirme o encaminhamento:

```bash
tcpdump -ni any
```

### Evidência sugerida

Salve resultados reais na pasta compartilhada:

```bash
ping -c 3 10.0.2.10 2>&1 | tee /shared/evidencias/baseline_ping_dmz.txt
curl -v http://10.0.2.10 2>&1 | tee /shared/evidencias/baseline_web.txt
```

## 6. Segurança de Perímetro

No `fw`:

```bash
/root/firewall/perimeter.sh
/root/firewall/show_rules.sh
```

Política implementada:

| Comunicação | Política |
|---|---|
| LAN → Internet | ✅ Permitir |
| LAN → Web/DNS da DMZ | ✅ Permitir somente os serviços necessários |
| Internet → Web da DMZ | ✅ Permitir TCP/80 |
| Internet → LAN | ❌ Bloquear |
| DMZ → LAN (novas conexões) | ❌ Bloquear |
| Respostas de conexões permitidas | ✅ `ESTABLISHED,RELATED` |

### LAN → Internet

No `pc1`:

```bash
ping -c 3 8.8.8.8
curl -I http://example.com
```

### LAN → Web/DNS

```bash
curl http://10.0.2.10
dig @10.0.2.11 lab.test A
```

### Internet → Web

O `r0` realiza DNAT para `10.0.2.10:80`. A partir do host onde o Kathará está rodando, teste:

```bash
curl -v http://localhost:8080
```

Também é possível verificar no `r0`:

```bash
iptables -t nat -L -n -v
iptables -L FORWARD -n -v
```

### Internet → LAN e DMZ → LAN

Não existem regras `NEW` permitindo esses fluxos no `fw`; portanto, eles terminam no `FORWARD DROP`.

Uma tentativa iniciada no `web` em direção a `pc1`, por exemplo, não deve passar quando `perimeter.sh` está ativo:

```bash
# no web
ping -c 3 10.0.1.10
```

A resposta de uma conexão iniciada e permitida pela LAN continua funcionando pela regra `ESTABLISHED,RELATED`.

## 7. Experimento L2 — bloquear `pc2` pelo MAC

O MAC de `pc2` foi fixado no `lab.conf`, evitando que a regra dependa de um endereço aleatório.

### Antes

No `fw`:

```bash
/root/firewall/baseline.sh
```

No `pc1` e no `pc2`:

```bash
curl http://10.0.2.10
```

Os dois devem alcançar o Web.

### Regra

No `fw`:

```bash
/root/firewall/l2_block_pc2.sh
iptables -L FORWARD -n -v --line-numbers
```

### Depois

Repita o `curl` em `pc1` e `pc2`. `pc1` continua funcionando; `pc2` é bloqueado.

Observe o enlace LAN:

```bash
tcpdump -eni eth1
```

### Investigação

O endereço MAC **não acompanha o pacote por toda a Internet**. MAC pertence ao enlace local e o cabeçalho de camada 2 é substituído a cada salto de roteamento. O `fw` consegue enxergar o MAC original de `pc2` porque `pc2` e `fw/eth1` estão no mesmo domínio Ethernet da LAN. Se houvesse um roteador L3 entre eles, o firewall enxergaria o MAC desse próximo salto, não o MAC original de `pc2`.

## 8. Experimentos L3

### A. ICMP entre LAN e DMZ

**Antes:**

```bash
# fw
/root/firewall/baseline.sh

# pc1
ping -c 4 10.0.2.10
```

No `fw`, pode-se observar em outro terminal:

```bash
tcpdump -ni any icmp
```

**Regra:**

```bash
# fw
/root/firewall/l3_block_icmp.sh
```

**Depois:**

```bash
# pc1
ping -c 4 10.0.2.10
```

O segundo ping deve falhar e o contador da regra deve aumentar:

```bash
iptables -L FORWARD -n -v --line-numbers
```

### B. Bloquear um destino IP

Usamos `10.0.2.10` como destino controlado do laboratório.

**Antes:**

```bash
# fw
/root/firewall/baseline.sh

# pc1
curl -v http://10.0.2.10
```

**Regra:**

```bash
# fw
/root/firewall/l3_block_destino.sh
```

**Depois:**

```bash
# pc1
curl --connect-timeout 3 -v http://10.0.2.10
```

Bloquear apenas um IP não é uma solução completa para impedir acesso a um site: um domínio pode resolver para vários IPs; um mesmo IP pode hospedar vários sites; CDNs e serviços em nuvem podem mudar os endereços. Controles por domínio ou aplicação dão mais contexto.

## 9. Experimento L4 — bloqueio de serviço por TCP/UDP

A faixa `6881:6889` é usada para representar uma política de bloqueio de P2P/BitTorrent. O objetivo do experimento é demonstrar filtragem por protocolo e porta, não executar BitTorrent.

No `web`, inicie o servidor de teste:

```bash
python3 /root/l4_test_server.py
```

### Antes

No `fw`:

```bash
/root/firewall/baseline.sh
```

No `pc1`:

```bash
python3 /root/test_l4.py
```

O esperado é obter resposta em TCP e UDP na porta 6881.

### Regra

No `fw`:

```bash
/root/firewall/l4_block_p2p.sh
```

### Depois

No `pc1`:

```bash
python3 /root/test_l4.py
```

Agora TCP e UDP devem falhar. No `fw`:

```bash
tcpdump -ni any 'tcp port 6881 or udp port 6881'
iptables -L FORWARD -n -v --line-numbers
```

### Investigação

Bloquear portas não garante que uma aplicação não funcione. Aplicações podem escolher portas alternativas ou dinâmicas e, em alguns casos, usar portas comuns a outros serviços. Uma política mais forte pode exigir identificação de aplicações, inspeção de protocolo e controles em L7, com atenção a criptografia, evasão e falsos positivos.

## 10. L7 — proposta para discussão

Uma possibilidade é um **WAF (Web Application Firewall)** diante do servidor Web.

Ele pode analisar elementos da comunicação HTTP, como método, URL, cabeçalhos, parâmetros e corpo da requisição, permitindo políticas como bloquear `/admin`, permitir `/public` e reconhecer padrões de ataques à aplicação.

Outros controles possíveis são DNS Filtering, proxy, Application Firewall e NGFW. Para esta atividade, L7 é apenas pesquisado e explicado; não precisa ser implementado.

## 11. Defense in Depth

Se o servidor `web` da DMZ for comprometido, isso **não significa acesso direto automático** a `pc1` e `pc2`.

Ainda existem várias camadas de proteção:

1. **DMZ e segmentação:** Web e LAN estão em redes distintas.
2. **Firewall stateful:** a política final não permite novas conexões DMZ → LAN.
3. **Default deny:** o que não foi explicitamente autorizado é descartado.
4. **Filtragem L3/L4:** redes, IPs, protocolos e portas podem ser restringidos.
5. **Controles nos próprios serviços:** autenticação, atualização, permissões e hardening reduzem o impacto de um comprometimento.
6. **Monitoramento:** logs, contadores do `iptables` e capturas ajudam a identificar tentativas indevidas.
7. **MGMT separada:** a rede de gerenciamento também fica segmentada.

Isso representa **Defense in Depth**: a segurança não depende de uma única barreira; se uma camada falhar, outras ainda limitam movimento lateral e alcance do ataque.

## 12. Evidências — formato pedido no enunciado

Para cada experimento, registre exatamente:

> **Antes da regra → Regra implementada → Depois da regra**

A pasta `shared/evidencias/` é montada como `/shared/evidencias/` dentro dos nós e pode receber saídas reais dos comandos. Exemplos:

```bash
iptables -L FORWARD -n -v --line-numbers 2>&1 | tee /shared/evidencias/regras.txt
ping -c 4 10.0.2.10 2>&1 | tee /shared/evidencias/l3_ping.txt
```

As evidências devem ser produzidas durante a execução local do laboratório; resultados não foram inventados dentro deste repositório.

Para facilitar, há também o script opcional `coletar_evidencias.sh`. Depois de iniciar o laboratório, execute no host:

```bash
./coletar_evidencias.sh
```

Ele grava uma sequência de saídas reais em `shared/evidencias/`. Revise os arquivos e complemente com `tcpdump`/Wireshark quando necessário.

## 13. Respostas finais

**Quem pode se comunicar com quem?**  
A LAN pode iniciar conexões para a Internet e para os serviços Web/DNS autorizados na DMZ. A Internet pode iniciar HTTP para o Web publicado. Internet → LAN e novas conexões DMZ → LAN são bloqueadas.

**Que tipos de comunicação são permitidos ou bloqueados?**  
A decisão combina origem/destino, estado da conexão, protocolo e porta. Os experimentos também demonstram bloqueio por MAC, ICMP, IP de destino e portas TCP/UDP.

**Se uma camada falhar, quais outras ainda protegem a infraestrutura?**  
Segmentação, DMZ, firewall stateful/default deny, filtros de rede/transporte e controles locais nos serviços continuam reduzindo o alcance do ataque.
