$ErrorActionPreference = "Stop"

$project_root = Split-Path -Parent $PSScriptRoot
$required_files = @(
	"scripts/ui/pause_menu.gd",
	"scripts/ui/settings_screen.gd",
	"scripts/ui/volume_screen.gd"
)

foreach ($relative_path in $required_files) {
	if (-not (Test-Path (Join-Path $project_root $relative_path))) {
		throw "Arquivo ausente: $relative_path"
	}
}

$pause_scene = Get-Content -Raw (Join-Path $project_root "scenes/Pause.tscn")
$settings_scene = Get-Content -Raw (Join-Path $project_root "scenes/configurações.tscn")
$volume_scene = Get-Content -Raw (Join-Path $project_root "scenes/volume.tscn")
$world_scene_lines = Get-Content (Join-Path $project_root "scenes/world/world.tscn")
$main_menu_scene = Get-Content -Raw (Join-Path $project_root "scenes/menu.tscn")

if ($pause_scene -match "pause\.torch") { throw "Pause ainda depende do grafo legado." }
if ($settings_scene -match "configurações\.torch") { throw "Configurações ainda troca de cena pelo grafo legado." }
if ($volume_scene -match "volume\.torch") { throw "Volume ainda depende do grafo legado." }
if ($settings_scene -match "change_scene_to_file") { throw "Configurações não deve trocar a cena da partida." }
if ($volume_scene -match "change_scene_to_file") { throw "Volume não deve trocar a cena da partida." }
if ($main_menu_scene -match "menu\.torch") { throw "O menu principal ainda referencia o fluxo legado direto para o mundo." }
if ($pause_scene -notmatch "Settings") { throw "Pause não instancia Configurações." }
if ($pause_scene -notmatch "Volume") { throw "Pause não instancia Volume." }
foreach ($button_name in @("Button", "Button2")) {
	$node_line = "[node name=`"$button_name`" parent=`"CanvasLayer/Pause`""
	$node_index = [Array]::FindIndex([string[]]$world_scene_lines, [Predicate[string]]{ param($line) $line.StartsWith($node_line) })
	if ($node_index -ge 0) {
		$node_block = ($world_scene_lines[($node_index + 1)..([Math]::Min($node_index + 7, $world_scene_lines.Count - 1))] -join "`n")
		$expected_left = if ($button_name -eq "Button2") { "718.0" } else { "705.0" }
		if ($node_block -notmatch "offset_left = $([regex]::Escape($expected_left))") {
			throw "A posição do botão $button_name de Pause não foi preservada."
		}
	}
}

Write-Host "UI navigation static checks passed."
