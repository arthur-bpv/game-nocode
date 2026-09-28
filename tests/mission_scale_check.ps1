$ErrorActionPreference = "Stop"

$project_root = Split-Path -Parent $PSScriptRoot
$mission_scene = Get-Content -Raw (Join-Path $project_root "scenes/missions/conecta_camadas.tscn")
$mission_script = Get-Content -Raw (Join-Path $project_root "scenes/missions/conecta_camadas.gd")
$world_scene = Get-Content -Raw (Join-Path $project_root "scenes/world/world.tscn")
$room_scene = Get-Content -Raw (Join-Path $project_root "scenes/world/rooms/upper_right_room.tscn")
$catalog = Get-Content -Raw (Join-Path $project_root "data/study/catalog.tres")
$player_scene = Get-Content -Raw (Join-Path $project_root "scenes/player/player.tscn")

if ($mission_scene -notmatch "(?m)^offset_right = 680\.0$") {
	throw "A task deve ter largura lógica de 680 px."
}
if ($mission_scene -notmatch "(?m)^offset_bottom = 460\.0$") {
	throw "A task deve ter altura lógica de 460 px."
}
if ($mission_script -notmatch "(?m)^const CABINET_WIDTH := 300\.0$") {
	throw "Os armários devem usar a largura proporcional de 300 px."
}
if ($mission_script -notmatch "var width: float = CABINET_WIDTH") {
	throw "A montagem da task deve usar a constante de escala dos armários."
}

if ($world_scene -notmatch 'name="MapLayout".*instance=ExtResource\("8_modular"\)') {
	throw "O mundo deve instanciar o mapa modular."
}
$room_anchor = [regex]::Match(
	$room_scene,
	'(?ms)\[node name="Primary"[^\]]*parent="MissionSlots"[^\]]*\](.*?)(?=\r?\n\[node |\z)'
)
if (-not $room_anchor.Success) {
	throw "Âncora da missão ausente da sala superior direita."
}
foreach ($expected in @(
	'position = Vector2(-170, -115)',
	'slot_id = &"sala_superior_direita_principal"'
)) {
	if ($room_anchor.Groups[1].Value -notmatch "(?m)^$([regex]::Escape($expected))\r?$") {
		throw "Âncora da missão fora da sala superior direita: falta '$expected'."
	}
}
if ($catalog -notmatch '(?s)id = &"conecta_camadas".*?map_slot = &"sala_superior_direita_principal"') {
	throw "A task de camadas deve usar o slot da sala superior direita."
}

if ($player_scene -notmatch "scale = Vector2\(1\.951538, 2\.090698\)") {
	throw "O personagem não deve ser reduzido para compensar a task."
}

Write-Host "Mission scale static checks passed."
