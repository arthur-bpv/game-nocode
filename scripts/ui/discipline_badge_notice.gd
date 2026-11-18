extends PanelContainer

func _ready() -> void:
	$HideTimer.timeout.connect(hide)
	%BadgeName.add_theme_font_override("font", ThemeDB.fallback_font)

func show_badge(discipline: StudyDiscipline) -> void:
	%BadgeIcon.texture = discipline.badge_icon
	%BadgeName.text = discipline.title
	show()
	$HideTimer.start()
