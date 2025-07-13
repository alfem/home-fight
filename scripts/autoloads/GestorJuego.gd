extends Node

signal jugador_muerto(id_jugador)
signal juego_terminado(ganador)
signal partida_reiniciada

var jugadores_vivos = {}
var objetos_en_mapa = []
var estadisticas_jugadores = {}
var temporizador_objetos = null
var juego_activo = false

var configuracion_juego = {
	"tiempo_aparicion_objetos": 5.0,
	"max_objetos_simultaneos": 15,
	"vida_inicial": 100,
	"velocidad_jugador": 200
}

func _ready():
	print("GestorJuego iniciado")
	# Conectar señal de cambio de escena para limpiar automáticamente
	get_tree().tree_changed.connect(_on_tree_changed)

func _on_tree_changed():
	# Verificar si estamos en una escena que no es de juego
	var escena_actual = get_tree().current_scene
	if escena_actual and not es_escena_de_juego(escena_actual):
		print("=== DETECTADO CAMBIO A ESCENA NO-JUEGO: ", escena_actual.name, " ===")
		detener_juego_completamente()

func es_escena_de_juego(escena: Node) -> bool:
	# Verificar si la escena es una escena de juego válida
	if not escena:
		return false
	
	var nombre_escena = escena.name.to_lower()
	
	# Es escena de juego si es "Principal" o contiene "juego"
	if nombre_escena == "principal" or nombre_escena.contains("juego"):
		return true
	
	# También verificar si tiene laberinto (más confiable)
	var tiene_laberinto = escena.find_child("Laberinto", true, false) != null
	
	print("Verificando escena: ", escena.name, " - Es juego: ", tiene_laberinto)
	return tiene_laberinto

func detener_juego_completamente():
	print("=== DETENIENDO JUEGO COMPLETAMENTE ===")
	
	# Marcar juego como inactivo INMEDIATAMENTE
	juego_activo = false
	
	# Detener y eliminar temporizador INMEDIATAMENTE
	if temporizador_objetos:
		print("Deteniendo temporizador de objetos")
		temporizador_objetos.stop()
		temporizador_objetos.queue_free()
		temporizador_objetos = null
	
	# Limpiar objetos existentes
	for objeto in objetos_en_mapa:
		if is_instance_valid(objeto):
			objeto.queue_free()
	objetos_en_mapa.clear()
	
	print("Juego detenido completamente")

func iniciar_juego():
	print("Iniciando juego...")
	print("Inicializando estado de juego...")
	
	# IMPORTANTE: Limpiar estado previo completamente
	limpiar_estado_completo()
	
	# Verificar que estamos en la escena correcta
	if not verificar_escena_juego():
		print("Error: No se puede iniciar el juego, no estamos en la escena Principal")
		return
	
	# Detener música del menú y preparar sonidos del juego
	GestorAudio.detener_musica()
	
	# Inicializar jugadores
	jugadores_vivos.clear()
	estadisticas_jugadores.clear()
	objetos_en_mapa.clear()
	juego_activo = true
	
	# IMPORTANTE: Añadir TODOS los jugadores actuales
	# Obtener todos los jugadores del juego
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	print("IDs de jugadores detectados: ", jugadores.map(func(j): return j.id_jugador))
	
	for jugador in jugadores:
		var id = jugador.id_jugador
		jugadores_vivos[id] = true
		estadisticas_jugadores[id] = {"eliminaciones": 0, "objetos_recogidos": 0}
	
	print("Jugadores vivos inicializados: ", jugadores_vivos)
	print("Estadísticas inicializadas: ", estadisticas_jugadores)
	
	# Comenzar a generar objetos después de un pequeño delay
	await get_tree().create_timer(2.0).timeout
	iniciar_generacion_objetos()

# NUEVA FUNCIÓN para agregar jugadores dinámicamente
func agregar_jugador_vivo(id_jugador: int):
	print("=== AGREGANDO JUGADOR VIVO AL GESTOR ===")
	print("ID: ", id_jugador)
	print("Jugadores vivos ANTES: ", jugadores_vivos)
	
	jugadores_vivos[id_jugador] = true
	estadisticas_jugadores[id_jugador] = {"eliminaciones": 0, "objetos_recogidos": 0}
	
	print("Jugadores vivos DESPUÉS: ", jugadores_vivos)
	print("Estadísticas DESPUÉS: ", estadisticas_jugadores)

func verificar_escena_juego() -> bool:
	# Verificar que estamos en la escena Principal con Laberinto
	var escena_actual = get_tree().current_scene
	if not escena_actual:
		print("ERROR: No hay escena actual")
		return false
	
	print("Escena actual: ", escena_actual.name)
	var laberinto = buscar_laberinto()
	var resultado = laberinto != null
	print("Laberinto encontrado: ", resultado)
	if laberinto:
		print("Laberinto: ", laberinto.name)
	
	return resultado

func buscar_laberinto() -> Node:
	# Buscar el nodo laberinto de forma segura
	var escena_actual = get_tree().current_scene
	if not escena_actual:
		print("ERROR: No hay escena actual en buscar_laberinto")
		return null
	
	print("Buscando laberinto en escena: ", escena_actual.name)
	
	# VERIFICACIÓN TEMPRANA: Si no es escena de juego, no buscar
	if not es_escena_de_juego(escena_actual):
		print("Escena actual no es de juego, cancelando búsqueda de laberinto")
		return null
	
	# Método 1: Buscar por nombre usando find_child
	var laberinto = escena_actual.find_child("Laberinto", true, false)
	if laberinto:
		print("Laberinto encontrado con find_child: ", laberinto.name)
		return laberinto
	
	# Método 2: Buscar directamente en Principal/Laberinto
	var laberinto_directo = escena_actual.get_node_or_null("Laberinto")
	if laberinto_directo:
		print("Laberinto encontrado directamente: ", laberinto_directo.name)
		return laberinto_directo
	
	# Método 3: Buscar en todos los nodos hijos recursivamente
	print("Buscando laberinto recursivamente...")
	var laberinto_recursivo = buscar_laberinto_recursivo(escena_actual)
	if laberinto_recursivo:
		print("Laberinto encontrado recursivamente: ", laberinto_recursivo.name)
		return laberinto_recursivo
	
	print("ERROR: Laberinto no encontrado en ninguna búsqueda")
	print("Hijos de la escena actual:")
	for child in escena_actual.get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	
	return null

func buscar_laberinto_recursivo(nodo: Node) -> Node:
	# Buscar recursivamente en todos los nodos
	if nodo.name == "Laberinto":
		return nodo
	
	for child in nodo.get_children():
		var resultado = buscar_laberinto_recursivo(child)
		if resultado:
			return resultado
	
	return null

func iniciar_generacion_objetos():
	print("=== INICIANDO GENERACIÓN DE OBJETOS ===")
	
	# VERIFICACIÓN CRÍTICA: ¿Seguimos en una escena de juego?
	if not juego_activo:
		print("ERROR: Juego no activo, cancelando generación de objetos")
		return
	
	var escena_actual = get_tree().current_scene
	if not es_escena_de_juego(escena_actual):
		print("ERROR: No estamos en escena de juego, cancelando generación de objetos")
		return
	
	# Limpiar temporizador anterior si existe
	if temporizador_objetos:
		print("Eliminando temporizador anterior")
		temporizador_objetos.queue_free()
		temporizador_objetos = null
	
	# Verificar que tenemos laberinto
	var laberinto = buscar_laberinto()
	if not laberinto:
		print("ERROR: No se puede iniciar generación de objetos sin laberinto")
		return
	
	print("Laberinto confirmado para generación de objetos: ", laberinto.name)
	
	# Crear nuevo temporizador
	temporizador_objetos = Timer.new()
	temporizador_objetos.wait_time = configuracion_juego.tiempo_aparicion_objetos
	temporizador_objetos.timeout.connect(_generar_objeto_aleatorio)
	temporizador_objetos.autostart = true
	add_child(temporizador_objetos)
	
	print("Generación de objetos iniciada correctamente")

func _generar_objeto_aleatorio():
	# VERIFICACIONES CRÍTICAS AL INICIO
	if not juego_activo:
		print("Juego no activo, cancelando generación de objeto")
		detener_temporizador()
		return
	
	var escena_actual = get_tree().current_scene
	if not escena_actual or not es_escena_de_juego(escena_actual):
		print("ERROR: No estamos en escena de juego válida")
		print("Escena actual: ", escena_actual.name if escena_actual else "null")
		detener_temporizador()
		return
		
	if objetos_en_mapa.size() >= configuracion_juego.max_objetos_simultaneos:
		print("Máximo de objetos alcanzado: ", objetos_en_mapa.size())
		return
	
	print("=== GENERANDO OBJETO ALEATORIO ===")
	
	var tipos_objetos = ["espada", "hacha", "pistola", "rifle", "escudo", "medicina"]
	var tipo_elegido = tipos_objetos[randi() % tipos_objetos.size()]
	
	print("Tipo de objeto elegido: ", tipo_elegido)
	
	# Obtener posición aleatoria del laberinto de forma segura
	var laberinto = buscar_laberinto()
	if not laberinto:
		print("ERROR: No se puede generar objeto - laberinto no encontrado")
		detener_temporizador()
		return
	
	print("Laberinto encontrado para objeto: ", laberinto.name)
	
	if laberinto.has_method("obtener_posicion_libre_aleatoria"):
		var posicion = laberinto.obtener_posicion_libre_aleatoria()
		print("Posición obtenida: ", posicion)
		crear_objeto_en_red.rpc(tipo_elegido, posicion)
	else:
		print("ERROR: Laberinto no tiene método obtener_posicion_libre_aleatoria")

func detener_temporizador():
	print("=== DETENIENDO TEMPORIZADOR DE OBJETOS ===")
	if temporizador_objetos:
		temporizador_objetos.stop()
		temporizador_objetos.queue_free()
		temporizador_objetos = null
	juego_activo = false

@rpc("call_local")
func crear_objeto_en_red(tipo: String, posicion: Vector2):
	# VERIFICACIÓN CRÍTICA AL INICIO
	if not juego_activo:
		print("Juego no activo, cancelando creación de objeto")
		return
	
	print("=== CREANDO OBJETO EN RED ===")
	print("Tipo: ", tipo, " Posición: ", posicion)
	
	# Verificar que tenemos la escena del objeto
	var ruta_objeto = "res://escenas/objetos/ObjetoRecogible.tscn"
	if not ResourceLoader.exists(ruta_objeto):
		print("ERROR: ObjetoRecogible.tscn no existe")
		return
	
	# Buscar el laberinto de forma segura
	var laberinto = buscar_laberinto()
	if not laberinto:
		print("ERROR: No se puede crear objeto - laberinto no encontrado en crear_objeto_en_red")
		return
	
	print("Creando objeto en laberinto: ", laberinto.name)
	
	var escena_objeto = load(ruta_objeto)
	var objeto = escena_objeto.instantiate()
	
	if objeto.has_method("configurar_tipo"):
		objeto.configurar_tipo(tipo)
	
	objeto.position = posicion
	laberinto.add_child(objeto)
	objetos_en_mapa.append(objeto)
	
	print("Objeto creado exitosamente: ", tipo, " en ", posicion)

func jugador_recoge_objeto(jugador_id: int, objeto):
	# Reproducir sonido de recoger objeto
	reproducir_sonido_recoger.rpc()
	
	# Actualizar estadísticas
	if jugador_id in estadisticas_jugadores:
		estadisticas_jugadores[jugador_id].objetos_recogidos += 1
	
	objetos_en_mapa.erase(objeto)
	objeto.queue_free()

@rpc("call_local")
func reproducir_sonido_recoger():
	GestorAudio.reproducir_efecto("recoger_objeto")

@rpc("any_peer", "call_local")
func notificar_muerte_jugador_rpc(id_jugador: int, id_atacante: int = -1):
	# Esta función será llamada por los clientes para notificar al servidor
	if multiplayer.is_server():
		print("Servidor recibió notificación de muerte: jugador ", id_jugador, " por atacante ", id_atacante)
		notificar_muerte_jugador(id_jugador, id_atacante)

func notificar_muerte_jugador(id_jugador: int, id_atacante: int = -1):
	print("=== NOTIFICACIÓN DE MUERTE ===")
	print("Jugador muerto: ", id_jugador)
	print("Atacante: ", id_atacante)
	print("Soy servidor: ", multiplayer.is_server())
	
	if multiplayer.is_server():
		print("Servidor procesando muerte...")
		# Solo el servidor maneja la lógica de muerte
		reproducir_sonido_muerte.rpc()
		
		# Actualizar estadísticas del atacante
		if id_atacante != -1 and id_atacante in estadisticas_jugadores:
			estadisticas_jugadores[id_atacante].eliminaciones += 1
			print("*** ESTADÍSTICAS DEL ATACANTE ", id_atacante, " ACTUALIZADAS ***")
			print("Eliminaciones: ", estadisticas_jugadores[id_atacante].eliminaciones)
		
		print("Jugadores vivos ANTES: ", jugadores_vivos)
		if id_jugador in jugadores_vivos:
			jugadores_vivos.erase(id_jugador)
			print("Jugador ", id_jugador, " removido de jugadores vivos")
		else:
			print("WARNING: Jugador ", id_jugador, " no estaba en jugadores_vivos")
		
		# Notificar a todos los clientes
		jugador_muerto.emit(id_jugador)
		informar_muerte_cliente.rpc(id_jugador)
		
		print("Jugadores vivos DESPUÉS: ", jugadores_vivos)
		print("Cantidad de jugadores vivos: ", jugadores_vivos.size())
		
		# Verificar si el juego terminó
		determinar_ganador()
	else:
		print("Cliente enviando notificación de muerte al servidor...")
		# Los clientes solo notifican al servidor
		notificar_muerte_jugador_rpc.rpc_id(1, id_jugador, id_atacante)

@rpc("call_local")
func informar_muerte_cliente(id_jugador: int):
	# Los clientes reciben esta notificación del servidor
	if not multiplayer.is_server():
		jugador_muerto.emit(id_jugador)
	print("Todos los clientes notificados de muerte del jugador ", id_jugador)

func determinar_ganador():
	print("=== DETERMINANDO GANADOR (SOLO SERVIDOR) ===")
	print("Soy servidor: ", multiplayer.is_server())
	
	if not multiplayer.is_server():
		print("No soy servidor, saliendo de determinar_ganador")
		return
	
	print("Jugadores vivos actuales: ", jugadores_vivos)
	print("Cantidad de jugadores vivos: ", jugadores_vivos.size())
	print("Keys de jugadores vivos: ", jugadores_vivos.keys())
	
	if jugadores_vivos.size() <= 1:
		var ganador = -1  # Empate por defecto
		
		if jugadores_vivos.size() == 1:
			ganador = jugadores_vivos.keys()[0]
			print("*** GANADOR DETERMINADO POR SERVIDOR: ", ganador, " ***")
			print("Tipo de ganador: ", typeof(ganador))
		else:
			print("*** EMPATE DETERMINADO POR SERVIDOR - no quedan jugadores vivos ***")
		
		print("¡JUEGO TERMINADO POR SERVIDOR!")
		print("Ganador final que se va a enviar: ", ganador)
		print("Estadísticas que se van a enviar: ", estadisticas_jugadores)
		
		terminar_juego(ganador)

@rpc("call_local")
func reproducir_sonido_muerte():
	GestorAudio.reproducir_efecto("muerte_jugador")

func terminar_juego(id_ganador: int):
	print("Terminando juego. Ganador: ", id_ganador)
	
	# DETENER JUEGO INMEDIATAMENTE
	detener_juego_completamente()
	
	# Notificar a todos del fin del juego
	terminar_juego_definitivo.rpc(id_ganador, estadisticas_jugadores)

@rpc("call_local")
func terminar_juego_definitivo(ganador: int, estadisticas: Dictionary):
	print("=== TERMINANDO JUEGO DEFINITIVO ===")
	print("Ganador final recibido en RPC: ", ganador)
	print("Tipo de ganador: ", typeof(ganador))
	print("Estadísticas finales recibidas: ", estadisticas)
	print("Mi ID: ", multiplayer.get_unique_id())
	print("Soy servidor: ", multiplayer.is_server())
	
	# DETENER TODO INMEDIATAMENTE
	detener_juego_completamente()
	
	# Actualizar estado local
	estadisticas_jugadores = estadisticas
	
	print("Estado local actualizado:")
	print("  - estadisticas_jugadores actualizadas: ", estadisticas_jugadores)
	
	juego_terminado.emit(ganador)
	
	# Cambiar a pantalla de resultados
	await get_tree().create_timer(2.0).timeout
	print("Después del delay, enviando a mostrar_resultados_finales:")
	print("  - Ganador: ", ganador)
	print("  - Mi ID: ", multiplayer.get_unique_id())
	mostrar_resultados_finales(ganador, estadisticas)

func mostrar_resultados_finales(ganador: int, estadisticas: Dictionary):
	print("=== CARGANDO PANTALLA DE RESULTADOS ===")
	print("Ganador FINAL a enviar: ", ganador)
	print("Tipo del ganador: ", typeof(ganador))
	print("Ganador es -1?: ", ganador == -1)
	print("Ganador es 1?: ", ganador == 1) 
	print("Estadísticas FINALES a enviar: ", estadisticas)
	
	var ruta_resultados = "res://escenas/interfaz/PantallaResultados.tscn"
	
	if not ResourceLoader.exists(ruta_resultados):
		print("PantallaResultados.tscn no existe, volviendo al menú")
		get_tree().change_scene_to_file("res://escenas/interfaz/MenuPrincipal.tscn")
		return
	
	print("Cargando escena de resultados...")
	var escena_resultados = load(ruta_resultados)
	var pantalla_resultados = escena_resultados.instantiate()
	
	get_tree().root.add_child(pantalla_resultados)
	
	if pantalla_resultados.has_method("configurar_resultados"):
		print("Configurando resultados CORRECTAMENTE...")
		print("  - Ganador que voy a enviar: ", ganador)
		print("  - Tipo: ", typeof(ganador))
		print("  - Estadísticas que voy a enviar: ", estadisticas)
		pantalla_resultados.configurar_resultados(ganador, estadisticas)
		print("configurar_resultados llamado exitosamente")
	else:
		print("ERROR: pantalla_resultados no tiene método configurar_resultados")
	
	# Eliminar la escena actual del juego
	if get_tree().current_scene:
		print("Eliminando escena actual: ", get_tree().current_scene.name)
		get_tree().current_scene.queue_free()
	
	print("Pantalla de resultados configurada y mostrada exitosamente")

@rpc("any_peer", "call_local")
func solicitar_reinicio():
	if multiplayer.is_server():
		reiniciar_partida.rpc()

@rpc("call_local")
func reiniciar_partida():
	print("=== REINICIANDO PARTIDA ===")
	
	# Limpiar estado completamente
	limpiar_estado_completo()
	
	partida_reiniciada.emit()
	
	# Cambiar a la escena del juego
	print("Cambiando a escena Principal...")
	get_tree().change_scene_to_file("res://escenas/juego/Principal.tscn")

# NUEVA FUNCIÓN: Limpiar estado completamente
func limpiar_estado_completo():
	print("=== LIMPIANDO ESTADO COMPLETO DEL GESTOR ===")
	
	# DETENER TODO INMEDIATAMENTE
	detener_juego_completamente()
	
	# Limpiar datos de juego
	jugadores_vivos.clear()
	estadisticas_jugadores.clear()
	
	print("Estado del gestor limpiado completamente")

func reproducir_sonido_ataque(tipo_arma: String):
	match tipo_arma:
		"pistola":
			reproducir_sonido_disparo_pistola.rpc()
		"rifle":
			reproducir_sonido_disparo_rifle.rpc()
		"espada", "hacha":
			reproducir_sonido_golpe.rpc()

@rpc("call_local")
func reproducir_sonido_disparo_pistola():
	GestorAudio.reproducir_efecto("disparo_pistola")

@rpc("call_local") 
func reproducir_sonido_disparo_rifle():
	GestorAudio.reproducir_efecto("disparo_rifle")

@rpc("call_local")
func reproducir_sonido_golpe():
	GestorAudio.reproducir_efecto("golpe_espada")

func _on_jugador_conectado(id):
	print("Jugador conectado: ", id)

func _on_jugador_desconectado(id):
	print("Jugador desconectado: ", id)
	if id in jugadores_vivos:
		notificar_muerte_jugador(id)

# Función para limpiar al cambiar de escena
func reinicializar_jugadores():
	print("=== REINICIALIZANDO JUGADORES EN GESTOR ===")
	
	# Limpiar estado anterior
	jugadores_vivos.clear()
	estadisticas_jugadores.clear()
	
	# Volver a detectar todos los jugadores
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	print("Jugadores encontrados para reinicializar: ", jugadores.size())
	
	for jugador in jugadores:
		var id = jugador.id_jugador
		jugadores_vivos[id] = true
		estadisticas_jugadores[id] = {"eliminaciones": 0, "objetos_recogidos": 0}
		print("  - Jugador ", id, " reinicializado")
	
	print("Jugadores vivos después de reinicializar: ", jugadores_vivos)
	print("Estadísticas después de reinicializar: ", estadisticas_jugadores)

# FUNCIÓN DEPRECATED - usar limpiar_estado_completo()
func limpiar_estado():
	limpiar_estado_completo()
