extends Control

@onready var etiqueta_resultado = $VBoxContainer/EtiquetaResultado
@onready var lista_jugadores = $VBoxContainer/ScrollContainer/ListaJugadores
@onready var boton_jugar_otra_vez = $VBoxContainer/HBoxBotones/BotonJugarOtraVez
@onready var boton_menu_principal = $VBoxContainer/HBoxBotones/BotonMenuPrincipal

var id_ganador: int = -1
var estadisticas_jugadores = {}

func _ready():
	# Conectar botones
	boton_jugar_otra_vez.pressed.connect(_on_boton_jugar_otra_vez_pressed)
	boton_menu_principal.pressed.connect(_on_boton_menu_principal_pressed)
	
	# Agregar efectos de sonido a botones
	configurar_sonidos_botones()
	
	# Detener música del juego y reproducir música de menú
	if GestorAudio:
		GestorAudio.reproducir_musica("menu")
	
	# Si ya tenemos datos, mostrar resultados inmediatamente
	if id_ganador != -1 or estadisticas_jugadores.size() > 0:
		mostrar_resultados()

func configurar_sonidos_botones():
	var botones = [boton_jugar_otra_vez, boton_menu_principal]
	for boton in botones:
		boton.pressed.connect(_on_boton_click, CONNECT_DEFERRED)

func _on_boton_click():
	if GestorAudio:
		GestorAudio.reproducir_efecto("click_boton")

func configurar_resultados(ganador: int, estadisticas: Dictionary):
	id_ganador = ganador
	estadisticas_jugadores = estadisticas
	call_deferred("mostrar_resultados")

func mostrar_resultados():
	# Limpiar lista actual
	for child in lista_jugadores.get_children():
		child.queue_free()
	
	# Configurar título principal
	configurar_titulo_resultado()
	
	# Mostrar estadísticas de todos los jugadores
	mostrar_estadisticas_jugadores()

func configurar_titulo_resultado():
	if id_ganador == -1:
		etiqueta_resultado.text = "¡EMPATE!"
		etiqueta_resultado.modulate = Color.YELLOW
	elif id_ganador == multiplayer.get_unique_id():
		etiqueta_resultado.text = "¡VICTORIA!"
		etiqueta_resultado.modulate = Color.GREEN
		# Efecto de parpadeo para victoria
		crear_efecto_victoria()
	else:
		etiqueta_resultado.text = "DERROTA"
		etiqueta_resultado.modulate = Color.RED

func crear_efecto_victoria():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(etiqueta_resultado, "scale", Vector2(1.1, 1.1), 0.5)
	tween.tween_property(etiqueta_resultado, "scale", Vector2(1.0, 1.0), 0.5)

func mostrar_estadisticas_jugadores():
	# Ordenar jugadores: ganador primero, luego por ID
	var jugadores_ordenados = estadisticas_jugadores.keys()
	jugadores_ordenados.sort()
	
	# Mover ganador al principio
	if id_ganador in jugadores_ordenados:
		jugadores_ordenados.erase(id_ganador)
		jugadores_ordenados.push_front(id_ganador)
	
	for id_jugador in jugadores_ordenados:
		crear_info_jugador(id_jugador)

func crear_info_jugador(id_jugador: int):
	var contenedor_jugador = HBoxContainer.new()
	
	# Información básica del jugador
	var info_principal = Label.new()
	var nombre_jugador = "Jugador " + str(id_jugador)
	
	if id_jugador == multiplayer.get_unique_id():
		nombre_jugador += " (Tú)"
	
	var estado = "Eliminado"
	var color_estado = Color.GRAY
	
	if id_jugador == id_ganador:
		estado = "¡GANADOR!"
		color_estado = Color.GOLD
	
	info_principal.text = nombre_jugador + " - " + estado
	info_principal.modulate = color_estado
	info_principal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Estadísticas adicionales
	var info_stats = Label.new()
	if id_jugador in estadisticas_jugadores:
		var stats = estadisticas_jugadores[id_jugador]
		var eliminaciones = stats.get("eliminaciones", 0)
		var objetos = stats.get("objetos_recogidos", 0)
		info_stats.text = "Eliminaciones: %d | Objetos: %d" % [eliminaciones, objetos]
	else:
		info_stats.text = "Sin estadísticas"
	
	info_stats.modulate = Color.LIGHT_GRAY
	info_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	# Ensamblar contenedor
	contenedor_jugador.add_child(info_principal)
	contenedor_jugador.add_child(info_stats)
	lista_jugadores.add_child(contenedor_jugador)
	
	# Separador visual
	if id_jugador != estadisticas_jugadores.keys()[-1]:  # No añadir separador al último
		var separador = HSeparator.new()
		separador.custom_minimum_size = Vector2(0, 10)
		lista_jugadores.add_child(separador)

func _on_boton_jugar_otra_vez_pressed():
	print("Solicitando reinicio de partida...")
	
	# Deshabilitar botón para evitar múltiples clicks
	boton_jugar_otra_vez.disabled = true
	boton_jugar_otra_vez.text = "Reiniciando..."
	
	# Reiniciar el juego
	if multiplayer.is_server():
		# Si somos el servidor, reiniciamos la partida
		if GestorJuego:
			GestorJuego.reiniciar_partida.rpc()
	else:
		# Si somos cliente, solicitamos reinicio
		if GestorJuego:
			GestorJuego.solicitar_reinicio.rpc_id(1)

func _on_boton_menu_principal_pressed():
	print("Regresando al menú principal...")
	
	# Limpiar estado del juego
	if GestorJuego:
		GestorJuego.limpiar_estado()
	
	# Desconectar del multijugador
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	
	# Volver al menú principal
	get_tree().change_scene_to_file("res://escenas/interfaz/MenuPrincipal.tscn")
