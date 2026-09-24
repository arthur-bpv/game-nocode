$ErrorActionPreference = "Stop"

$project_root = Split-Path -Parent $PSScriptRoot

function Read-ProjectFile([string]$relative_path) {
	$path = Join-Path $project_root $relative_path
	if (-not (Test-Path -LiteralPath $path)) {
		throw "Arquivo ausente: $relative_path"
	}
	return Get-Content -Raw -LiteralPath $path
}

$project = Read-ProjectFile "project.godot"
$menu = Read-ProjectFile "scenes/menu.tscn"
$pause = Read-ProjectFile "scenes/Pause.tscn"
$tablet = Read-ProjectFile "scenes/tablet/TabletMenu.tscn"
$world = Read-ProjectFile "scenes/world/world.tscn"
$world_walls = Read-ProjectFile "scenes/world/world_walls.gd"
$audio_settings = Read-ProjectFile "scripts/autoload/audio_settings.gd"
$scene_transition = Read-ProjectFile "scripts/autoload/scene_transition.gd"
$pause_controller = Read-ProjectFile "scripts/ui/pause_menu.gd"

if ($project -notmatch 'AudioSettings="\*res://scripts/autoload/audio_settings.gd"') {
	throw "AudioSettings não foi registrado como autoload."
}
if ($project -notmatch 'SceneTransition="\*res://scripts/autoload/scene_transition.gd"') {
	throw "SceneTransition não foi registrado como autoload."
}
if ($project -notmatch 'window/stretch/mode="canvas_items"') {
	throw "O projeto perdeu o modo responsivo canvas_items."
}
if ($menu -match 'TabletMenuPregame|ui_background_netbot_menu.png|menu.torch') {
	throw "O menu ainda depende da preparação em tablet, do PNG completo ou do grafo legado."
}
foreach ($label in @("SINGLEPLAYER", "MULTIPLAYER", "EM BREVE", "SAIR")) {
	if ($menu -notmatch [regex]::Escape($label)) { throw "Ação ausente no menu: $label" }
}
if ($tablet -match 'SettingsPanel|GearButton|ColorRow|pregame_mode') {
	throw "O tablet ainda contém configurações globais ou preparação pré-jogo."
}
foreach ($label in @("MAPA", "MISSÕES", "TUTORIAL")) {
	if ($tablet -notmatch [regex]::Escape($label)) { throw "Conteúdo ausente no tablet: $label" }
}
foreach ($label in @("CONTINUAR", "CONFIGURAÇÕES", "VOLTAR AO MENU", "SAIR DO JOGO")) {
	if ($pause -notmatch [regex]::Escape($label)) { throw "Ação ausente no pause: $label" }
}
if ($pause_controller -notmatch 'func open_pause\(' -or $pause_controller -notmatch 'func resume_game\(') {
	throw "PauseMenu não oferece os contratos open_pause/resume_game."
}
if ($world -match 'world.torch' -or $world -notmatch 'world_controller.gd') {
	throw "O mundo ainda depende do grafo legado para o ESC."
}
if ($world -notmatch '(?s)\[node name="UiController".*?process_mode = 3') {
	throw "O roteador de ESC precisa continuar processando enquanto o jogo está pausado."
}
if ($world_walls -match 'for y in mask_image|get_pixel' -or $world_walls -notmatch 'collision_polygons.tres') {
	throw "As colisões ainda são calculadas pixel a pixel em runtime."
}
if ($audio_settings -notmatch 'user://settings.cfg') {
	throw "AudioSettings não persiste em user://settings.cfg."
}
foreach ($bus in @("Master", "Music", "SFX")) {
	if ($audio_settings -notmatch [regex]::Escape($bus)) { throw "Bus não gerenciado: $bus" }
}
if ($scene_transition -notmatch 'load_threaded_request' -or $scene_transition -notmatch 'load_threaded_get_status') {
	throw "SceneTransition não utiliza carregamento em thread."
}

Write-Host "UI system static checks passed."
