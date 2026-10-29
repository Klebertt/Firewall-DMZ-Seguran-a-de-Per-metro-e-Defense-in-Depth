# Firewall, DMZ e Defense in Depth no Kathará

Laboratório de segurança de redes desenvolvido no **Kathará**, com foco em firewall, DMZ, filtragem de tráfego e Defense in Depth.

## 1. Sobre o trabalho

<<<<<<< HEAD
Neste laboratório foi montada no Kathará uma rede com LAN, DMZ, rede de gerenciamento, um roteador de borda (`r0`) e um firewall (`fw`).
=======
Neste laboratório foi montada no Kathará uma rede com LAN, DMZ, rede de gerenciamento, um roteador de borda (`r0`) e um firewall (`fw`). A saída da LAN para a Internet passa pelo proxy Squid (`proxy`); o acesso público ao servidor Web passa pelo NGINX Reverse Proxy (`rp`).
>>>>>>> d1501a0 (Defense in Depth)

A ideia é começar com a rede funcionando normalmente e, depois, aplicar regras de segurança para controlar quais comunicações podem ou não passar pelo firewall. Também são feitos testes em diferentes camadas da rede, usando MAC, IP, ICMP e portas TCP/UDP.

A topologia usada é a mesma do enunciado.

## 2. Topologia e endereçamento

| Dispositivo | Endereço | Função |
|---|---|---|
<<<<<<< HEAD
| `r0/eth1` | `198.51.100.1/30` | Ligação entre o roteador e o firewall |
| `fw/eth0` | `198.51.100.2/30` | Interface WAN do firewall |
=======
| `r0/eth0` | `198.51.100.2/30` | Ligação entre o roteador e o firewall |
| `fw/eth0` | `198.51.100.1/30` | Interface WAN do firewall |
>>>>>>> d1501a0 (Defense in Depth)
| `fw/eth1` | `10.0.1.1/24` | Gateway da LAN |
| `fw/eth2` | `10.0.2.1/24` | Gateway da DMZ |
| `fw/eth3` | `10.0.3.1/24` | Gateway da rede de gerenciamento |
| `pc1` | `10.0.1.10/24` | Estação da LAN |
| `pc2` | `10.0.1.11/24` | Estação da LAN |
<<<<<<< HEAD
| `web` | `10.0.2.10/24` | Servidor Web da DMZ |
=======
| `proxy` | `10.0.1.20/24` | Proxy HTTP/HTTPS Squid da LAN |
| `rp` | `10.0.2.10/24` | NGINX Reverse Proxy da DMZ |
| `web` | `10.0.2.20/24` | Servidor Web da DMZ, acessível pelo `rp` |
>>>>>>> d1501a0 (Defense in Depth)
| `dns` | `10.0.2.11/24` | Servidor DNS da DMZ |
| `adm` | `10.0.3.10/24` | Máquina de gerenciamento |

Gateways utilizados:

- LAN: `10.0.1.1`
- DMZ: `10.0.2.1`
- MGMT: `10.0.3.1`
<<<<<<< HEAD
- saída do firewall: `198.51.100.1`
=======
- endereço WAN do firewall: `198.51.100.1` (gateway: `198.51.100.2`)

Os fluxos principais são:

- Saída: `pc1/pc2 → proxy (10.0.1.20:3128) → fw → Internet`.
- Entrada Web: `Internet → r0 → fw → rp (10.0.2.10:80/443) → web (10.0.2.20:80)`.
- O servidor `web` não recebe encaminhamento direto da Internet.
>>>>>>> d1501a0 (Defense in Depth)

## 3. Como iniciar o laboratório

Na pasta do projeto:

```bash
kathara lstart
```

Para entrar em um dispositivo:

```bash
kathara connect pc1
kathara connect pc2
<<<<<<< HEAD
=======
kathara connect proxy
kathara connect rp
>>>>>>> d1501a0 (Defense in Depth)
kathara connect web
kathara connect dns
kathara connect fw
kathara connect r0
```

Para encerrar o laboratório:

```bash
kathara lclean
```

## 4. Baseline da rede

Antes de aplicar as regras restritivas, a primeira etapa é verificar se o endereçamento e o roteamento estão funcionando.

No firewall, as regras podem ser temporariamente limpas e as políticas deixadas como `ACCEPT`:

```bash
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
sysctl -w net.ipv4.ip_forward=1
```

No `r0`, o NAT de saída precisa continuar ativo:

```bash
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

Alguns testes que podem ser feitos a partir do `pc1`:

```bash
ping -c 3 10.0.1.1
ping -c 3 10.0.2.10
curl http://10.0.2.10
```

Para testar o DNS:

```bash
dig @10.0.2.11 lab.test
```

E, caso o ambiente esteja com acesso externo funcionando:

```bash
ping -c 3 8.8.8.8
<<<<<<< HEAD
curl -I http://example.com
=======
curl --proxy http://10.0.1.20:3128 -I http://example.com
>>>>>>> d1501a0 (Defense in Depth)
```

Também é possível acompanhar os pacotes no firewall com:

```bash
tcpdump -ni any
```

Essa etapa serve para confirmar que a rede funciona antes de começar os bloqueios.

## 5. Firewall de perímetro

Depois da baseline, o `fw.startup` aplica a política de segurança.

A ideia principal é usar **default deny**: o tráfego é bloqueado por padrão e só é liberado quando existe uma regra permitindo.

As políticas principais são:

```bash
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
```

O firewall também aceita pacotes de conexões que já foram estabelecidas:

```bash
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

<<<<<<< HEAD
Isso permite, por exemplo, que o `pc1` inicie uma conexão com a Internet e receba a resposta normalmente, sem precisar liberar novas conexões vindas da Internet para a LAN.
=======
Isso permite que as respostas do Squid e do NGINX retornem sem liberar novas conexões iniciadas pela Internet para a LAN.
>>>>>>> d1501a0 (Defense in Depth)

A política final fica assim:

| Comunicação | Política |
|---|---|
<<<<<<< HEAD
| LAN → Internet | Permitida |
| LAN → Web/DNS da DMZ | Permitida |
| Internet → Web | Permitida na porta 80 |
=======
| LAN → Internet diretamente | Bloqueada |
| LAN → Internet via Squid | Permitida para HTTP/HTTPS |
| LAN → NGINX/DNS da DMZ | Permitida |
| NGINX → Web da DMZ | Permitida na porta 80 |
| Internet → NGINX | Permitida nas portas 80/443 |
| Internet → Web diretamente | Bloqueada |
| NGINX → Internet | Limitada a HTTP/HTTPS e DNS para pacotes do serviço |
>>>>>>> d1501a0 (Defense in Depth)
| Internet → LAN | Bloqueada |
| DMZ → LAN em novas conexões | Bloqueada |
| Respostas de conexões permitidas | Permitidas |

As regras podem ser conferidas com:

```bash
iptables -L FORWARD -n -v --line-numbers
```

## 6. Testes da política de perímetro

### LAN para Internet

<<<<<<< HEAD
No `pc1`:

```bash
ping -c 3 8.8.8.8
curl -I http://example.com
```

### LAN para a DMZ

Para testar o servidor Web:
=======
Os scripts de `pc1` e `pc2` exportam `http_proxy` e `https_proxy` para sessões de shell de login. Para verificar de forma explícita, use `curl` com a URL do Squid:

```bash
curl --proxy http://10.0.1.20:3128 -I http://example.org
curl --proxy http://10.0.1.20:3128 -I https://example.org
```

O acesso direto da LAN à Internet, sem passar pelo Squid, deve ser bloqueado pelo firewall.

## 7. Proxy de saída Squid

O Squid escuta em `10.0.1.20:3128`. O firewall permite que apenas essa máquina inicie conexões de saída HTTP/HTTPS e DNS; os clientes não têm uma rota de saída direta liberada. O proxy autoriza os IPs de `pc1` e `pc2` por ACLs individuais e nega os demais clientes.

### Teste inicial do Forward Proxy

Após iniciar o laboratório, execute nos dois clientes:

```bash
kathara exec --wait pc1 curl --proxy http://10.0.1.20:3128 -I http://example.org
kathara exec --wait pc2 curl --proxy http://10.0.1.20:3128 -I http://example.org
```

Uma resposta HTTP do site (incluindo redirecionamentos) confirma o caminho cliente → Squid → firewall → Internet. Para verificar que o acesso direto não está liberado, compare com `curl -I --connect-timeout 5 http://example.org` sem a opção `--proxy`; a requisição deve falhar.

### ACL de cliente e domínio

O Squid define as ACLs `pc1` e `pc2` em `/etc/squid/squid.conf`. A lista persistente `/root/squid/blocked-domains.txt` é copiada para `/etc/squid/blocked-domains.txt` na inicialização; no estado inicial ela bloqueia `example.com` e seus subdomínios para ambos os clientes.

Teste o bloqueio por domínio:

```bash
kathara exec --wait pc1 curl --proxy http://10.0.1.20:3128 -I http://example.com
kathara exec --wait pc2 curl --proxy http://10.0.1.20:3128 -I http://example.com
```

O resultado esperado é `403 Forbidden` do Squid. A regra usa o domínio solicitado (`dstdomain`), não o endereço IP resolvido; por isso também cobre alterações de IP do domínio.

Para demonstrar uma política diferente por cliente, conecte ao `proxy` e adicione um domínio à ACL exclusiva do `pc2`:

```bash
echo '.example.org' >> /etc/squid/pc2-blocked-domains.txt
squid -k reconfigure
```

Repita a requisição para `example.org` nos dois PCs: o `pc1` continua autorizado, enquanto o `pc2` recebe `403`. Para desfazer o teste e manter a política inicial:

```bash
: > /etc/squid/pc2-blocked-domains.txt
squid -k reconfigure
```

A ordem das regras importa: bloqueios por cliente e domínio vêm antes das permissões `http_access allow pc1` e `http_access allow pc2`.

### Logs e cache

O log de acesso é `/var/log/squid/access.log`; o código/resultados de cada solicitação incluem `TCP_MISS`, `TCP_HIT`, `TCP_TUNNEL` ou `TCP_DENIED`. Observe as entradas enquanto repete uma URL HTTP:

```bash
tail -f /var/log/squid/access.log
```

Em outro terminal de `pc1`, faça duas solicitações:

```bash
curl --proxy http://10.0.1.20:3128 -o /dev/null -sS http://example.org/
curl --proxy http://10.0.1.20:3128 -o /dev/null -sS http://example.org/
```

Se a resposta permitir armazenamento e ainda estiver válida, a segunda solicitação poderá aparecer como `TCP_HIT`; a primeira normalmente aparece como `TCP_MISS`. O cache em memória e em disco está habilitado em `squid.conf`. O Squid não armazena o conteúdo HTTPS neste modo: `CONNECT` cria um túnel TLS e aparece no log como `TCP_TUNNEL`. Cabeçalhos do servidor como `no-store` também impedem cache, então um `MISS` repetido pode ser comportamento correto da origem.

### LAN para a DMZ

Para acessar o servidor Web da DMZ, use o NGINX Reverse Proxy:
>>>>>>> d1501a0 (Defense in Depth)

```bash
curl http://10.0.2.10
```

Para testar o DNS:

```bash
dig @10.0.2.11 lab.test
```

### Internet para o servidor Web

<<<<<<< HEAD
O `r0` faz um DNAT da porta TCP 80 para o servidor `10.0.2.10`.
=======
O `r0` faz DNAT das portas TCP 80 e 443 para o NGINX Reverse Proxy `10.0.2.10`. O NGINX encaminha as requisições ao servidor Web `10.0.2.20`. O laboratório gera um certificado autoassinado para HTTPS; clientes de teste devem confiar nele ou ignorar a validação do certificado.
>>>>>>> d1501a0 (Defense in Depth)

A regra usada é:

```bash
<<<<<<< HEAD
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 \
    -j DNAT --to-destination 10.0.2.10:80
```

Assim, uma conexão recebida pelo `r0` na porta 80 é encaminhada para o servidor Web da DMZ.
=======
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 \
    -j DNAT --to-destination 10.0.2.10:80
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 443 \
    -j DNAT --to-destination 10.0.2.10:443
```

Assim, as conexões recebidas pelo `r0` nas portas 80 e 443 são encaminhadas para o NGINX na DMZ. O NGINX e o servidor Web estão na mesma sub-rede da DMZ; o NGINX encaminha as requisições HTTP ao `web`.
>>>>>>> d1501a0 (Defense in Depth)

No firewall existe uma regra permitindo esse tráfego:

```bash
iptables -A FORWARD -i eth0 -o eth2 -d 10.0.2.10 \
<<<<<<< HEAD
    -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
```

Já o acesso da Internet diretamente para a LAN continua bloqueado porque não existe uma regra liberando esse fluxo.

## 7. L2 — bloqueio do PC2 pelo endereço MAC
=======
    -p tcp -m multiport --dports 80,443 \
    -m conntrack --ctstate NEW -j ACCEPT
```

O firewall encaminha somente para o NGINX. O servidor `web` (`10.0.2.20`) não é destino do DNAT e não tem regra para novas conexões vindas da Internet. Já o acesso da Internet diretamente para a LAN continua bloqueado porque não existe uma regra liberando esse fluxo.

## 8. L2 — bloqueio do PC2 pelo endereço MAC
>>>>>>> d1501a0 (Defense in Depth)

Nesse experimento, o `pc2` é tratado como um dispositivo comprometido.

Primeiro é necessário descobrir o MAC da interface dele:

```bash
ip link show eth0
```

Também é possível verificar pelo firewall:

```bash
ip neigh show 10.0.1.11
```

Depois, o MAC real deve ser colocado na variável `PC2_MAC` do `fw.startup`.

A regra de bloqueio é:

```bash
iptables -I FORWARD 1 -i eth1 -m mac --mac-source MAC_DO_PC2 -j DROP
```

Antes da regra, `pc1` e `pc2` devem conseguir gerar tráfego normalmente. Depois da regra, o esperado é que o `pc2` seja bloqueado e o `pc1` continue funcionando.

Exemplos de teste:

```bash
ping -c 3 10.0.2.10
curl http://10.0.2.10
```

O tráfego pode ser observado no firewall com:

```bash
tcpdump -eni eth1
```

O endereço MAC funciona apenas no enlace local. Quando um pacote passa por um roteador, o cabeçalho de camada 2 é trocado. Por isso, o MAC original do `pc2` não acompanha o pacote durante todo o caminho até a Internet.

Nesse laboratório o firewall consegue ver o MAC do `pc2` porque ele está diretamente ligado à LAN. Também é importante lembrar que um endereço MAC pode ser falsificado, então esse tipo de bloqueio não deve ser usado como única proteção.

<<<<<<< HEAD
## 8. L3 — ICMP e bloqueio por IP

### 8.1 Bloqueio de ICMP

Primeiro pode ser feito um `ping` do `pc1` para o servidor Web:
=======
## 9. L3 — ICMP e bloqueio por IP

### 8.1 Bloqueio de ICMP

Primeiro pode ser feito um `ping` do `pc1` para o NGINX Reverse Proxy:
>>>>>>> d1501a0 (Defense in Depth)

```bash
ping -c 4 10.0.2.10
```

No firewall, o ICMP pode ser acompanhado com:

```bash
tcpdump -ni any icmp
```

Depois é aplicada a regra:

```bash
iptables -I FORWARD 1 -i eth1 -o eth2 -p icmp -j DROP
```

Ao repetir o `ping`, ele deve deixar de funcionar.

Isso não significa que todo o acesso ao servidor foi bloqueado. Por exemplo, uma requisição HTTP ainda pode funcionar:

```bash
curl http://10.0.2.10
```

Nesse caso o ICMP foi bloqueado, mas o TCP da porta 80 continua permitido.

### 8.2 Bloqueio de um destino IP

Para representar um destino que a organização decidiu bloquear, pode ser usado um endereço do próprio laboratório.

Exemplo:

```bash
iptables -I FORWARD 1 -i eth1 -s 10.0.1.0/24 -d 10.0.2.10 -j DROP
```

Depois da regra, o acesso da LAN ao endereço `10.0.2.10` deve ser bloqueado.

Um bloqueio por IP tem algumas limitações. Um domínio pode usar vários endereços, o endereço pode mudar com o tempo e um mesmo IP pode hospedar vários sites. Por isso, bloquear somente um IP não é uma solução completa para controlar o acesso a um site.

<<<<<<< HEAD
## 9. L4 — bloqueio por portas
=======
## 10. L4 — bloqueio por portas
>>>>>>> d1501a0 (Defense in Depth)

Para representar uma política de bloqueio de serviços P2P, foram usadas as portas TCP e UDP de `6881` até `6889`, uma faixa tradicionalmente associada ao BitTorrent.

As regras são:

```bash
iptables -A FORWARD -p tcp --dport 6881:6889 -j DROP
iptables -A FORWARD -p udp --dport 6881:6889 -j DROP
```

<<<<<<< HEAD
Para testar, pode ser aberto temporariamente um serviço na porta 6881 do servidor Web:
=======
Para testar, pode ser aberto temporariamente um serviço na porta 6881 do servidor `web`:
>>>>>>> d1501a0 (Defense in Depth)

```bash
nc -lvkp 6881
```

No `pc1`:

```bash
<<<<<<< HEAD
nc -vz -w 2 10.0.2.10 6881
=======
nc -vz -w 2 10.0.2.20 6881
>>>>>>> d1501a0 (Defense in Depth)
```

Depois da aplicação da regra, a conexão nessa porta deve ser bloqueada.

Esse tipo de regra também tem limitações. Um programa P2P pode usar outras portas ou escolher portas dinamicamente. Então bloquear uma faixa de portas ajuda, mas não garante que uma aplicação específica seja totalmente impedida de funcionar.

<<<<<<< HEAD
## 10. Controle na camada de aplicação (L7)
=======
## 11. Controle na camada de aplicação (L7)
>>>>>>> d1501a0 (Defense in Depth)

Para L7, uma possibilidade seria usar um **WAF (Web Application Firewall)** na frente do servidor Web.

Diferente das regras anteriores, que olham principalmente MAC, IP, protocolo e porta, um WAF consegue analisar informações da própria aplicação Web, como URL, método HTTP, cabeçalhos, parâmetros e corpo da requisição.

Um exemplo seria permitir:

```text
/public
```

e bloquear:

```text
/admin
```

mesmo que os dois caminhos usem o mesmo IP e a mesma porta.

Uma tecnologia que poderia ser usada nesse cenário é o ModSecurity com regras do OWASP Core Rule Set. Outra opção seria utilizar proxy, DNS Filtering ou um NGFW, dependendo do tipo de controle desejado.

Essa parte não precisa ser implementada na tarefa, apenas estudada e discutida.

<<<<<<< HEAD
## 11. Defense in Depth
=======
## 12. Defense in Depth
>>>>>>> d1501a0 (Defense in Depth)

Mesmo que o servidor Web da DMZ seja comprometido, isso não significa que o atacante terá acesso direto ao `pc1` e ao `pc2`.

O servidor Web está em uma rede separada da LAN. Além disso, o firewall não permite novas conexões da DMZ para a LAN.

Nesse caso, ainda existem várias camadas de proteção:

- separação entre LAN e DMZ;
- firewall com política default deny;
- filtragem por IP, protocolo e porta;
- controle stateful das conexões;
- regras e permissões nos próprios serviços;
- rede de gerenciamento separada;
- monitoramento dos pacotes e logs.

A ideia de **Defense in Depth** é justamente não depender de uma única proteção. Se uma camada falhar, as outras ainda podem limitar o que um atacante consegue alcançar dentro da rede.
