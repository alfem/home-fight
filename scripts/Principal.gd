extends Node2D

@onready var laberinto = $Laberinto
@onready var contenedor_jugadores = $ContenedorJugadores
@onready var camara = $Camara2D
@onready var hud = $InterfazUsuario/HUD

var jugadores_instanciados = {}
var jugador_local = null
var mi_indice_asignado = -1

func _ready():
	print("Escena Principal iniciada")
	print("Mi ID: ", multiplayer.get_unique_id())
	print("Soy servidor: ", multiplayer.is_server())
	print("Peers conectados: ", multiplayer.get_peers())
	
	# Limpiar cualquier jugador previo
	limpiar_todos_los_jugadores()
	
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
	
	# Inicialización diferente para servidor vs cliente
	await get_tree().create_timer(0.2).timeout
	
	if multiplayer.is_server():
		inicializar_como_servidor()
	else:
		inicializar_como_cliente()

func limpiar_todos_los_jugadores():
	print("=== LIMPIANDO TODOS LOS JUGADORES EXISTENTES ===")
	
	# Limpiar del diccionario
	for id in jugadores_instanciados:
		if jugadores_instanciados[id] and is_instance_valid(jugadores_instanciados[id]):
			jugadores_instanciados[id].queue_free()
	jugadores_instanciados.clear()
	
	# Limpiar del grupo "jugadores"
	var jugadores_en_grupo = get_tree().get_nodes_in_group("jugadores")
	for jugador in jugadores_en_grupo:
		jugador.queue_free()
	
	# Limpiar todos los hijos del contenedor
	for child in contenedor_jugadores.get_children():
		child.queue_free()
	
	# Esperar a que se procesen las eliminaciones
	await get_tree().process_frame
	print("Limpieza completa terminada")

func inicializar_como_servidor():
	print("=== INICIALIZANDO COMO SERVIDOR ===")
	
	# El servidor crea su propio jugador primero
	mi_indice_asignado = 0
	crear_mi_jugador(mi_indice_asignado)
	
	# IMPORTANTE: El servidor también debe iniciar el GestorJuego
	await get_tree().create_timer(0.5).timeout
	print("*** SERVIDOR INICIANDO GESTOR JUEGO ***")
	if GestorJuego:
		GestorJuego.iniciar_juego()

func inicializar_como_cliente():
	print("=== INICIALIZANDO COMO CLIENTE ===")
	
	# Solicitar mi índice al servidor
	await get_tree().create_timer(0.5).timeout
	solicitar_indice_al_servidor.rpc_id(1)

@rpc("any_peer", "call_local")
func solicitar_indice_al_servidor():
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	print("=== SERVIDOR PROCESANDO SOLICITUD DE CLIENTE ===")
	print("Servidor recibió solicitud de índice de cliente: ", sender_id)
	print("Jugadores actuales en servidor: ", jugadores_instanciados.keys())
	
	# Calcular índice basado en número de jugadores existentes
	var siguiente_indice = jugadores_instanciados.size()
	
	print("Asignando índice ", siguiente_indice, " al cliente ", sender_id)
	
	# IMPORTANTE: EL SERVIDOR CREA EL JUGADOR DEL CLIENTE INMEDIATAMENTE
	print("*** SERVIDOR CREANDO JUGADOR DEL CLIENTE DIRECTAMENTE ***")
	crear_jugador_interno(sender_id, siguiente_indice)
	
	# Enviar información del servidor al cliente
	print("Enviando información del servidor al nuevo cliente...")
	enviar_info_servidor_a_cliente.rpc_id(sender_id, 1, 0)
	
	# Responder al cliente con su índice
	asignar_indice_cliente.rpc_id(sender_id, siguiente_indice)
	
	# IMPORTANTE: Actualizar GestorJuego inmediatamente
	if GestorJuego:
		print("*** ACTUALIZANDO GESTOR JUEGO CON NUEVO CLIENTE ***")
		GestorJuego.agregar_jugador_vivo(sender_id)

@rpc("any_peer", "call_local")
func enviar_info_servidor_a_cliente(servidor_id: int, servidor_indice: int):
	print("=== RECIBIDA INFORMACIÓN DEL SERVIDOR ===")
	print("Servidor ID: ", servidor_id, " Índice: ", servidor_indice)
	print("Mi ID: ", multiplayer.get_unique_id())
	
	# Solo los clientes procesan esto
	if multiplayer.is_server():
		print("Soy servidor, ignorando mi propia información")
		return
	
	# Crear el jugador del servidor si no existe
	if servidor_id not in jugadores_instanciados:
		print("*** CREANDO JUGADOR DEL SERVIDOR EN CLIENTE ***")
		crear_jugador_interno(servidor_id, servidor_indice)
	else:
		print("Jugador del servidor ya existe, ignorando")

@rpc("any_peer", "call_local")
func asignar_indice_cliente(indice: int):
	if multiplayer.is_server():
		print("Soy servidor, ignorando asignación de índice")
		return
	
	print("=== CLIENTE RECIBIÓ ASIGNACIÓN ===")
	print("Cliente recibió asignación de índice: ", indice)
	mi_indice_asignado = indice
	
	# Crear mi jugador con el índice asignado
	crear_mi_jugador(mi_indice_asignado)
	
	# IMPORTANTE: EL CLIENTE TAMBIÉN DEBE INICIAR EL GESTOR JUEGO
	await get_tree().create_timer(0.5).timeout
	print("*** CLIENTE INICIANDO GESTOR JUEGO ***")
	if GestorJuego:
		GestorJuego.iniciar_juego()

func crear_mi_jugador(indice: int):
	print("=== CREANDO MI JUGADOR ===")
	var mi_id = multiplayer.get_unique_id()
	print("Mi ID: ", mi_id, " Índice: ", indice)
	
	# Verificar que no exista ya
	if mi_id in jugadores_instanciados:
		print("ERROR: Ya tengo un jugador con mi ID")
		return
	
	crear_jugador_interno(mi_id, indice)

func crear_jugador_interno(peer_id: int, indice_spawn: int):
	print("--- CREAR_JUGADOR_INTERNO ---")
	print("Peer ID: ", peer_id)
	print("Índice spawn: ", indice_spawn)
	print("Es mi ID: ", peer_id == multiplayer.get_unique_id())
	print("Soy servidor: ", multiplayer.is_server())
	
	# Verificación final
	if peer_id in jugadores_instanciados:
		print("ABORT: Jugador ", peer_id, " ya existe")
		return
	
	# Cargar la escena del jugador
	if not ResourceLoader.exists("res://escenas/juego/Jugador.tscn"):
		print("ERROR: No se encuentra Jugador.tscn")
		return
	
	var escena_jugador = load("res://escenas/juego/Jugador.tscn")
	var jugador = escena_jugador.instantiate()
	
	# Configurar el jugador
	jugador.name = "Jugador" + str(peer_id)
	jugador.id_jugador = peer_id
	jugador.es_local = (peer_id == multiplayer.get_unique_id())
	jugador.indice_jugador = indice_spawn
	
	print("Configurando jugador: ", jugador.name, " Local: ", jugador.es_local)
	
	# Posiciones de spawn bien separadas
	var posiciones_spawn = [
		Vector2(200, 200),    # Índice 0 - Servidor
		Vector2(1200, 200),   # Índice 1 - Cliente 1
		Vector2(200, 800),    # Índice 2 - Cliente 2  
		Vector2(1200, 800)    # Índice 3 - Cliente 3
	]
	
	var posicion_spawn = Vector2(200, 200)  # Posición por defecto
	
	if indice_spawn >= 0 and indice_spawn < posiciones_spawn.size():
		posicion_spawn = posiciones_spawn[indice_spawn]
	else:
		# Fallback para índices fuera de rango
		posicion_spawn = Vector2(200 + (indice_spawn % 4) * 300, 200 + (indice_spawn / 4) * 200)
	
	jugador.position = posicion_spawn
	print("Posición asignada: ", posicion_spawn)
	
	# Establecer autoridad de red
	jugador.set_multiplayer_authority(peer_id)
	
	# Configurar nombre
	if jugador.has_method("establecer_nombre"):
		var nombre = "Jugador " + str(peer_id)
		jugador.establecer_nombre(nombre)
	
	# IMPORTANTE: Añadir al diccionario ANTES del scene tree
	jugadores_instanciados[peer_id] = jugador
	
	# Añadir al grupo y al contenedor
	jugador.add_to_group("jugadores")
	contenedor_jugadores.add_child(jugador)
	
	print("Jugador añadido al scene tree exitosamente")
	
	# Si es el jugador local, configurar cámara
	if jugador.es_local:
		jugador_local = jugador
		print("*** JUGADOR LOCAL CONFIGURADO: ", jugador_local.name)
		call_deferred("configurar_camara_seguimiento")
	
	# DEBUG: Estado final
	print("Estado final - Jugadores en diccionario: ", jugadores_instanciados.keys())
	var en_grupo = get_tree().get_nodes_in_group("jugadores")
	print("Jugadores en grupo: ", en_grupo.size())
	for j in en_grupo:
		if "id_jugador" in j:
			print("  - Jugador: ID ", j.id_jugador, " Local: ", j.es_local, " Pos: ", j.position)
	print("--- FIN CREAR_JUGADOR_INTERNO ---")

func configurar_camara_seguimiento():
	if jugador_local and camara:
		print("Configurando cámara para seguir al jugador local: ", jugador_local.name)
		camara.global_position = jugador_local.global_position
		camara.enabled = true
		camara.make_current()
		print("Cámara configurada en posición: ", camara.global_position)
	else:
		print("ERROR: No se pudo configurar cámara. jugador_local: ", jugador_local, " camara: ", camara)

func _process(delta):
	if jugador_local and camara and is_instance_valid(jugador_local):
		var distancia = camara.global_position.distance_to(jugador_local.global_position)
		
		if distancia > 5.0:
			var velocidad_camara = 5.0
			camara.global_position = camara.global_position.lerp(jugador_local.global_position, velocidad_camara * delta)
		else:
			camara.global_position = jugador_local.global_position

func _on_jugador_muerto(id_jugador: int):
	print("Jugador eliminado: ", id_jugador)

func _on_juego_terminado(ganador: int):
	print("Juego terminado. Ganador: ", ganador)

func _on_peer_connected(id):
	print("=== PEER CONECTADO: ", id, " ===")
	print("Peers actuales después de conexión: ", multiplayer.get_peers())

func _on_peer_disconnected(id: int):
	print("=== PEER DESCONECTADO: ", id, " ===")
	
	if id in jugadores_instanciados:
		jugadores_instanciados[id].queue_free()
		jugadores_instanciados.erase(id)
		print("Jugador ", id, " eliminado del juego")
	
	if GestorJuego and GestorJuego.has_method("_on_jugador_desconectado"):
		GestorJuego._on_jugador_desconectado(id)
