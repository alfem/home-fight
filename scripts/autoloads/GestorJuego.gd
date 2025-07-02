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
	# Las conexiones de red se harán cuando sea necesario
	# multiplayer.peer_connected.connect(_on_jugador_conectado)
	# multiplayer.peer_disconnected.connect(_on_jugador_desconectado)

func iniciar_juego():
	print("Iniciando juego...")
	
	# Conectar señales de red ahora que el multiplayer está activo
	#conectar_senales_red()
	
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
	
	for id in multiplayer.get_peers():
		jugadores_vivos[id] = true
		estadisticas_jugadores[id] = {"eliminaciones": 0, "objetos_recogidos": 0}
	
	# El servidor también juega
	jugadores_vivos[1] = true
	estadisticas_jugadores[1] = {"eliminaciones": 0, "objetos_recogidos": 0}
	
	# Comenzar a generar objetos después de un pequeño delay
	await get_tree().create_timer(2.0).timeout
	iniciar_generacion_objetos()

func verificar_escena_juego() -> bool:
	# Verificar que estamos en la escena Principal con Laberinto
	var escena_actual = get_tree().current_scene
	if not escena_actual:
		return false
	
	var laberinto = buscar_laberinto()
	return laberinto != null

func buscar_laberinto() -> Node:
	# Buscar el nodo laberinto de forma segura
	var escena_actual = get_tree().current_scene
	if not escena_actual:
		return null
	
	# Buscar por nombre
	var laberinto = escena_actual.find_child("Laberinto", true, false)
	if laberinto:
		return laberinto
	
	# Buscar en Principal/Laberinto
	var principal = escena_actual.get_node_or_null(".")
	if principal:
		laberinto = principal.get_node_or_null("Laberinto")
		if laberinto:
			return laberinto
	
	return null

func iniciar_generacion_objetos():
	# Crear temporizador para generar objetos
	if temporizador_objetos:
		temporizador_objetos.queue_free()
	
	temporizador_objetos = Timer.new()
	temporizador_objetos.wait_time = configuracion_juego.tiempo_aparicion_objetos
	temporizador_objetos.timeout.connect(_generar_objeto_aleatorio)
	temporizador_objetos.autostart = true
	add_child(temporizador_objetos)
	
	print("Generación de objetos iniciada")

func _generar_objeto_aleatorio():
	if not juego_activo:
		return
		
	if objetos_en_mapa.size() >= configuracion_juego.max_objetos_simultaneos:
		return
	
	var tipos_objetos = ["espada", "hacha", "pistola", "rifle", "escudo", "medicina"]
	var tipo_elegido = tipos_objetos[randi() % tipos_objetos.size()]
	
	# Obtener posición aleatoria del laberinto de forma segura
	var laberinto = buscar_laberinto()
	if laberinto and laberinto.has_method("obtener_posicion_libre_aleatoria"):
		var posicion = laberinto.obtener_posicion_libre_aleatoria()
		crear_objeto_en_red.rpc(tipo_elegido, posicion)
	else:
		print("No se puede generar objeto: laberinto no encontrado")

@rpc("call_local")
func crear_objeto_en_red(tipo: String, posicion: Vector2):
	# Verificar que tenemos la escena del objeto
	var ruta_objeto = "res://escenas/objetos/ObjetoRecogible.tscn"
	if not ResourceLoader.exists(ruta_objeto):
		print("ObjetoRecogible.tscn no existe, saltando creación de objeto")
		return
	
	# Buscar el laberinto de forma segura
	var laberinto = buscar_laberinto()
	if not laberinto:
		print("No se puede crear objeto: laberinto no encontrado")
		return
	
	var escena_objeto = load(ruta_objeto)
	var objeto = escena_objeto.instantiate()
	
	if objeto.has_method("configurar_tipo"):
		objeto.configurar_tipo(tipo)
	
	objeto.position = posicion
	laberinto.add_child(objeto)
	objetos_en_mapa.append(objeto)
	
	print("Objeto creado: ", tipo, " en ", posicion)

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

func notificar_muerte_jugador(id_jugador: int, id_atacante: int = -1):
	# Reproducir sonido de muerte
	reproducir_sonido_muerte.rpc()
	
	# Actualizar estadísticas del atacante
	if id_atacante != -1 and id_atacante in estadisticas_jugadores:
		estadisticas_jugadores[id_atacante].eliminaciones += 1
	
	jugadores_vivos.erase(id_jugador)
	jugador_muerto.emit(id_jugador)
	
	if jugadores_vivos.size() <= 1:
		var ganador = jugadores_vivos.keys()[0] if jugadores_vivos.size() == 1 else -1
		terminar_juego(ganador)

@rpc("call_local")
func reproducir_sonido_muerte():
	GestorAudio.reproducir_efecto("muerte_jugador")

func terminar_juego(id_ganador: int):
	print("Terminando juego. Ganador: ", id_ganador)
	juego_activo = false
	
	# Detener generación de objetos
	if temporizador_objetos:
		temporizador_objetos.queue_free()
		temporizador_objetos = null
	
	juego_terminado.emit(id_ganador)
	
	# Cambiar a pantalla de resultados
	await get_tree().create_timer(2.0).timeout
	mostrar_resultados.rpc(id_ganador, estadisticas_jugadores)

@rpc("call_local")
func mostrar_resultados(ganador: int, estadisticas: Dictionary):
	var ruta_resultados = "res://escenas/interfaz/PantallaResultados.tscn"
	
	if not ResourceLoader.exists(ruta_resultados):
		print("PantallaResultados.tscn no existe, volviendo al menú")
		get_tree().change_scene_to_file("res://escenas/interfaz/MenuPrincipal.tscn")
		return
	
	var escena_resultados = load(ruta_resultados)
	var pantalla_resultados = escena_resultados.instantiate()
	
	get_tree().root.add_child(pantalla_resultados)
	
	if pantalla_resultados.has_method("configurar_resultados"):
		pantalla_resultados.configurar_resultados(ganador, estadisticas)
	
	# Eliminar la escena actual del juego
	if get_tree().current_scene:
		get_tree().current_scene.queue_free()

@rpc("any_peer", "call_local")
func solicitar_reinicio():
	if multiplayer.is_server():
		reiniciar_partida.rpc()

@rpc("call_local")
func reiniciar_partida():
	juego_activo = false
	
	# Limpiar objetos
	for objeto in objetos_en_mapa:
		if is_instance_valid(objeto):
			objeto.queue_free()
	objetos_en_mapa.clear()
	
	# Detener temporizadores
	if temporizador_objetos:
		temporizador_objetos.queue_free()
		temporizador_objetos = null
	
	partida_reiniciada.emit()
	get_tree().change_scene_to_file("res://escenas/juego/Principal.tscn")

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
func limpiar_estado():
	juego_activo = false
	jugadores_vivos.clear()
	estadisticas_jugadores.clear()
	
	for objeto in objetos_en_mapa:
		if is_instance_valid(objeto):
			objeto.queue_free()
	objetos_en_mapa.clear()
	
	if temporizador_objetos:
		temporizador_objetos.queue_free()
		temporizador_objetos = null
