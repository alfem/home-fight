extends Control

@onready var barra_vida = $BarraVida
@onready var info_arma = $InfoArma
@onready var info_municion = $InfoMunicion
@onready var info_jugadores = $InfoJugadores
@onready var info_conexion = $PanelDebug/InfoConexion

var jugador_local = null

func _ready():
	print("HUD iniciado")
	
	# Inicializar barra de vida con valores por defecto
	barra_vida.value = 100
	barra_vida.modulate = Color.GREEN
	
	# Conectar señales del gestor de juego
	if GestorJuego:
		GestorJuego.jugador_muerto.connect(_on_jugador_muerto)
		GestorJuego.juego_terminado.connect(_on_juego_terminado)
	
	# Buscar el jugador local con múltiples intentos
	buscar_jugador_local_con_reintentos()

func buscar_jugador_local_con_reintentos():
	# Intentar varias veces para encontrar el jugador local
	var intentos = 0
	var max_intentos = 10
	
	while jugador_local == null and intentos < max_intentos:
		await get_tree().process_frame
		buscar_jugador_local()
		intentos += 1
		
		if jugador_local:
			print("Jugador local encontrado en intento ", intentos)
			break
		else:
			print("Intento ", intentos, " - jugador local no encontrado aún")
			await get_tree().create_timer(0.1).timeout
	
	if not jugador_local:
		print("ERROR: No se pudo encontrar jugador local después de ", max_intentos, " intentos")
	else:
		# Actualizar inmediatamente la interfaz
		actualizar_interfaz_inicial()

func buscar_jugador_local():
	# Método 1: Buscar en ContenedorJugadores
	var escena_principal = get_tree().current_scene
	if escena_principal:
		var contenedor_jugadores = escena_principal.get_node_or_null("ContenedorJugadores")
		if contenedor_jugadores:
			for child in contenedor_jugadores.get_children():
				if child.has_method("get_multiplayer_authority") and child.es_local:
					jugador_local = child
					print("Jugador local encontrado en ContenedorJugadores: ", child.name)
					return
	
	# Método 2: Buscar en el grupo de jugadores
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	print("Buscando jugador local en grupo. Jugadores encontrados: ", jugadores.size())
	
	for jugador in jugadores:
		print("  - Jugador: ", jugador.name, " ID: ", jugador.id_jugador, " Local: ", jugador.es_local, " Mi ID: ", multiplayer.get_unique_id())
		if jugador.es_local:
			jugador_local = jugador
			print("¡Jugador local encontrado en grupo!")
			return

func actualizar_interfaz_inicial():
	if not jugador_local:
		return
	
	print("Actualizando interfaz inicial para jugador: ", jugador_local.name)
	
	# Conectar señales del jugador
	if not jugador_local.vida_cambiada.is_connected(_on_vida_cambiada):
		jugador_local.vida_cambiada.connect(_on_vida_cambiada)
		print("Señal vida_cambiada conectada")
	
	# Actualizar valores inmediatamente
	_on_vida_cambiada(jugador_local.vida_actual)
	actualizar_info_arma()
	actualizar_info_municion()
	
	print("Vida actual del jugador: ", jugador_local.vida_actual)
	print("Barra de vida actualizada a: ", barra_vida.value)

func _process(_delta):
	if jugador_local and is_instance_valid(jugador_local):
		actualizar_info_arma()
		actualizar_info_municion()
	elif not jugador_local:
		# Si perdimos la referencia, intentar encontrarla de nuevo
		buscar_jugador_local()
	
	actualizar_info_conexion()
	actualizar_lista_jugadores()

func _on_vida_cambiada(nueva_vida: int):
	print("HUD recibió cambio de vida: ", nueva_vida)
	
	barra_vida.value = nueva_vida
	
	# Cambiar color según la vida
	if nueva_vida > 70:
		barra_vida.modulate = Color.GREEN
	elif nueva_vida > 30:
		barra_vida.modulate = Color.YELLOW
	else:
		barra_vida.modulate = Color.RED

func actualizar_info_arma():
	if not jugador_local:
		return
		
	if jugador_local.arma_equipada == "":
		info_arma.text = "Arma: Puños"
	else:
		info_arma.text = "Arma: " + jugador_local.arma_equipada.capitalize()

func actualizar_info_municion():
	if not jugador_local:
		return
		
	if jugador_local.es_ataque_a_distancia():
		info_municion.text = "Munición: " + str(jugador_local.municion_actual)
		info_municion.visible = true
	else:
		info_municion.visible = false

func actualizar_info_conexion():
	var peers_conectados = multiplayer.get_peers().size() + 1  # +1 por el servidor
	info_conexion.text = "Jugadores: " + str(peers_conectados) + "/4"

func actualizar_lista_jugadores():
	# Limpiar lista actual
	for child in info_jugadores.get_children():
		child.queue_free()
	
	# Mostrar jugadores vivos
	if GestorJuego and GestorJuego.jugadores_vivos:
		for id_jugador in GestorJuego.jugadores_vivos:
			var etiqueta = Label.new()
			etiqueta.text = "Jugador " + str(id_jugador)
			if id_jugador == multiplayer.get_unique_id():
				etiqueta.text += " (Tú)"
				etiqueta.modulate = Color.YELLOW
			info_jugadores.add_child(etiqueta)

func _on_jugador_muerto(id_jugador: int):
	# Mostrar mensaje si el jugador local murió
	if id_jugador == multiplayer.get_unique_id():
		mostrar_mensaje_muerte()

func mostrar_mensaje_muerte():
	var mensaje = Label.new()
	mensaje.text = "¡HAS SIDO ELIMINADO!"
	mensaje.add_theme_font_size_override("font_size", 36)
	mensaje.modulate = Color.RED
	mensaje.anchors_preset = Control.PRESET_CENTER
	add_child(mensaje)
	
	# Hacer que parpadee
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(mensaje, "modulate:a", 0.0, 0.5)
	tween.tween_property(mensaje, "modulate:a", 1.0, 0.5)

func _on_juego_terminado(ganador: int):
	# El mensaje de fin de juego se maneja en PantallaResultados
	pass
