$ErrorActionPreference = "Stop"

$project_root = Split-Path -Parent $PSScriptRoot
$mission_scene = Get-Content -Raw (Join-Path $project_root "scenes/missions/conecta_camadas.tscn")
$mission_script = Get-Content -Raw (Join-Path $project_root "scenes/missions/conecta_camadas.gd")
$world_scene = Get-Content -Raw (Join-Path $project_root "scenes/world/world.tscn")
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

$world_mission = [regex]::Match(
	$world_scene,
	'(?ms)\[node name="ConectaCamadas"[^\]]*\](.*?)(?=\r?\n\[node |\z)'
)
if (-not $world_mission.Success) {
	throw "Instância ConectaCamadas ausente do mundo."
}
foreach ($expected in @(
	"offset_left = 1077.0",
	"offset_top = -756.0",
	"offset_right = 1757.0",
	"offset_bottom = -296.0"
)) {
	if ($world_mission.Groups[1].Value -notmatch "(?m)^$([regex]::Escape($expected))$") {
		throw "A task não está centralizada na sala octagonal direita: falta '$expected'."
	}
}

if ($player_scene -notmatch "scale = Vector2\(1\.951538, 2\.0906985\)") {
	throw "O personagem não deve ser reduzido para compensar a task."
}

Write-Host "Mission scale static checks passed."
