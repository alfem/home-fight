extends Control

@onready var etiqueta_titulo = $VBoxContainer/EtiquetaTitulo
@onready var campo_ip = $VBoxContainer/HBoxIP/CampoIP
@onready var campo_puerto = $VBoxContainer/HBoxPuerto/CampoPuerto
@onready var boton_conectar = $VBoxContainer/BotonConectar
@onready var boton_volver = $VBoxContainer/BotonVolver
@onready var etiqueta_estado = $VBoxContainer/EtiquetaEstado

var es_servidor = true

func _ready():
	print("PantallaConexion iniciada")
	
	# Determinar si es servidor o cliente
	es_servidor = GlobalData.modo_conexion != "cliente"
	
	#call_deferred("configurar_interfaz")
	configurar_interfaz()
	
	# Conectar señales
	boton_conectar.pressed.connect(_on_boton_conectar_pressed)
	boton_volver.pressed.connect(_on_boton_volver_pressed)
	
	# Conectar señales de red
	if GestorRed:
		GestorRed.conexion_establecida.connect(_on_conexion_establecida)
		GestorRed.conexion_fallida.connect(_on_conexion_fallida)

func configurar_interfaz():
	if es_servidor:
		etiqueta_titulo.text = "CREAR SERVIDOR"
		boton_conectar.text = "Crear Servidor"
		campo_ip.visible = false
		campo_puerto.text = "7000"
	else:
		etiqueta_titulo.text = "UNIRSE A PARTIDA"
		boton_conectar.text = "Conectar"
		campo_ip.text = "127.0.0.1"
		campo_puerto.text = "7000"

func _on_boton_conectar_pressed():
	if GestorAudio:
		GestorAudio.reproducir_efecto("click_boton")
	
	etiqueta_estado.text = "Conectando..."
	etiqueta_estado.modulate = Color.YELLOW
	boton_conectar.disabled = true
	
	var puerto = int(campo_puerto.text)
	
	if es_servidor:
		print("Creando servidor en puerto: ", puerto)
		if GestorRed:
			GestorRed.crear_servidor(puerto)
	else:
		var ip = campo_ip.text
		print("Conectando a: ", ip, ":", puerto)
		if GestorRed:
			GestorRed.unirse_servidor(ip, puerto)

func _on_boton_volver_pressed():
	if GestorAudio:
		GestorAudio.reproducir_efecto("click_boton")
	
	# Limpiar conexiones si existen
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	
	get_tree().change_scene_to_file("res://escenas/interfaz/MenuPrincipal.tscn")

func _on_conexion_establecida():
	print("Conexión establecida exitosamente")
	etiqueta_estado.text = "¡Conexión exitosa!"
	etiqueta_estado.modulate = Color.GREEN
	
	# Esperar un momento antes de cambiar de escena
	await get_tree().create_timer(1.0).timeout
	
	# Cambiar a la escena principal del juego
	print("Cambiando a escena Principal...")
	get_tree().change_scene_to_file("res://escenas/juego/Principal.tscn")

func _on_conexion_fallida():
	print("Falló la conexión")
	etiqueta_estado.text = "Error en la conexión"
	etiqueta_estado.modulate = Color.RED
	boton_conectar.disabled = false
