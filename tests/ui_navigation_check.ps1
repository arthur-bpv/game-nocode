$ErrorActionPreference = "Stop"

$project_root = Split-Path -Parent $PSScriptRoot
$required_files = @(
	"scripts/ui/pause_menu.gd",
	"scripts/ui/volume_screen.gd",
	"scripts/ui/confirmation_modal.gd",
	"scenes/world/world_controller.gd"
)

foreach ($relative_path in $required_files) {
	if (-not (Test-Path (Join-Path $project_root $relative_path))) {
		throw "Arquivo ausente: $relative_path"
	}
}

$pause_scene = Get-Content -Raw (Join-Path $project_root "scenes/Pause.tscn")
$volume_scene = Get-Content -Raw (Join-Path $project_root "scenes/volume.tscn")
$world_scene = Get-Content -Raw (Join-Path $project_root "scenes/world/world.tscn")
$main_menu_scene = Get-Content -Raw (Join-Path $project_root "scenes/menu.tscn")

if ($pause_scene -match "pause\.torch") { throw "Pause ainda depende do grafo legado." }
if ($volume_scene -match "volume\.torch") { throw "Volume ainda depende do grafo legado." }
if ($volume_scene -match "change_scene_to_file") { throw "Volume não deve trocar a cena da partida." }
if ($main_menu_scene -match "menu\.torch") { throw "O menu principal ainda referencia o fluxo legado direto para o mundo." }
if ($pause_scene -notmatch "VolumeScreen") { throw "Pause não instancia as configurações de áudio." }
if ($pause_scene -notmatch "ConfirmationModal") { throw "Pause não instancia o modal de confirmação compartilhado." }
if ($world_scene -match "world\.torch") { throw "O mundo ainda depende do grafo legado para navegar pelo ESC." }
if ($world_scene -notmatch "world_controller\.gd") { throw "O controlador central de ESC não está ligado ao mundo." }
if ($pause_scene -match 'offset_left = 7[0-9][0-9]\.0') { throw "Pause ainda depende das posições absolutas antigas." }

Write-Host "UI navigation static checks passed."
