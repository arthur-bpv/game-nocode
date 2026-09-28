# Protótipo modular do mapa

A cena `scenes/world/maps/central_section_prototype.tscn` monta a sala central, as salas
superior e inferior esquerdas, a sala inferior central, a sala pequena à direita, a sala
superior direita, a sala inferior direita e seus corredores. `scenes/world/world.tscn`
instancia essa seção como `MapLayout`; o mapa PNG único e suas colisões não participam
mais da cena jogável. Os arquivos antigos continuam no repositório como referência.

A composição visual atual está em `docs/architecture/modular-map-preview.png`.
Ela é uma prévia montada a partir dos PNGs e das posições da cena; os marcadores de
conexão são validados pelo teste `tests/modular_map_runtime_test.gd` no Godot.
O teste `tests/modular_map_collision_test.gd` verifica a passagem da cápsula do jogador
pelas entradas e o bloqueio das paredes.
O tablet usa a mesma composição em `assets/sprites/map/modular_map_overview.png`, com
limites de mundo de (-1800, -500) a (2400, 1800). Uma mudança visual ou de posição nas
peças precisa atualizar essa imagem de visão geral.

As imagens originais recebidas estão copiadas para `assets/sprites/map/`. A sala central mede
431×490 px, a superior esquerda 377×440 px, a inferior esquerda 458×330 px, a inferior
central 235×457 px, a pequena à direita 208×355 px, a superior direita 411×452 px e a
inferior direita 257×331 px. O corredor lateral mede 327×127 px,
o inferior central 83×172 px, o inferior diagonal 117×297 px, a variante média 263×152 px,
o corredor em L 258×414 px e o minicorredor 69×115 px.
A seção aplica escala
2 ao conjunto, para se aproximar da escala do mapa atual de 4080×2295 px. Todos os
marcadores usam as coordenadas originais dos PNGs; portanto uma mudança de escala do
conjunto mantém os encaixes juntos. A instância do corredor entre as duas salas é
encurtada horizontalmente para reproduzir a proporção da referência do Canvas.

Cada peça tem cena própria, com sprite e marcadores de conexão. A sala
central expõe `area_id = sala_central`; as outras expõem `sala_superior_esquerda`,
`sala_inferior_esquerda`, `sala_inferior_central`, `sala_inferior_centro_direita`,
`sala_superior_direita` e `sala_inferior_direita`.
Todas têm um `MapMissionAnchor` chamado `Primary`, cujo `slot_id` é único e inclui o
ID físico da sala. Esses IDs não são IDs de task. `modular_world_setup.gd` lê os
marcadores ao carregar o mundo e cria os `MapTaskSlot` em `Entities`, na posição global
de cada âncora. Assim, as missões mantêm sua escala de interface mesmo quando a seção
do mapa é ampliada. Mover uma sala também move o ponto de montagem da missão.

O catálogo declara os vínculos do tema atual: `sinais_osi` na sala inferior esquerda,
`conecta_camadas` na superior direita e `rack_osi` na inferior central. A nova task
`sinais_osi` foi movida do registro em tempo de execução para `data/study/catalog.tres`.
O progresso continua identificado pelo ID de cada task, independente do slot físico.

Os corredores entram um pouco nas salas, e os marcadores ficam dentro dessa sobreposição
para manter os encaixes alinhados. Os sprites dos corredores usam `z_index = 1` para cobrir a borda preta contínua
da sala sem modificar os PNGs. Cada cena de sala e corredor agora contém um
`StaticBody2D` chamado `Walls`, com segmentos de colisão editáveis no Godot. As
aberturas coincidem com as conexões entre peças; as paredes não são criadas por script
em tempo de execução. A colisão do minicorredor concede alguns pixels extras de
largura à passagem para acomodar a cápsula atual do jogador.

O corredor inferior da sala superior esquerda sobrepõe sua diagonal e a parede superior
da sala inferior esquerda. A sala inferior reutiliza o corredor lateral na saída direita.
Na sala inferior central, o corredor que desce da sala central cobre toda a espessura
da parede superior do PNG, deixando apenas os trechos à esquerda e à direita da entrada.
Ela recebe o corredor lateral vindo da sala inferior esquerda e oferece outro à direita.
Esse último foi substituído pela variante média fornecida para conectar a sala pequena.
O PNG médio tem cerca de 77 px de espaço transparente à direita; a cena usa somente a
região desenhada de 186×152 px, sem alterar o arquivo original. Sua parede superior e
piso continuam editáveis como um único sprite de corredor.

A sala superior direita se liga à central pelo corredor lateral. O corredor em L desce
da sala superior direita e vira à esquerda para alcançar a sala pequena inferior
central direita. Um ramal com o minicorredor sai da lateral direita do L para a sala
inferior direita. O minicorredor conserva a proporção original do PNG, sem comprimir
a largura transitável. As três junções do L e as duas
do minicorredor têm marcadores próprios, para manter a montagem verificável.
Piso verde toca piso verde, sem exigir recorte angular do PNG. Há uma leve diferença de tom entre esses pisos;
ela forma um retângulo discreto na sobreposição. Isso não impede o encaixe, mas merece
revisão visual ao finalizar as artes.

O jogador nasce na sala central. A câmera usa os limites do mapa mostrado no tablet.
Ainda faltam acabamento das junções, uma inspeção visual interativa das missões em
resolução final e a substituição futura dos corredores PNG por tiles.
