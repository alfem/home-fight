extends Control

@onready var barra_vida = $BarraVida
@onready var info_arma = $InfoArma
@onready var info_municion = $InfoMunicion
@onready var info_jugadores = $InfoJugadores
@onready var info_conexion = $PanelDebug/InfoConexion

var jugador_local = null

func _ready():
	# Buscar el jugador local
	await get_tree().process_frame
	buscar_jugador_local()
	
	# Conectar señales del gestor de juego
	GestorJuego.jugador_muerto.connect(_on_jugador_muerto)
	GestorJuego.juego_terminado.connect(_on_juego_terminado)

func buscar_jugador_local():
	# Buscar el jugador que pertenece a este cliente
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	for jugador in jugadores:
		if jugador.es_local:
			jugador_local = jugador
			# Conectar señales del jugador
			jugador.vida_cambiada.connect(_on_vida_cambiada)
			break

func _process(_delta):
	if jugador_local:
		actualizar_info_arma()
		actualizar_info_municion()
	
	actualizar_info_conexion()
	actualizar_lista_jugadores()

func _on_vida_cambiada(nueva_vida: int):
	barra_vida.value = nueva_vida
	
	# Cambiar color según la vida
	if nueva_vida > 70:
		barra_vida.modulate = Color.GREEN
	elif nueva_vida > 30:
		barra_vida.modulate = Color.YELLOW
	else:
		barra_vida.modulate = Color.RED

func actualizar_info_arma():
	if jugador_local.arma_equipada == "":
		info_arma.text = "Arma: Puños"
	else:
		info_arma.text = "Arma: " + jugador_local.arma_equipada.capitalize()

func actualizar_info_municion():
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
