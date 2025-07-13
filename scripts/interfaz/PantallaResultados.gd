extends Control

@onready var etiqueta_resultado = $VBoxContainer/EtiquetaResultado
@onready var lista_jugadores = $VBoxContainer/ScrollContainer/ListaJugadores
@onready var boton_jugar_otra_vez = $VBoxContainer/HBoxBotones/BotonJugarOtraVez
@onready var boton_menu_principal = $VBoxContainer/HBoxBotones/BotonMenuPrincipal

var id_ganador: int = -1
var estadisticas_jugadores = {}

func _ready():
	print("PantallaResultados _ready()")
	
	# Verificar que los nodos existen
	if not etiqueta_resultado:
		print("ERROR: etiqueta_resultado no encontrada")
	if not lista_jugadores:
		print("ERROR: lista_jugadores no encontrada")
	
	if boton_jugar_otra_vez:
		boton_jugar_otra_vez.pressed.connect(_on_boton_jugar_otra_vez_pressed)
	if boton_menu_principal:
		boton_menu_principal.pressed.connect(_on_boton_menu_principal_pressed)
	
	# Detener música del juego y reproducir música de menú
	if GestorAudio:
		GestorAudio.reproducir_musica("menu")

func configurar_resultados(ganador: int, estadisticas: Dictionary):
	print("=== CONFIGURAR RESULTADOS ===")
	print("Ganador recibido: ", ganador)
	print("Mi ID: ", multiplayer.get_unique_id())
	print("Estadísticas recibidas: ", estadisticas)
	
	id_ganador = ganador
	estadisticas_jugadores = estadisticas
	
	print("id_ganador asignado: ", id_ganador)
	print("Comparación: id_ganador == mi_id: ", id_ganador == multiplayer.get_unique_id())
	
	# Esperar un frame para asegurar que todos los nodos están listos
	await get_tree().process_frame
	
	# Llamar a mostrar_resultados DESPUÉS de configurar los datos
	mostrar_resultados()

func mostrar_resultados():
	print("=== MOSTRAR RESULTADOS ===")
	print("id_ganador: ", id_ganador)
	print("Mi unique_id: ", multiplayer.get_unique_id())
	print("Comparación directa: ", id_ganador == multiplayer.get_unique_id())
	
	# Verificar que tenemos los nodos necesarios
	if not etiqueta_resultado:
		print("ERROR: No se puede mostrar resultado, etiqueta_resultado es null")
		return
		
	if id_ganador == -1:
		etiqueta_resultado.text = "¡EMPATE!"
		etiqueta_resultado.modulate = Color.YELLOW
		print("Mostrando: EMPATE")
	elif id_ganador == multiplayer.get_unique_id():
		etiqueta_resultado.text = "¡VICTORIA!"
		etiqueta_resultado.modulate = Color.GREEN
		print("Mostrando: VICTORIA")
	else:
		etiqueta_resultado.text = "DERROTA"
		etiqueta_resultado.modulate = Color.RED
		print("Mostrando: DERROTA")
	
	# Verificar que lista_jugadores existe antes de usarla
	if not lista_jugadores:
		print("ERROR CRÍTICO: No se puede encontrar ListaJugadores")
		return
	
	# Limpiar lista actual
	for child in lista_jugadores.get_children():
		child.queue_free()
	
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
	if GestorAudio:
		GestorAudio.reproducir_efecto("click_boton")
	
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
	if GestorAudio:
		GestorAudio.reproducir_efecto("click_boton")
	
	# Desconectar del multijugador
	multiplayer.multiplayer_peer = null
	
	# Volver al menú principal
	get_tree().change_scene_to_file("res://escenas/interfaz/MenuPrincipal.tscn")
