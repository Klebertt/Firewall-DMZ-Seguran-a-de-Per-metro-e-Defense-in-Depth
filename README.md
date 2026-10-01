# Firewall, DMZ e Defense in Depth no Kathará

Laboratório de segurança de redes desenvolvido no **Kathará**, com foco em firewall, DMZ, filtragem de tráfego e Defense in Depth.

## 1. Sobre o trabalho

Neste laboratório foi montada no Kathará uma rede com LAN, DMZ, rede de gerenciamento, um roteador de borda (`r0`) e um firewall (`fw`).

A ideia é começar com a rede funcionando normalmente e, depois, aplicar regras de segurança para controlar quais comunicações podem ou não passar pelo firewall. Também são feitos testes em diferentes camadas da rede, usando MAC, IP, ICMP e portas TCP/UDP.

A topologia usada é a mesma do enunciado.

## 2. Topologia e endereçamento

| Dispositivo | Endereço | Função |
|---|---|---|
| `r0/eth1` | `198.51.100.1/30` | Ligação entre o roteador e o firewall |
| `fw/eth0` | `198.51.100.2/30` | Interface WAN do firewall |
| `fw/eth1` | `10.0.1.1/24` | Gateway da LAN |
| `fw/eth2` | `10.0.2.1/24` | Gateway da DMZ |
| `fw/eth3` | `10.0.3.1/24` | Gateway da rede de gerenciamento |
| `pc1` | `10.0.1.10/24` | Estação da LAN |
| `pc2` | `10.0.1.11/24` | Estação da LAN |
| `web` | `10.0.2.10/24` | Servidor Web da DMZ |
| `dns` | `10.0.2.11/24` | Servidor DNS da DMZ |
| `adm` | `10.0.3.10/24` | Máquina de gerenciamento |

Gateways utilizados:

- LAN: `10.0.1.1`
- DMZ: `10.0.2.1`
- MGMT: `10.0.3.1`
- saída do firewall: `198.51.100.1`

## 3. Como iniciar o laboratório

Na pasta do projeto:

```bash
kathara lstart
```

Para entrar em um dispositivo:

```bash
kathara connect pc1
kathara connect pc2
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
curl -I http://example.com
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

Isso permite, por exemplo, que o `pc1` inicie uma conexão com a Internet e receba a resposta normalmente, sem precisar liberar novas conexões vindas da Internet para a LAN.

A política final fica assim:

| Comunicação | Política |
|---|---|
| LAN → Internet | Permitida |
| LAN → Web/DNS da DMZ | Permitida |
| Internet → Web | Permitida na porta 80 |
| Internet → LAN | Bloqueada |
| DMZ → LAN em novas conexões | Bloqueada |
| Respostas de conexões permitidas | Permitidas |

As regras podem ser conferidas com:

```bash
iptables -L FORWARD -n -v --line-numbers
```

## 6. Testes da política de perímetro

### LAN para Internet

No `pc1`:

```bash
ping -c 3 8.8.8.8
curl -I http://example.com
```

### LAN para a DMZ

Para testar o servidor Web:

```bash
curl http://10.0.2.10
```

Para testar o DNS:

```bash
dig @10.0.2.11 lab.test
```

### Internet para o servidor Web

O `r0` faz um DNAT da porta TCP 80 para o servidor `10.0.2.10`.

A regra usada é:

```bash
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 \
    -j DNAT --to-destination 10.0.2.10:80
```

Assim, uma conexão recebida pelo `r0` na porta 80 é encaminhada para o servidor Web da DMZ.

No firewall existe uma regra permitindo esse tráfego:

```bash
iptables -A FORWARD -i eth0 -o eth2 -d 10.0.2.10 \
    -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
```

Já o acesso da Internet diretamente para a LAN continua bloqueado porque não existe uma regra liberando esse fluxo.

## 7. L2 — bloqueio do PC2 pelo endereço MAC

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

## 8. L3 — ICMP e bloqueio por IP

### 8.1 Bloqueio de ICMP

Primeiro pode ser feito um `ping` do `pc1` para o servidor Web:

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

## 9. L4 — bloqueio por portas

Para representar uma política de bloqueio de serviços P2P, foram usadas as portas TCP e UDP de `6881` até `6889`, uma faixa tradicionalmente associada ao BitTorrent.

As regras são:

```bash
iptables -A FORWARD -p tcp --dport 6881:6889 -j DROP
iptables -A FORWARD -p udp --dport 6881:6889 -j DROP
```

Para testar, pode ser aberto temporariamente um serviço na porta 6881 do servidor Web:

```bash
nc -lvkp 6881
```

No `pc1`:

```bash
nc -vz -w 2 10.0.2.10 6881
```

Depois da aplicação da regra, a conexão nessa porta deve ser bloqueada.

Esse tipo de regra também tem limitações. Um programa P2P pode usar outras portas ou escolher portas dinamicamente. Então bloquear uma faixa de portas ajuda, mas não garante que uma aplicação específica seja totalmente impedida de funcionar.

## 10. Controle na camada de aplicação (L7)

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

## 11. Defense in Depth

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
