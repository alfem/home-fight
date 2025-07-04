extends CharacterBody2D
class_name JugadorPersonaje

signal vida_cambiada(nueva_vida)
signal jugador_muerto

@export var velocidad_movimiento = 200.0
@export var vida_maxima = 100
@export var dano_base = 20

var vida_actual: int
var arma_equipada: String = ""
var municion_actual: int = 0
var tiene_escudo: bool = false
var id_jugador: int
var es_local: bool = false
var nombre_jugador: String = "Jugador"

# Referencias a nodos
@onready var sprite_jugador = $SpriteJugador
@onready var area_ataque = $AreaAtaque
@onready var indicador_alcance = $AreaAtaque/IndicadorAlcance
@onready var detector_objetos = $DetectorObjetos
@onready var etiqueta_nombre = $EtiquetaNombre
@onready var barra_vida_local = $BarraVidaLocal
@onready var efectos_visuales = $EfectosVisuales
@onready var efecto_ataque = $EfectosVisuales/EfectoAtaque
@onready var efecto_recogida = $EfectosVisuales/EfectoRecogida

func _ready():
	print("Jugador inicializado")
	
	# Configurar ID y autoridad
	id_jugador = get_multiplayer_authority()
	es_local = (id_jugador == multiplayer.get_unique_id())
	
	print("Jugador ID: ", id_jugador, " Local: ", es_local, " Unique ID: ", multiplayer.get_unique_id())
	
	# CRÍTICO: Configurar colisiones correctamente
	configurar_colisiones()
	
	# Inicializar vida
	vida_actual = vida_maxima
	
	# Configurar colores únicos por jugador
	configurar_apariencia_inicial()
	
	# Solo el jugador local procesa input
	set_physics_process(es_local)
	
	# Añadir al grupo de jugadores
	add_to_group("jugadores")
	
	# Conectar señal de vida
	vida_cambiada.connect(_on_vida_cambiada)
	
	print("Jugador ", id_jugador, " listo. Local: ", es_local)

func configurar_colisiones():
	print("Configurando colisiones para jugador ", id_jugador)
	
	# JUGADOR PRINCIPAL - debe colisionar con paredes
	collision_layer = 2   # Está en capa "jugadores" (bit 2)
	collision_mask = 1    # Colisiona con "paredes" (bit 1)
	
	# ÁREA DE ATAQUE - debe detectar otros jugadores
	if area_ataque:
		area_ataque.collision_layer = 8   # Está en capa "ataques" (bit 4) 
		area_ataque.collision_mask = 2    # Detecta "jugadores" (bit 2)
	
	# DETECTOR DE OBJETOS - debe detectar objetos recogibles
	if detector_objetos:
		detector_objetos.collision_layer = 0   # No está en ninguna capa
		detector_objetos.collision_mask = 4    # Detecta "objetos" (bit 3)
	
	print("Colisiones configuradas:")
	print("  - Jugador: layer=", collision_layer, " mask=", collision_mask)
	if area_ataque:
		print("  - AreaAtaque: layer=", area_ataque.collision_layer, " mask=", area_ataque.collision_mask)
	if detector_objetos:
		print("  - DetectorObjetos: layer=", detector_objetos.collision_layer, " mask=", detector_objetos.collision_mask)

func configurar_apariencia_inicial():
	# Crear sprite con color único por jugador
	var colores_jugadores = [
		Color.BLUE,      # Jugador 1
		Color.RED,       # Jugador 2  
		Color.GREEN,     # Jugador 3
		Color.ORANGE     # Jugador 4
	]
	
	var color_jugador = colores_jugadores[(id_jugador - 1) % colores_jugadores.size()]
	
	var sprite = get_node_or_null("SpriteJugador")
	
	if sprite.texture:
		sprite.modulate = color_jugador
		print("Color aplicado al sprite existente: ", color_jugador)
	else:
		# Si no tiene textura, crear una redonda
		crear_textura_redonda(sprite, color_jugador)
	
	print("Jugador ", id_jugador, " configurado con color: ", color_jugador)
	
func crear_textura_redonda(sprite: Sprite2D, color: Color):
	# Crear textura REDONDA en lugar de cuadrada
	var imagen = Image.create(40, 40, false, Image.FORMAT_RGBA8)
	imagen.fill(Color.TRANSPARENT)  # Fondo transparente
	
	var centro = 20
	var radio = 18
	
	# Dibujar círculo pixel por pixel
	for y in range(40):
		for x in range(40):
			var distancia = Vector2(x - centro, y - centro).length()
			if distancia <= radio:
				imagen.set_pixel(x, y, color)
			elif distancia <= radio + 1:
				# Borde suavizado
				var alpha = 1.0 - (distancia - radio)
				imagen.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	
	var textura = ImageTexture.create_from_image(imagen)
	sprite.texture = textura
	
	print("Textura redonda creada para jugador ", id_jugador)

func crear_indicador_alcance():
	# Crear círculo semitransparente para mostrar alcance de ataque
	var imagen = Image.create(120, 120, false, Image.FORMAT_RGBA8)
	imagen.fill(Color.TRANSPARENT)
	
	var centro = 60
	var radio = 60
	
	for y in range(120):
		for x in range(120):
			var distancia = Vector2(x - centro, y - centro).length()
			if distancia <= radio and distancia >= radio - 3:
				imagen.set_pixel(x, y, Color(1, 0, 0, 0.5))  # Borde rojo
	
	var textura = ImageTexture.create_from_image(imagen)
	indicador_alcance.texture = textura
	indicador_alcance.visible = false

func configurar_efectos():
	# Configurar efectos visuales (por ahora simples)
	efecto_ataque.visible = false
	efecto_recogida.visible = false

func _physics_process(delta):
	# SOLO el jugador local procesa input
	if not es_local:
		return
	
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("mover_arriba"):
		direction.y -= 1
	if Input.is_action_pressed("mover_abajo"):
		direction.y += 1
	if Input.is_action_pressed("mover_izquierda"):
		direction.x -= 1
	if Input.is_action_pressed("mover_derecha"):
		direction.x += 1
	if Input.is_action_just_pressed("atacar"):
		print("¡Botón de ataque presionado por jugador ", id_jugador, "!")
		realizar_ataque()
		
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * velocidad_movimiento
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# Sincronizar posición solo si nos movemos
	if velocity != Vector2.ZERO:
		actualizar_posicion.rpc(position)

@rpc("unreliable")
func actualizar_estado(nueva_posicion: Vector2, direccion_movimiento: Vector2):
	if es_local:
		return
	
	# Interpolación suave para otros jugadores
	var tween = create_tween()
	tween.tween_property(self, "position", nueva_posicion, 0.1)
	
	# Actualizar orientación del sprite si es necesario
	if direccion_movimiento.x < 0:
		sprite_jugador.flip_h = true
	elif direccion_movimiento.x > 0:
		sprite_jugador.flip_h = false

@rpc("unreliable")
func actualizar_posicion(nueva_posicion: Vector2):
	# Solo los jugadores remotos actualizan su posición
	if es_local:
		return
	
	# Interpolación suave
	var tween = create_tween()
	tween.tween_property(self, "position", nueva_posicion, 0.1)

func realizar_ataque():
	print("REALIZANDO ATAQUE - Jugador ", id_jugador, " en posición ", position)
	
	# SOLO el jugador local puede atacar
	if not es_local:
		print("ERROR: Jugador no local intentando atacar")
		return
	
	# Mostrar indicador de alcance temporalmente
	mostrar_indicador_ataque()
	
	var objetivo = buscar_objetivo_cercano()
	if objetivo:
		var dano = calcular_dano()
		
		print("OBJETIVO ENCONTRADO! Jugador ", id_jugador, " atacando a jugador ", objetivo.id_jugador, " por ", dano, " de daño")
		
		# Reproducir sonido de ataque para todos
		reproducir_sonido_ataque_rpc.rpc(arma_equipada)
		
		if es_ataque_a_distancia():
			if municion_actual > 0:
				municion_actual -= 1
				# Enviar RPC a TODOS los clientes, no solo al objetivo
				realizar_dano_a_jugador.rpc(objetivo.id_jugador, dano, id_jugador)
				mostrar_efecto_ataque()
			else:
				print("Sin munición!")
		else:
			# Enviar RPC a TODOS los clientes, no solo al objetivo
			realizar_dano_a_jugador.rpc(objetivo.id_jugador, dano, id_jugador)
			mostrar_efecto_ataque()
	else:
		print("No hay objetivos en rango para jugador ", id_jugador)

@rpc("call_local")
func realizar_dano_a_jugador(id_objetivo: int, cantidad: int, id_atacante: int):
	# Buscar el jugador objetivo por ID
	var objetivo = encontrar_jugador_por_id(id_objetivo)
	if objetivo and objetivo.id_jugador == id_objetivo:
		print("Aplicando ", cantidad, " de daño a jugador ", id_objetivo, " desde atacante ", id_atacante)
		objetivo.recibir_dano_directo(cantidad, id_atacante)
	else:
		print("ERROR: No se encontró jugador objetivo con ID ", id_objetivo)

func encontrar_jugador_por_id(buscar_id: int):
	# Buscar en ContenedorJugadores
	var escena_principal = get_tree().current_scene
	if escena_principal:
		var contenedor_jugadores = escena_principal.get_node_or_null("ContenedorJugadores")
		if contenedor_jugadores:
			for child in contenedor_jugadores.get_children():
				if child.has_method("get_multiplayer_authority") and child.id_jugador == buscar_id:
					return child
	
	# Fallback: buscar en grupo
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	for jugador in jugadores:
		if jugador.id_jugador == buscar_id:
			return jugador
	
	return null

@rpc("call_local")
func reproducir_sonido_ataque_rpc(tipo_arma: String):
	match tipo_arma:
		"pistola":
			GestorAudio.reproducir_efecto("disparo_pistola")
		"rifle":
			GestorAudio.reproducir_efecto("disparo_rifle")
		"espada", "hacha":
			GestorAudio.reproducir_efecto("golpe_espada")

func mostrar_indicador_ataque():
	indicador_alcance.visible = true
	var tween = create_tween()
	tween.tween_property(indicador_alcance, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): indicador_alcance.visible = false)

func mostrar_efecto_ataque():
	# Efecto visual simple de ataque
	efecto_ataque.modulate = Color.WHITE
	efecto_ataque.visible = true
	var tween = create_tween()
	tween.tween_property(efecto_ataque, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): efecto_ataque.visible = false)

func buscar_objetivo_cercano():
	print("BUSCANDO OBJETIVO - Jugador ", id_jugador, " buscando desde posición ", position)
	
	var distancia_ataque = 100.0 if es_ataque_a_distancia() else 60.0
	print("Distancia de ataque: ", distancia_ataque)
	
	var objetivo_encontrado = null
	var distancia_minima = distancia_ataque + 1
	
	# Método 1: Buscar en el contenedor de jugadores de la escena Principal
	var escena_principal = get_tree().current_scene
	if escena_principal:
		var contenedor_jugadores = escena_principal.get_node_or_null("ContenedorJugadores")
		if contenedor_jugadores:
			print("Buscando en ContenedorJugadores...")
			for child in contenedor_jugadores.get_children():
				# VERIFICACIÓN CRÍTICA: No atacarse a sí mismo
				if child != self and child.id_jugador != id_jugador and child.has_method("recibir_dano") and child.vida_actual > 0:
					var distancia = position.distance_to(child.position)
					print("  - Jugador ", child.id_jugador, " a distancia ", distancia, " (mi ID: ", id_jugador, ")")
					if distancia <= distancia_ataque and distancia < distancia_minima:
						distancia_minima = distancia
						objetivo_encontrado = child
						print("    -> NUEVO OBJETIVO MÁS CERCANO")
	
	# Método 2: Fallback - buscar en el grupo de jugadores
	if not objetivo_encontrado:
		print("Fallback: buscando en grupo 'jugadores'...")
		var jugadores = get_tree().get_nodes_in_group("jugadores")
		print("Jugadores en grupo: ", jugadores.size())
		for jugador in jugadores:
			# VERIFICACIÓN CRÍTICA: No atacarse a sí mismo
			if jugador != self and jugador.id_jugador != id_jugador and jugador.has_method("recibir_dano") and jugador.vida_actual > 0:
				var distancia = position.distance_to(jugador.position)
				print("  - Jugador ", jugador.id_jugador, " a distancia ", distancia, " (mi ID: ", id_jugador, ")")
				if distancia <= distancia_ataque and distancia < distancia_minima:
					distancia_minima = distancia
					objetivo_encontrado = jugador
					print("    -> NUEVO OBJETIVO MÁS CERCANO")
	
	if objetivo_encontrado:
		print("OBJETIVO SELECCIONADO: Jugador ", objetivo_encontrado.id_jugador, " a distancia ", distancia_minima)
		# VERIFICACIÓN FINAL: Asegurar que no es el mismo jugador
		if objetivo_encontrado.id_jugador == id_jugador:
			print("ERROR: Se seleccionó a sí mismo como objetivo!")
			return null
	else:
		print("NO SE ENCONTRÓ OBJETIVO")
	
	return objetivo_encontrado

func detectar_objetivo_por_area(distancia_max: float):
	# Método simplificado sin await - usar detección directa por distancia
	var objetivo = null
	var distancia_minima = distancia_max + 1
	
	# Buscar todos los nodos CharacterBody2D en la escena
	var todos_los_nodos = get_tree().get_nodes_in_group("jugadores")
	
	print("Detectando por área - nodos encontrados: ", todos_los_nodos.size())
	
	for nodo in todos_los_nodos:
		# VERIFICACIÓN CRÍTICA: No atacarse a sí mismo
		if nodo != self and nodo.id_jugador != id_jugador and nodo.has_method("recibir_dano") and nodo.vida_actual > 0:
			var distancia = position.distance_to(nodo.position)
			print("  - Nodo ", nodo.id_jugador, " a distancia ", distancia, " (mi ID: ", id_jugador, ")")
			if distancia <= distancia_max and distancia < distancia_minima:
				distancia_minima = distancia
				objetivo = nodo
				print("    -> NUEVO OBJETIVO MÁS CERCANO")
	
	return objetivo

func es_ataque_a_distancia() -> bool:
	return arma_equipada in ["pistola", "rifle"]

func calcular_dano() -> int:
	var multiplicador = 1.0
	match arma_equipada:
		"espada": multiplicador = 1.5
		"hacha": multiplicador = 2.0
		"pistola": multiplicador = 1.8
		"rifle": multiplicador = 2.5
		_: multiplicador = 1.0
	
	return int(dano_base * multiplicador)

@rpc("call_local")
func recibir_dano_directo(cantidad: int, atacante_id: int):
	print("RECIBIENDO DAÑO DIRECTO - Jugador ", id_jugador, " recibe ", cantidad, " de daño de jugador ", atacante_id)
	
	# Verificar que no nos estamos atacando a nosotros mismos
	if atacante_id == id_jugador:
		print("ERROR: Jugador ", id_jugador, " intentando atacarse a sí mismo!")
		return
	
	if tiene_escudo and randf() < 0.3:  # 30% de bloqueo con escudo
		print("¡Ataque bloqueado por ", nombre_jugador, "!")
		mostrar_efecto_bloqueo.rpc()
		return
	
	vida_actual -= cantidad
	vida_cambiada.emit(vida_actual)
	
	# Efecto visual de daño
	mostrar_efecto_dano.rpc()
	
	print(nombre_jugador, " recibió ", cantidad, " de daño. Vida restante: ", vida_actual)
	
	if vida_actual <= 0:
		morir()

@rpc("call_local")
func recibir_dano(cantidad: int, atacante_id: int):
	# Mantener función antigua para compatibilidad, pero redirigir a la nueva
	recibir_dano_directo(cantidad, atacante_id)

@rpc("call_local")
func mostrar_efecto_dano():
	# Efecto de parpadeo rojo al recibir daño
	var tween = create_tween()
	tween.tween_property(sprite_jugador, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite_jugador, "modulate", Color.WHITE, 0.1)

@rpc("call_local")
func mostrar_efecto_bloqueo():
	# Efecto visual de bloqueo
	var tween = create_tween()
	tween.tween_property(sprite_jugador, "modulate", Color.CYAN, 0.1)
	tween.tween_property(sprite_jugador, "modulate", Color.WHITE, 0.1)

func morir():
	print(nombre_jugador, " ha muerto!")
	jugador_muerto.emit()
	
	# Notificar inmediatamente al GestorJuego - sin complicaciones de red
	if GestorJuego and GestorJuego.has_method("notificar_muerte_jugador"):
		print("Notificando muerte al GestorJuego - ID: ", id_jugador)
		GestorJuego.notificar_muerte_jugador(id_jugador)
	
	# Efectos visuales de muerte (para todos)
	sprite_jugador.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Gris semitransparente
	etiqueta_nombre.text = nombre_jugador + " (Muerto)"
	
	# Deshabilitar controles
	set_physics_process(false)
	
	# Mantener visible pero sin colisiones
	collision_layer = 0
	collision_mask = 0

func _on_objeto_detectado(objeto):
	_on_area_objeto_detectada(objeto)

func _on_area_objeto_detectada(objeto):
	if not es_local:
		return
	
	print("Objeto detectado: ", objeto.name)
	
	if objeto.has_method("ser_recogido"):
		objeto.ser_recogido(self)
		mostrar_efecto_recogida()

func mostrar_efecto_recogida():
	# Efecto visual al recoger objeto
	efecto_recogida.modulate = Color.GREEN
	efecto_recogida.visible = true
	var tween = create_tween()
	tween.tween_property(efecto_recogida, "scale", Vector2(1.5, 1.5), 0.2)
	tween.parallel().tween_property(efecto_recogida, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): efecto_recogida.visible = false; efecto_recogida.scale = Vector2.ONE)

func equipar_arma(tipo_arma: String, municion: int = 0):
	arma_equipada = tipo_arma
	municion_actual = municion
	print(nombre_jugador, " equipó: ", tipo_arma, 
		  (" con " + str(municion) + " munición") if municion > 0 else "")
	actualizar_sprite_arma()

func equipar_escudo():
	tiene_escudo = true
	print(nombre_jugador, " equipó un escudo")
	actualizar_sprite_escudo()

func curar(cantidad: int):
	var vida_anterior = vida_actual
	vida_actual = min(vida_actual + cantidad, vida_maxima)
	var vida_curada = vida_actual - vida_anterior
	vida_cambiada.emit(vida_actual)
	print(nombre_jugador, " se curó ", vida_curada, " puntos. Vida actual: ", vida_actual)

func actualizar_sprite_arma():
	var sprite = get_node_or_null("SpriteJugador")
	if not sprite:
		print("ERROR: SpriteJugador no encontrado")
		return
	
	# Limpiar indicadores anteriores
	limpiar_indicadores_arma()
	
	# Aplicar color según arma
	match arma_equipada:
		"espada":
			sprite.modulate = Color(0.8, 0.8, 1.2)
			crear_indicador_arma("E", Color.CYAN)
		"hacha":
			sprite.modulate = Color(1.2, 0.8, 0.8)
			crear_indicador_arma("H", Color.RED)
		"pistola":
			sprite.modulate = Color(1.1, 1.1, 0.8)
			crear_indicador_arma("P", Color.YELLOW)
		"rifle":
			sprite.modulate = Color(0.8, 1.1, 0.8)
			crear_indicador_arma("R", Color.GREEN)
		"":
			sprite.modulate = Color.WHITE
	
	print("Arma actualizada visualmente: ", arma_equipada)

func crear_indicador_arma(letra: String, color: Color):
	# Crear una etiqueta que muestre qué arma tienes
	var indicador = Label.new()
	indicador.name = "IndicadorArma"
	indicador.text = letra
	indicador.modulate = color
	indicador.position = Vector2(15, -25)  # Arriba a la derecha del jugador
	indicador.add_theme_font_size_override("font_size", 16)
	add_child(indicador)
	
	print("Indicador de arma creado: ", letra)

func limpiar_indicadores_arma():
	var indicador = get_node_or_null("IndicadorArma")
	if indicador:
		indicador.queue_free()

func actualizar_sprite_escudo():
	var sprite = get_node_or_null("SpriteJugador")
	if sprite:
		sprite.modulate = Color(1.2, 1.2, 0.8)  # Dorado
		
		# Crear indicador de escudo
		limpiar_indicadores_escudo()
		var indicador = Label.new()
		indicador.name = "IndicadorEscudo"
		indicador.text = "🛡"  # Emoji de escudo
		indicador.position = Vector2(-25, -25)  # Arriba a la izquierda
		indicador.modulate = Color.GOLD
		add_child(indicador)
		
		print("Escudo equipado con indicador visual")

func limpiar_indicadores_escudo():
	var indicador = get_node_or_null("IndicadorEscudo")
	if indicador:
		indicador.queue_free()

func establecer_foto_cara(textura: Texture2D):
	if textura:
		sprite_jugador.texture = textura
		print("Foto personalizada establecida para ", nombre_jugador)

func establecer_nombre(nuevo_nombre: String):
	nombre_jugador = nuevo_nombre

func _on_vida_cambiada(nueva_vida: int):
	# Actualizar barra de vida local
	barra_vida_local.value = nueva_vida
	
	# Cambiar color según la vida
	if nueva_vida > 70:
		barra_vida_local.modulate = Color.GREEN
	elif nueva_vida > 30:
		barra_vida_local.modulate = Color.YELLOW
	else:
		barra_vida_local.modulate = Color.RED

func obtener_info_estado() -> Dictionary:
	return {
		"id": id_jugador,
		"nombre": nombre_jugador,
		"vida": vida_actual,
		"arma": arma_equipada,
		"municion": municion_actual,
		"escudo": tiene_escudo,
		"vivo": vida_actual > 0
	}
