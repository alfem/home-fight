extends Node2D

@onready var laberinto = $Laberinto
@onready var contenedor_jugadores = $ContenedorJugadores
@onready var camara = $Camara2D
@onready var hud = $InterfazUsuario/HUD

var jugadores_instanciados = {}
var jugador_local = null

func _ready():
	print("Escena Principal iniciada")
	print("Mi ID: ", multiplayer.get_unique_id())
	print("Soy servidor: ", multiplayer.is_server())
	print("Peers conectados: ", multiplayer.get_peers())
	if camara:
		print("Cámara posición inicial: ", camara.global_position)
		print("Cámara enabled: ", camara.enabled)
		print("Cámara zoom: ", camara.zoom)
	else:
		print("ERROR: Cámara no encontrada")
		
	# Conectar señales de red
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# Conectar señales del gestor de juego
	if GestorJuego:
		GestorJuego.jugador_muerto.connect(_on_jugador_muerto)
		GestorJuego.juego_terminado.connect(_on_juego_terminado)
	
	# DEBUG
	get_tree().debug_collisions_hint = true
	# Inicializar el juego después de un pequeño delay
	call_deferred("inicializar_juego")

func inicializar_juego():
	print("Inicializando juego...")
	
	# Crear jugadores para todos los peers conectados
	crear_jugadores()
	
	# Iniciar la lógica del juego
	if GestorJuego:
		GestorJuego.iniciar_juego()

func crear_jugadores():
	print("=== CREANDO JUGADORES ===")
	print("Mi ID: ", multiplayer.get_unique_id())
	print("Soy servidor: ", multiplayer.is_server())
	print("Peers conectados: ", multiplayer.get_peers())
	
	var indice_spawn = 0
	var jugadores_a_crear = []
	
	# Lista de TODOS los jugadores que deben existir
	jugadores_a_crear.append(1)  # Servidor siempre existe
	
	# Añadir mi propio ID si no soy el servidor
	if multiplayer.get_unique_id() != 1:
		jugadores_a_crear.append(multiplayer.get_unique_id())
	
	# Añadir otros peers (excluyendo a mí mismo)
	for peer_id in multiplayer.get_peers():
		if peer_id != multiplayer.get_unique_id() and peer_id not in jugadores_a_crear:
			jugadores_a_crear.append(peer_id)
	
	print("Jugadores a crear: ", jugadores_a_crear)
	
	# Crear cada jugador
	for jugador_id in jugadores_a_crear:
		print("Creando jugador con ID: ", jugador_id)
		crear_jugador(jugador_id, indice_spawn)
		indice_spawn += 1
	
	print("=== JUGADORES CREADOS ===")
	
func crear_jugador(peer_id: int, indice_spawn: int):
	print("Creando jugador ", peer_id, " con spawn index: ", indice_spawn)
	
	# Verificar que existe la escena del jugador
	if not ResourceLoader.exists("res://escenas/juego/Jugador.tscn"):
		print("ERROR: No se encuentra Jugador.tscn")
		return
	
	# Cargar la escena del jugador
	var escena_jugador = load("res://escenas/juego/Jugador.tscn")
	var jugador = escena_jugador.instantiate()
	
	# Configurar el jugador
	jugador.name = "Jugador" + str(peer_id)
	jugador.id_jugador = peer_id
	jugador.es_local = (peer_id == multiplayer.get_unique_id())
	
	# Posiciones fijas y separadas para cada jugador
	var posiciones_spawn = [
		Vector2(150, 150),   # Jugador 1 (servidor)
		Vector2(450, 150),   # Jugador 2 (cliente 1)
		Vector2(150, 350),   # Jugador 3 (cliente 2)
		Vector2(450, 350)    # Jugador 4 (cliente 3)
	]
	
	if indice_spawn < posiciones_spawn.size():
		jugador.position = posiciones_spawn[indice_spawn]
	else:
		jugador.position = Vector2(150 + indice_spawn * 100, 150)
	
	print("Jugador ", peer_id, " posicionado en: ", jugador.position)
	print("Es local: ", jugador.es_local, " (mi ID: ", multiplayer.get_unique_id(), ")")
	
	# Establecer autoridad de red
	jugador.set_multiplayer_authority(peer_id)
	
	# Configurar nombre
	if jugador.has_method("establecer_nombre"):
		var nombre = "Jugador " + str(peer_id)
		jugador.establecer_nombre(nombre)
	
	# Añadir al grupo y al contenedor
	jugador.add_to_group("jugadores")
	contenedor_jugadores.add_child(jugador)
	jugadores_instanciados[peer_id] = jugador
	
	# Si es el jugador local, configurar cámara para seguirlo
	if jugador.es_local:
		jugador_local = jugador
		print("*** JUGADOR LOCAL DETECTADO: ", jugador_local.name, " ID: ", peer_id)
		
		# Configurar cámara después de un frame para asegurar que todo está listo
		call_deferred("configurar_camara_seguimiento")

	
	print("Jugador ", peer_id, " creado exitosamente") 
	
@rpc("call_local")
func establecer_posicion_jugador(peer_id: int, posicion: Vector2):
	if peer_id in jugadores_instanciados:
		jugadores_instanciados[peer_id].position = posicion
		print("Posición sincronizada para jugador ", peer_id, ": ", posicion)

func configurar_camara_seguimiento():
	if jugador_local and camara:
		print("Configurando cámara para seguir al jugador local: ", jugador_local.name)
		# Posicionar cámara inicialmente en el jugador
		camara.global_position = jugador_local.global_position
		camara.enabled = true
		camara.make_current()
		print("Cámara configurada en posición: ", camara.global_position)
	else:
		print("ERROR: No se pudo configurar cámara. jugador_local: ", jugador_local, " camara: ", camara)

func _process(delta):
	# Hacer que la cámara siga al jugador local con interpolación suave
	if jugador_local and camara and is_instance_valid(jugador_local):
		var distancia = camara.global_position.distance_to(jugador_local.global_position)
		
		# Solo actualizar si el jugador se ha movido significativamente
		if distancia > 5.0:
			# Interpolación suave hacia el jugador
			var velocidad_camara = 5.0
			camara.global_position = camara.global_position.lerp(jugador_local.global_position, velocidad_camara * delta)
		else:
			# Si está cerca, seguir exactamente
			camara.global_position = jugador_local.global_position

func _on_jugador_muerto(id_jugador: int):
	print("Jugador eliminado: ", id_jugador)
	# Aquí podrías añadir efectos visuales de muerte

func _on_juego_terminado(ganador: int):
	print("Juego terminado. Ganador: ", ganador)
	# La pantalla de resultados se maneja en GestorJuego

func _on_peer_connected(id):
	print("Peer conectado: ", id)
	print("Mis peers actuales: ", multiplayer.get_peers())
	
	# Crear jugador para el nuevo peer (solo el servidor)
	if multiplayer.is_server():
		var indice = multiplayer.get_peers().size()
		crear_jugador(id, indice)

# Función para manejar desconexiones
func _on_peer_disconnected(id: int):
	if id in jugadores_instanciados:
		jugadores_instanciados[id].queue_free()
		jugadores_instanciados.erase(id)

# Función de respaldo si no hay multiplayer
func crear_jugador_individual():
	print("Creando jugador individual (sin multiplayer)")
	crear_jugador(1, 0)
