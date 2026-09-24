# Tasklist

Atualizado em: 2026-09-01

## Próxima ação recomendada

- [ ] Testar manualmente no editor: Menu → Singleplayer → Loading → Mapa → Tablet → ESC → Áudio → Continuar/Voltar.
- [ ] Confirmar movimentação, colisões, escala do personagem e posição da task na sala octagonal.
- [ ] Registrar qualquer diferença visual ou funcional observada durante o teste manual.

## Assets do Canvas

- [ ] Receber fundo limpo 16:9 em 4K, sem conteúdo interativo rasterizado.
- [ ] Receber logo NETBOT transparente.
- [ ] Decidir se serão fornecidos ícones/molduras/estados decorativos separados.
- [ ] Integrar os assets definitivos sem alterar os contratos de UI.
- [ ] Reexecutar capturas em 720p, 1080p e 4K após a integração visual.

## Próxima fase de produto: tasks

- [ ] Inventariar todos os PNGs e cenas de tasks existentes.
- [ ] Separar molduras/ilustrações de textos, botões e estados interativos.
- [ ] Criar componentes Godot reutilizáveis para título, instruções, feedback e fechar/voltar.
- [ ] Definir um identificador de temática para cada mapa e missão.
- [ ] Implementar regra de exibição: missões OSI/TCP-IP aparecem apenas nos mapas compatíveis; missões de Protocolos de Rede não aparecem em temas diferentes.
- [ ] Substituir o botão `X` da task por uma interação coerente com o mundo, caso o design final confirme que a task não deve ser fechável livremente.
- [ ] Validar novamente a proporção visual entre personagem, task e câmera.

## Conteúdo do tablet

- [ ] Implementar a visualização real do mapa no tablet.
- [ ] Integrar a lista de missões ao sistema temático.
- [ ] Definir e implementar o conteúdo do tutorial.
- [ ] Manter configurações de sistema e saída fora do tablet.

## Qualidade e manutenção

- [ ] Investigar separadamente o crash/código 1 no shutdown do Godot 4.6 com as extensões do projeto.
- [ ] Revisar os arquivos `.torch` legados e remover somente os que estiverem comprovadamente sem referências.
- [ ] Separar as mudanças preexistentes de mapa/task das mudanças desta UI em commits coerentes.
- [ ] Não adicionar os arquivos TMP do Orchestrator ao Git.
- [ ] Rodar os checks PowerShell, runtimes Godot e render visual antes de cada entrega.

## Concluído nesta fase

- [x] Theme compartilhado e fonte licenciada.
- [x] Menu inicial reconstruído.
- [x] Multiplayer desabilitado como “Em breve”.
- [x] Loading assíncrono minimalista.
- [x] Pause completo com confirmações.
- [x] Configurações Master/Music/SFX persistidas.
- [x] Tablet separado das configurações globais.
- [x] Prioridade correta do ESC.
- [x] Colisões do mapa pré-geradas.
- [x] Validação visual em 720p, 1080p e 4K.
