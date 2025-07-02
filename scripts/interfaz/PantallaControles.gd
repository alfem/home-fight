extends Control

@onready var boton_volver = $VBoxContainer/BotonVolver
@onready var lista_controles = $VBoxContainer/ScrollContainer/VBoxControles

func _ready():
	boton_volver.pressed.connect(_on_boton_volver_pressed)
	
	# Agregar información de controles
	agregar_info_controles()

func agregar_info_controles():
	var controles_info = [
		"=== MOVIMIENTO ===",
		"W / Flecha Arriba: Mover hacia arriba",
		"S / Flecha Abajo: Mover hacia abajo", 
		"A / Flecha Izquierda: Mover hacia la izquierda",
		"D / Flecha Derecha: Mover hacia la derecha",
		"",
		"=== COMBATE ===",
		"Espacio / Click Izquierdo: Atacar",
		"",
		"=== OBJETIVO ===",
		"• Encuentra armas y objetos en el laberinto",
		"• Las armas de fuego tienen munición limitada",
		"• Los escudos bloquean el 30% de los ataques",
		"• La medicina restaura 50 puntos de vida",
		"• ¡Sé el último jugador en pie para ganar!",
		"",
		"=== TIPOS DE ARMA ===",
		"• Espada: Daño medio, corto alcance",
		"• Hacha: Daño alto, corto alcance",
		"• Pistola: Daño medio-alto, largo alcance (12 balas)",
		"• Rifle: Daño muy alto, largo alcance (30 balas)"
	]
	
	for info in controles_info:
		var etiqueta = Label.new()
		etiqueta.text = info
		if info.begins_with("==="):
			etiqueta.add_theme_color_override("font_color", Color.YELLOW)
		lista_controles.add_child(etiqueta)

func _on_boton_volver_pressed():
	GestorAudio.reproducir_efecto("click_boton")
	get_tree().change_scene_to_file("res://escenas/interfaz/MenuPrincipal.tscn")