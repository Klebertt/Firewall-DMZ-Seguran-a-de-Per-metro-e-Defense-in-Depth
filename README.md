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

Experimento L3: Isolamento DMZ -> LAN
Antes: Sem restrição de firewall, a DMZ conseguia pingar a LAN.

Regras no fw:

Bash
iptables -P FORWARD DROP
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth1 -s 10.0.1.0/24 -o eth2 -d 10.0.2.10 -p tcp --dport 80 -j ACCEPT
Depois: O teste ping -c 2 10.0.1.10 executado no web retorna 100% de perda (Timeout). A LAN continua acessando a Web pois o pacote de volta passa pelo estado ESTABLISHED.

Experimento L4: Bloqueio de Portas BitTorrent (P2P)
Antes: Conexões em portas altas passavam direto pelo firewall.

Regra no fw:

Bash
iptables -A FORWARD -p tcp --dport 6881:6889 -j DROP
Depois: O teste de porta nc -zv -w 2 10.0.2.10 6881 no pc1 dá Timeout, confirmando que os pacotes TCP na faixa 6881-6889 foram descartados.

## 3. Análise Teórica
1. Camada 2 (Enlace)
Para que serve: Garante o bloqueio de um dispositivo específico na rede local, independente do IP configurado nele.

Limitação: O endereço MAC trafega em texto claro na LAN. Qualquer usuário na rede pode capturar um MAC permitido e fazer MAC Spoofing para burlar o filtro.

2. Camada 3 (Rede)
Firewall Stateful vs Stateless: O firewall stateful acompanha a tabela de conexões (conntrack). Ele entende a diferença entre uma nova conexão vinda de fora e um pacote que é apenas a resposta de algo que a LAN pediu, dispensando a abertura manual de portas de retorno.

3. Camada 4 (Transporte)
Filtro de Porta vs DPI: O bloqueio por porta só funciona se o programa usar a porta padrão. Se um cliente BitTorrent usar a porta 443 (HTTPS), o iptables comum deixa passar. Para pegar isso, é necessário usar inspeção profunda (DPI), que analisa o conteúdo interno dos pacotes.

4. Camada 7 (Aplicação)
Limitação do iptables: O iptables lê apenas os cabeçalhos de rede e transporte. Ele não consegue identificar se uma requisição HTTP traz um ataque de SQL Injection ou código malicioso no corpo da mensagem.

## 4. Proposta de Controle em Camada 7 (L7)
Para adicionar proteção na Camada 7, a solução é instalar um WAF (Web Application Firewall) como o ModSecurity integrado a um proxy reverso Nginx na frente do servidor Web.

O WAF analisa o tráfego HTTP/HTTPS por completo (headers, cookies e dados POST) e aplica as regras do OWASP CRS para barrar ataques de aplicação (SQLi, XSS, upload de shells) antes que cheguem ao servidor final.

## 5. Defesa em Profundidade (Defense in Depth)
A rede foi montada em camadas para que a falha de uma proteção não comprometa todo o sistema:

Se o servidor Web for invadido via falha em L7, as regras em L3/L4 do firewall impedem que o atacante acesse a rede interna (LAN).

Se alguém tentar trocar o IP na rede local para burlar o roteamento (L3), a trava por MAC em L2 ainda barra o acesso.
