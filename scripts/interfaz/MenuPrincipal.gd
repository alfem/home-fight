extends Control

@onready var boton_servidor = $VBoxContainer/BotonServidor
@onready var boton_unirse = $VBoxContainer/BotonUnirse
@onready var boton_controles = $VBoxContainer/BotonControles
@onready var boton_personalizar = $VBoxContainer/BotonPersonalizar
@onready var boton_salir = $VBoxContainer/BotonSalir
@onready var titulo_juego = $TituloJuego

func _ready():
	# Reproducir música del menú
	GestorAudio.reproducir_musica("menu")
	
	# Conectar botones
	boton_servidor.pressed.connect(_on_boton_servidor_pressed)
	boton_unirse.pressed.connect(_on_boton_unirse_pressed)
	boton_controles.pressed.connect(_on_boton_controles_pressed)
	boton_personalizar.pressed.connect(_on_boton_personalizar_pressed)
	boton_salir.pressed.connect(_on_boton_salir_pressed)
	
	# Agregar efectos de sonido a botones
	configurar_sonidos_botones()

func configurar_sonidos_botones():
	var botones = [boton_servidor, boton_unirse, boton_controles, boton_personalizar, boton_salir]
	for boton in botones:
		boton.mouse_entered.connect(_on_boton_hover)
		boton.pressed.connect(_on_boton_click)

func _on_boton_hover():
	# Aquí podrías agregar un sonido sutil de hover si quieres
	pass

func _on_boton_click():
	GestorAudio.reproducir_efecto("click_boton")

func _on_boton_servidor_pressed():
	GlobalData.modo_conexion = "servidor"
	get_tree().change_scene_to_file("res://escenas/interfaz/PantallaConexion.tscn")

func _on_boton_unirse_pressed():
	# Pasar parámetro para indicar que es cliente
	GlobalData.modo_conexion = "cliente"
	get_tree().change_scene_to_file("res://escenas/interfaz/PantallaConexion.tscn")

func _on_boton_controles_pressed():
	get_tree().change_scene_to_file("res://escenas/interfaz/PantallaControles.tscn")

func _on_boton_personalizar_pressed():
	get_tree().change_scene_to_file("res://escenas/interfaz/PantallaPersonalizacion.tscn")

func _on_boton_salir_pressed():
	get_tree().quit()
