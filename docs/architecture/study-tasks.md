# Disciplinas, temas e tasks

Atualizado em 2026-09-07. Referência desta sessão: `main`, a partir de `origin/main` (`adc3196`).

## Capacidade e limites

Selecionar disciplina e tema antes de entrar no mapa. A disciplina escolhe a cena de mapa;
o tema escolhe suas tasks. A missão comunica sucesso por sinal; o progresso determina
quais tasks podem ser usadas. Manter a arte, colisões, escala do jogador e posição da
missão existentes. Não gerar mapas, inventar atividades ou reconstruir Orchestrator.

O catálogo atual contém Redes de Computadores e **um único tema: TCP/IP + Modelo OSI**
(`tcp_ip_modelo_osi`), conforme correção do usuário em 2026-09-08. A primeira rodada
reúne ambos os modelos; não oferecer OSI e TCP/IP como seleções separadas. A atividade
real de correspondência é a primeira task dessa rodada. O sistema continua permitindo
novos temas e disciplinas, sem que precisem existir placeholders no catálogo.

## Arquitetura encontrada

- `world.tscn` possuía MapSprite, colisões carregadas de Resource e ConectaCamadas
  diretamente instanciada em Entities. A raiz atual não executa `world.torch`.
- `conecta_camadas.gd` conhecia regras e coordenadas dos pinos; ao terminar apenas
  alterava um Label. Não havia evento de conclusão nem progresso externo.
- `main_menu.gd` apontava diretamente para a única cena de mundo.
- O tablet mostrava texto provisório para missões. `PlayerData` só guardava cor.
- `GameManager` continha nível e sinais sem participação neste fluxo; foi preservado.
- `SceneTransition` e `AudioSettings` já resolviam navegação e áudio e foram reutilizados.
- Arquivos `.torch` antigos permanecem; não são fonte do catálogo nem da progressão.

O maior acoplamento era a escolha da missão pela cena visual, junto com a ausência de
identidade, seleção e conclusão observável. As colisões já estavam suficientemente
separadas; não justificavam outra refatoração.

## Decisão do Council

Pergunta: qual etapa intermediária reduz retrabalho sem construir uma plataforma antes
que as próximas missões existam?

- Architect: catálogo mínimo, estado separado e adaptador de mapa. Razões: identidade
  estável, preservação visual e substituição localizada da apresentação. Risco: abstrair
  demais com apenas uma missão disponível.
- Skeptic: primeiro conectar identidade e conclusão; adiar seletor sem opções reais e
  persistência. Principal alerta: OSI/TCP na missão é uma correspondência, não dois cursos.
- Pragmatist: fluxo pequeno de seleção até conclusão, sem fabricar uma segunda atividade.
- Critic: validar IDs/cenas e separar indisponibilidade de bloqueio por progresso.

Consenso: fazer o fluxo completo mínimo e deixar o conteúdo e o mapa como estão.
A divergência mais forte foi o seletor com poucos conteúdos. Ele foi mantido para cumprir
seleção prévia e exercitar isolamento entre temas, com reuso provisório explícito da missão.
A fronteira serializável foi implementada; gravação em disco foi adiada. Não foram criados
factories, barramento global genérico, grafo de dependências ou gerador de mapas.

## Componentes novos

Todos os scripts abaixo estão em `scripts/study/`:

| Arquivo | Responsabilidade |
| --- | --- |
| `task_definition.gd` | Resource StudyTask: ID, título, disponibilidade editorial, cena da missão, slot visual. |
| `topic_definition.gd` | Resource StudyTopic: ID, título, política sequencial e array ordenado de tasks. |
| `discipline_definition.gd` | Resource StudyDiscipline: ID, título, mapa e temas. |
| `study_catalog.gd` | Resource StudyCatalog: disciplinas, busca e validação de IDs, slots e cenas. |
| `task_progress.gd` | RefCounted TaskProgress: conclusões e cálculo de estados, sem acessar nós ou sprites. Snapshot e restauração validados. |
| `study_session.gd` | Autoload StudySession: catálogo, seleção corrente e progresso durante a execução; emite progress_changed. |
| `map_task_slot.gd` | Adaptador Node2D: encontra a task do slot no tema, instancia sua cena, recebe completed e apresenta o estado. |

`data/study/catalog.tres` reúne os Resources de conteúdo. As tasks podem ser extraídas
para `.tres` individuais pelo Inspector sem mudar a lógica. O recurso da atividade atual
é compartilhado entre os temas e tratado como definição, nunca como estado mutável.

Testes novos: `tests/study_progress_test.gd` e `tests/study_runtime_test.gd`.
Documento novo: este arquivo.

## Arquivos existentes modificados

- `project.godot`: registra StudySession.
- `scripts/ui/main_menu.gd`: cria seletores pelo catálogo e navega ao mapa da disciplina.
- `scenes/world/world.tscn`: troca a instância fixa por CamadasSlot na mesma posição
  `(1077, -756)`, com slot ID `armarios_camadas`.
- `scenes/missions/conecta_camadas.gd`: emite completed após sete conexões corretas e
  oferece restore_completed para reconstruir a apresentação concluída.
- `scenes/tablet/tablet_menu.gd`: lista tasks e estados do tema atual.
- `tests/mission_scale_check.ps1`: preserva as verificações de escala usando o novo slot.
- `docs/agentInfo/contextos.md`: aponta para este estado e corrige a referência de branch.

## Contratos e invariantes

```text
StudyDiscipline.map_scene -> cena de mapa
StudyDiscipline.topics -> StudyTopic.tasks -> StudyTask
TaskProgress -> estado -> MapTaskSlot -> cena da missão
cena da missão --completed--> MapTaskSlot -> StudySession -> TaskProgress
```

- IDs não dependem de nome de nó, texto traduzido ou posição no array.
- IDs de disciplina são únicos no catálogo, de tema na disciplina e de task no tema.
- O array `tasks` define a ordem. Não adicionar outro campo numérico de ordem.
- `enabled=false` significa conteúdo ainda indisponível, não bloqueio por progresso.
- Em sequência, a primeira task habilitada só fica disponível se todas as anteriores
  foram concluídas. Uma task desabilitada anterior não concluída impede avançar.
- Estados: `unavailable`, `locked`, `available`, `completed`. Somente conclusões são salvas;
  bloqueios são recalculados. Duplicar conclusão ou concluir task bloqueada retorna false.
- Uma task habilitada por slot por tema. Slots diferentes permitem mais atividades no mapa.
- A missão atual é um Control com tamanho próprio e sinal `completed` sem argumentos.
  O adaptador não conhece respostas, sprites ou nomes internos da missão.
- `restore_completed()` é opcional para reconstruir o visual. A missão atual implementa.
- Tasks concluídas continuam visíveis; as bloqueadas ficam ocultas e sem processamento.
- A seleção ocorre no menu antes da instanciação do mapa. Troca de tema em mapa aberto
  não é suportada: retornar ao menu e entrar novamente recria as atividades do novo tema.
- O progresso sobrevive a sair do mapa e voltar **enquanto o processo está aberto**.
  Fechar o jogo ainda perde o progresso: não existe escrita automática de save nesta etapa.

`TaskProgress.snapshot()` retorna dados simples:

```json
{"version": 1, "completed": {"redes": {"tcp_ip_modelo_osi": ["conecta_camadas"]}}}
```

`StudySession.restore_progress(data)` valida antes de substituir e notifica os observadores.
Dados com versão/formato inválido não apagam o estado anterior. Não persistir Resource,
NodePath, índice, scene instance ou estados de bloqueio. IDs desconhecidos em snapshots
ficam preservados, sem liberar tasks que não existem no catálogo atual. A seleção não faz
parte do snapshot de progresso; decidir sua persistência junto com o save futuro.

## O que continua hardcoded / spritesheet

Permanecem: PNG inteiro do mapa, Resource de colisões, posição dos slots/jogador, arte e
coordenadas dos pinos, equivalência OSI–TCP e construção visual da missão. Não houve
mudança de PNGs, colisões, player ou scripts `.torch`.

Na migração para spritesheet/TileMapLayer, substituir MapSprite e adaptar colisões e
posições dos slots. Preservar os IDs de disciplina/tema/task e os contratos de conclusão.
Um slot pode virar outro ponto de montagem/acionamento sem mudar o cálculo de progresso.
O adaptador atual instancia Controls; missões com outro tipo de raiz exigirão adaptar essa
fronteira quando aparecer um caso real, não expandir o sistema antecipadamente.

## Próxima etapa

1. Definir as próximas atividades e a ordem pedagógica da rodada conjunta TCP/IP + Modelo OSI.
2. Criar cenas reais que emitam completed e cadastrar seus IDs/slots no catálogo.
3. Posicionar os novos slots; validar que todo slot citado existe no mapa da disciplina.
   O validador atual verifica catálogo/caminhos, não inspeciona hierarquias de todas as cenas.
4. Testar a sequência no mapa com o conjunto real. O algoritmo já está pronto e testado
   com três tasks sintéticas, exclusivamente no teste; não foram adicionadas ao conteúdo.
5. Conectar snapshot/restore a um save em `user://`, com escrita segura, tratamento de
   corrupção, política de reset e teste de reinício do processo. Preservar IDs existentes.
6. Com o spritesheet pronto, substituir a apresentação do mapa sem mover regras para ela.

Para adicionar disciplina: definir seu Resource e map_scene, seus temas/tasks e incluir
no catálogo; o menu já lê a coleção. Não duplicar sessão, progresso ou menu.

## Validação desta sessão

Godot 4.6.3 executado localmente (o MCP inicialmente reportou 4.6.stable).

```bash
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/study_progress_test.gd
godot --headless --path . --script res://tests/study_runtime_test.gd
godot --headless --path . --script res://tests/ui_runtime_test.gd
godot --headless --path . --script res://tests/world_map_runtime_test.gd
godot --headless --path . --script res://tests/scene_transition_runtime_test.gd
```

Testes cobrem ordem, bloqueio, conclusão duplicada/inválida, restauração, snapshot isolado,
formato inválido, catálogo inválido, interação correta/incorreta da missão, retorno ao mapa,
isolamento de temas e filtragem sem tasks, além dos fluxos existentes de UI e colisões.
Não há medidor de cobertura GDScript configurado; não foi alegado percentual de cobertura.

MCP 9080: projeto/editor inspecionados e mundo iniciado antes das alterações de gameplay.
Depois das atualizações/importações a conexão ficou indisponível; a verificação final foi
feita pelo executável Godot. Capturas inspecionadas: `.godot/study_menu.png` e
`.godot/study_world.png` (artefatos locais ignorados). O teste de render antigo pode capturar
quadro preto por esperar poucos frames; a inspeção usou frame_post_draw após estabilização.

Avisos preexistentes: UID inválido de ConfirmationModal com fallback por caminho e
recursos ainda em uso ao encerrar o editor headless. Os testes de runtime terminaram com
código 0, sem erros de script ou assertions.

## Git e ambiente

`main` local divergia da remota. Tentativa de merge foi abortada pelos conflitos; a versão
local foi preservada em `backup/main-before-architecture`. `main` foi alinhada à
`origin/main`, sem publicar mudanças. `origin/davi` tem commit exclusivo `2c2158b` e não
foi removida nem integrada. `chore/cleanup-e-classifica-assets` também foi preservada.

Instalado Git LFS 3.7.0 em `~/.local/bin/git-lfs`, configurado localmente para recuperar
PNGs que chegaram como ponteiros. Bytes recuperados foram verificados pelos hashes LFS.
Dois PNGs antigos ainda são blobs Git comuns (Android e ui_background_netbot_menu):
`.git/info/attributes` mantém esses dois fora do filtro no checkout, evitando conversão
incidental. Nenhuma alteração de conteúdo de imagem faz parte desta entrega.

O check PowerShell de escala foi atualizado; `pwsh` não está disponível neste ambiente.
A posição e o tamanho efetivos também foram verificados no teste Godot de runtime.

## Ajuste posterior de câmera (2026-09-07)

Após relato de ghosting no debug, habilitada `physics/common/physics_interpolation`
e configurada Camera2D de `scenes/player/player.tscn` com `process_callback = 0`
(Physics), acompanhando o movimento existente em `_physics_process` do Orchestrator.
Não foi habilitado position smoothing. Verificação local de movimento e pause/resume
passou; a melhora perceptiva do rastro ainda precisa ser confirmada no monitor do usuário.
MCP 9080 continuava indisponível. Referência: documentação Godot sobre jitter/stutter.

Reteste do usuário: interpolação/callback não resolveram o rastro. O usuário descreve
sombra/rastro em janela separada. Probe temporário em `.godot/ghosting_probe.gd` mediu
X11, refresh ~179.98 Hz, VSync ligado, frames medianos 5.546 ms, p95 6.325 ms e máximo
6.708 ms na amostra. Frame renderizado inspecionado sem rastro evidente. Isso não prova
causa no monitor; exibição/compositor ainda são hipóteses. Foi aberta execução temporária
com `--display-driver wayland` para comparação pelo usuário, sem mudar o backend salvo.

Confirmação do usuário: a janela Wayland ficou boa, sem o rastro relatado. Configurado
`display/display_server/driver.linuxbsd="wayland"` em `project.godot`. Execução sem
`--display-driver` confirmou `DisplayServer.get_name() == "Wayland"` e terminou sem
erros de script. A nova janela reportou monitor a 75 Hz (o teste X11 reportava 180 Hz),
portanto os tempos de frame não são comparação direta entre backends. A causa específica
no caminho de exibição não foi isolada, mas a configuração foi validada pelo usuário.
Para diagnóstico/compatibilidade, `--display-driver x11` permite sobrescrever a escolha.


## Artes sem texto e rodada conjunta — 2026-09-08

- Recebidos `armarioOsiNovo.png` (4898×6258) e `armarioTcpNovo.png` (4734×6211).
- Originais copiados integralmente para `assets/ui/classifica/classifica_osi_sem_texto.png`
  e `classifica_tcp_sem_texto.png`. Downloads e artes anteriores preservados.
- Imports com `process/size_limit=1024`: reduz uso de textura em runtime sem reduzir
  o arquivo original. O Godot pode arredondar as dimensões importadas.
- A missão usa OSI_SOURCE_SIZE/TCP_SOURCE_SIZE para manter geometria e hitboxes
  independentes da resolução importada. Largura de cada armário continua 300 unidades.
- Os 11 textos agora são Labels filhos de OsiCabinet/TcpCabinet na cena
  `scenes/missions/conecta_camadas.tscn`: texto, fonte, tamanho, outline e alinhamento
  podem ser editados no Inspector. Âncoras proporcionais às áreas coloridas e mouse
  ignorado nos Labels para preservar o arrastar/soltar da missão.
- Fonte reutilizada: PressStart2P-Regular.ttf. Não é mais texto gravado na imagem.
- Botão X preservado: sua mudança de comportamento ainda não foi definida pelo usuário.
- Catálogo e seleção padrão agora usam `tcp_ip_modelo_osi`. Não existe save em disco
  publicado a migrar. Snapshots manuais experimentais dos IDs anteriores não são migrados.
- Testes: `mission_labels_test.gd` (Labels, limites, dimensões e tamanho de textura),
  `study_runtime_test.gd` (conexões corretas/incorretas, retorno e seleção conjunta).
  Centros dos conectores conferidos contra os pixels coloridos dos PNGs novos.
- Preview inspecionado: `.godot/cabinets_preview.png`.

A decisão inicial do Council e as verificações de temas separados registradas acima são
históricas; foram substituídas pela definição de rodada conjunta confirmada pelo usuário.


## Protótipo de terminal e atividade no tablet — 2026-09-08

Pedido confirmado: algumas tasks serão físicas no mapa; outras abrirão no tablet após
interagir com um terminal na sala. A primeira atividade está experimentalmente no segundo
modo, para avaliação; não é uma decisão definitiva sobre sua apresentação.

- `StudyTask.presentation`: enum MAP (0) / TABLET (1). A task conecta_camadas está em 1
  no catálogo. Alterar para 0 e reiniciar o mapa permite comparar com o modo físico.
- `map_task_slot.gd`: em TABLET desenha um terminal provisório no ponto central da
  atividade (offset local 340,230) e cria Area2D de raio 140. O corpo do grupo player
  entrando no alcance revela `[E] ABRIR ATIVIDADE`. Não tem colisão sólida.
- A tecla E em alcance emite open_requested; o controlador de UI conecta esse sinal ao
  tablet. Task indisponível/bloqueada não abre. Pause/tablet já aberto impede nova abertura.
- `world_controller.gd`: conecta slots ao tablet, preservando prioridade de ESC.
- `tablet_menu.gd` + TabletMenu.tscn: host de atividade centralizado, usa a mesma instância
  da missão. Reparent não reconstrói respostas. Navegação normal fica oculta durante a task.
- X do tablet, ESC e Tab fecham e devolvem movimento. O X interno da atividade é ocultado
  quando hospedada no tablet. Reabrir pelo terminal mantém conexões parciais nessa visita.
- Conclusão continua pelo mesmo sinal e sistema de progresso, sem regras específicas de
  OSI/TCP no tablet. Voltar ao mapa restaura conclusão; conexões parciais não sobrevivem
  a descarregar o mapa. Não há simulação de download nem desbloqueio remoto no tablet.
- A arte final do terminal substituirá apenas o desenho provisório; mapa, PNG e colisões
  existentes não foram modificados. Nenhum spritesheet novo é necessário para testar.
- Teste novo: `tests/tablet_task_test.gd`, cobrindo alcance físico, E, task indisponível,
  fechar/reabrir, estado parcial, conclusão e X/ESC/Tab. `study_runtime_test.gd` continua
  verificando o modo MAP por override de catálogo exclusivo do teste.
- Preview inspecionado: `.godot/tablet_task_preview.png` em 1280×720.
