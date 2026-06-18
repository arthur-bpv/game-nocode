# Game Design Document

## Conceito Geral

Jogo top-down estilo Among Us ambientado dentro de uma placa-mãe vista de cima.
O jogador é um robô que transita por trilhas, corredores e salas — a estrutura física representa uma infraestrutura de rede.

Suporta **single player** e **multiplayer** (listen server).

---

## Tema e Objetivo Educacional

Antes de iniciar uma sessão, o jogador escolhe uma **temática de aprendizado**.
Cada temática gera um conjunto de problemas e tarefas relacionados ao tema escolhido.

**Primeiro objetivo:** TCP/IP e Modelo OSI

---

## Dinâmica de Jogo

### Sessão
- A sessão começa com vários **problemas de rede ativos** no mapa
- O jogador/equipe deve identificar e resolver cada problema
- Os problemas são gerados de acordo com a temática escolhida

### Resolução de Problemas
Os problemas têm duas camadas:

1. **Camada lógica** — resolvida no terminal (comandos, diagnóstico)
2. **Camada física** — resolvida no mapa (ir até o dispositivo com problema)

Exemplo de fluxo completo:
```
Terminal mostra switch desconectado (cabo vermelho na topologia)
  → Jogador vai até o roteador pelo mapa
  → Conecta o switch fisicamente
  → Volta ao terminal
  → Topologia atualiza (cabo verde)
  → Pode agora verificar tráfego, PCs conectados, etc.
```

---

## Mapa

- Ambientado dentro de uma **placa-mãe vista de cima**
- Corredores = trilhas da placa
- Salas maiores = chips, switches, roteadores
- Dispositivos de rede ficam em posições físicas no mapa

### Navegação entre Redes
- Existem **portas lógicas de rede** que funcionam como portais de transição de mapa
- O jogador entra em uma porta e transita para outra região da rede (ex: do lado do PC para o lado do roteador)
- Cada transição é uma mudança de cena com animação

---

## Tablet (Interface Principal)

### Posicionamento
- Tablets ficam nas bordas do mapa
- Têm `Area2D` que detecta proximidade do player
- Ao se aproximar: mostra indicador de interação
- Ao pressionar `E`: abre a interface

### Interface do Tablet

Dividida em dois painéis:

#### Painel Esquerdo — Terminal
- Estilo terminal Linux (inspiração: zsh)
- Aceita input de texto direto
- **Autosuggestions** enquanto o jogador digita
- **Preview de comandos disponíveis** (ajuda contextual)
- Arquivo de lógica separado que interpreta cada comando e retorna resultado
- Comandos temáticos: ping, traceroute, ifconfig, verificação de tráfego, etc.

#### Painel Direito — Topologia de Rede
- Visualização gráfica dos dispositivos e conexões
- Atualiza em tempo real conforme o estado da rede muda
- **Cabo verde** = dispositivo conectado e funcionando
- **Cabo vermelho** = dispositivo desconectado ou com problema
- Clicável para detalhes de cada dispositivo

#### Caixa de Sugestões (opcional)
- Aparece quando há um problema complexo ativo
- Dá dicas contextuais sobre o que fazer

---

## Arquitetura Técnica Planejada

### Terminal
- Arquivo de lógica de comandos independente (fácil de expandir com novos comandos)
- Cada comando retorna um resultado estruturado que o terminal renderiza
- Estado da rede é um objeto centralizado que o terminal e a topologia consultam

### Topologia
- Estado de cada dispositivo (conectado/desconectado, IP, etc.) guardado em um recurso central
- A visualização lê esse estado e atualiza os cabos/ícones
- Quando o jogador resolve um problema físico no mapa, o estado é atualizado e a topologia reflete

### Multiplayer
- Lógica de movimento já separada (handle_movement_deceleration recebe direction como parâmetro)
- Estado da rede compartilhado via MultiplayerSynchronizer
- Cada jogador tem autoridade sobre o próprio personagem
- Host = listen server com autoridade sobre o estado do mundo

---

## Temáticas Planejadas

| Temática | Problemas Gerados |
|---|---|
| TCP/IP e Modelo OSI | Cabos desconectados, IPs errados, rotas quebradas, pacotes perdidos |
| (futuras) | ... |

---

## Próximos Passos de Desenvolvimento

1. Tablet com Area2D e detecção de proximidade
2. Interface do tablet (terminal + topologia)
3. Lógica de interpretação de comandos
4. Sistema de estado da rede
5. Geração de problemas por temática
6. Transições de mapa (portas lógicas)
7. Multiplayer
