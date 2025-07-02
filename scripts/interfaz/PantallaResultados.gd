extends Control

@onready var etiqueta_resultado = $VBoxContainer/EtiquetaResultado
@onready var lista_jugadores = $VBoxContainer/ListaJugadores
@onready var boton_jugar_otra_vez = $VBoxContainer/HBoxBotones/BotonJugarOtraVez
@onready var boton_menu_principal = $VBoxContainer/HBoxBotones/BotonMenuPrincipal

var id_ganador: int = -1
var estadisticas_jugadores = {}

func _ready():
	boton_jugar_otra_vez.pressed.connect(_on_boton_jugar_otra_vez_pressed)
	boton_menu_principal.pressed.connect(_on_boton_menu_principal_pressed)
	
	# Detener música del juego y reproducir música de menú
	GestorAudio.reproducir_musica("menu")
	
	mostrar_resultados()

func configurar_resultados(ganador: int, estadisticas: Dictionary):
	id_ganador = ganador
	estadisticas_jugadores = estadisticas

func mostrar_resultados():
	if id_ganador == -1:
		etiqueta_resultado.text = "¡EMPATE!"
		etiqueta_resultado.modulate = Color.YELLOW
	elif id_ganador == multiplayer.get_unique_id():
		etiqueta_resultado.text = "¡VICTORIA!"
		etiqueta_resultado.modulate = Color.GREEN
	else:
		etiqueta_resultado.text = "DERROTA"
		etiqueta_resultado.modulate = Color.RED
	
	# Mostrar estadísticas de todos los jugadores
	for id_jugador in estadisticas_jugadores:
		var stats = estadisticas_jugadores[id_jugador]
		var info_jugador = Label.new()
		
		var texto_estado = "Eliminado"
		if id_jugador == id_ganador:
			texto_estado = "¡GANADOR!"
		
		info_jugador.text = "Jugador %d: %s" % [id_jugador, texto_estado]
		if id_jugador == id_ganador:
			info_jugador.modulate = Color.GOLD
		
		lista_jugadores.add_child(info_jugador)

func _on_boton_jugar_otra_vez_pressed():
	GestorAudio.reproducir_efecto("click_boton")
	
	# Reiniciar el juego
	if multiplayer.is_server():
		# Si somos el servidor, reiniciamos la partida
		GestorJuego.reiniciar_partida.rpc()
	else:
		# Si somos cliente, solicitamos reinicio
		GestorJuego.solicitar_reinicio.rpc_id(1)

func _on_boton_menu_principal_pressed():
	GestorAudio.reproducir_efecto("click_boton")
	
	# Desconectar del multijugador
	multiplayer.multiplayer_peer = null
	
	# Volver al menú principal
	get_tree().change_scene_to_file("res://escenas/interfaz/MenuPrincipal.tscn")