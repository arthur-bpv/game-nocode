# Design: Tablet como menu geral do jogador (Fase 1a)

**Status:** aprovado pelo usuário em 2026-08-13, pronto pra virar plano de implementação.

## Contexto

O tablet hoje (`scenes/tablet/TabletUI.tscn` + `tablet_ui.gd`) é um terminal (input/output de comando). O documento de planejamento oficial do projeto (agosto/2026, ver memória `contexto-planejamento-agosto`) descontinua isso: o tablet vira um **menu geral do jogador**, com botão de fechar, painel principal, acesso ao mapa, e atalho a qualquer momento da partida.

Existem mockups prontos (Canva, sem lógica) de 4 telas "NETBOT": páginas 1-3 são o menu principal atual (Singleplayer/Multiplayer, já implementado, não mexer). Página 4 é nova: barra de progresso no topo, botões Missões/Tutorial/Mapa à esquerda, seletor de cor de personagem à direita, botão Iniciar embaixo.

O usuário também forneceu uma imagem de referência de uma moldura de tablet rústico/industrial (frame físico, com botões laterais, área de tela vazia no centro) — essa moldura é o chrome visual que envolve o conteúdo das telas do tablet daqui pra frente, incluindo futuras telas de task (Fase 3, ex: a task de ligar os fios OSI↔TCP/IP).

## Objetivo

Substituir o terminal por um menu funcional, reaproveitando os três gatilhos de abertura (proximidade física, atalho global, fluxo pré-partida) e os padrões de código já validados no projeto (abrir/fechar UI com tratamento de ESC).

## Fora de escopo (Fase 1a)

- Conteúdo real de Missões/Tutorial/Mapa (dependem do sistema de tasks e do mapa real — Fase 2/3). Aqui só precisam existir como placeholder funcional (clicável, mostra algo tipo "em breve").
- Telas de task (ligar fios, esteira, rack OSI) — usam a mesma moldura de tablet no futuro, mas não fazem parte desta fase.
- Correção dos bugs de ESC/Voltar/volume/tema em `configurações.tscn`/`volume.tscn`/`Pause.tscn` — isso é Fase 1b, tela diferente, não mexer aqui.

## Arquitetura

**Componente visual compartilhado:** a moldura de tablet (imagem de referência do usuário) vira um `NinePatchRect`/`TextureRect` de fundo em `TabletMenu.tscn`, com a área de conteúdo (Home/Settings) posicionada dentro da região de "tela" da moldura.

**`TabletMenu.tscn`** (Control, novo) — cena única com dois `Panel` filhos alternados por `show()`/`hide()`:
- **`HomePanel`** — painel mínimo: botão Mapa, ícone de engrenagem (⚙ abre `SettingsPanel`), botão fechar (X). Ponto de entrada quando o tablet abre durante o jogo.
- **`SettingsPanel`** (a tela "página 4" do mockup) — barra de progresso, lista Missões/Tutorial/Mapa (placeholders funcionais), seletor de cor, botão contextual embaixo: **"Iniciar"** no fluxo pré-partida standalone, **"Voltar"** quando aberta pela engrenagem in-game (volta pra `HomePanel`).

Um script só, `tablet_menu.gd`, espelhando o padrão de `open_ui()`/`_close_ui()`/tratamento de `ui_cancel` que já existe e funciona em `tablet_ui.gd`.

**`PlayerData`** (autoload, novo) — singleton simples, `var player_color: Color`. Sobrevive à troca de cena entre a tela de setup pré-partida (`menu.tscn`) e o mundo (`world.tscn`).

## Gatilhos de abertura

1. **Proximidade** (existente, `tablet.torch`, sem mudança) → chama `open_ui()` em `TabletMenu`, abre em `HomePanel`.
2. **Tecla `Tab`** (nova input action `toggle_tablet`), tratada em `_unhandled_input` de `TabletMenu` — abre/fecha de qualquer lugar do mapa durante a partida, não depende de proximidade.
3. **Fluxo pré-partida** — botões Singleplayer/Multiplayer em `menu.tscn` abrem `SettingsPanel` direto (sem `HomePanel`), com "Iniciar" no lugar de "Voltar"; "Iniciar" chama `change_scene_to_file("res://scenes/world/world.tscn")`.

`TabletMenu` recebe o contexto via `@export var pregame_mode: bool`, setado diferente na instância usada em `menu.tscn` (true) vs `world.tscn` (false) — decide se `SettingsPanel` mostra "Iniciar" ou "Voltar".

## Fluxo de dados

- Clique numa cor em `SettingsPanel` → `PlayerData.player_color = cor` (atribuição direta, sem sinal).
- `player.tscn` em `_ready()` lê `PlayerData.player_color` e aplica em `modulate` do `AnimatedSprite2D`.

## Tratamento de erro

Nenhum caso crítico. Se o jogador não escolher cor, usa um valor default (branco/sem tint) — sem necessidade de validação adicional.

## Teste manual (critério de aceite)

- Abrir pelo tablet físico (proximidade) → `HomePanel`.
- Abrir por `Tab` de qualquer ponto do mapa (longe do tablet físico) → `HomePanel`.
- Fechar com X e com ESC, nos dois painéis.
- Engrenagem em `HomePanel` → abre `SettingsPanel` com botão "Voltar"; "Voltar" retorna a `HomePanel`.
- Trocar de cor em `SettingsPanel` → sprite do player muda.
- Fluxo pré-partida completo: menu principal → Singleplayer → `SettingsPanel` (com "Iniciar") → Iniciar → `world.tscn`, player já com a cor escolhida.
- Placeholders de Missões/Tutorial/Mapa são clicáveis e mostram algo (não crasham, não ficam mudos).
