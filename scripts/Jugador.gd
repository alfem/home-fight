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
var ultimo_atacante_id: int = -1  # Guardar el ID del último atacante
var indice_jugador: int = 0  # NUEVO: Índice del jugador para determinar color

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
	
	# Configurar colores únicos por jugador
	configurar_apariencia_inicial()
	
	# Solo el jugador local procesa input
	set_physics_process(es_local)
	
	# Añadir al grupo de jugadores
	add_to_group("jugadores")
	
	# Inicializar vida
	vida_actual = vida_maxima
	
	print("Jugador ", id_jugador, " listo. Local: ", es_local)

func configurar_apariencia_inicial():
	# Crear sprite con color único por jugador
	var colores_jugadores = [
		Color.BLUE,      # Jugador 0 (servidor)
		Color.RED,       # Jugador 1 (primer cliente)
		Color.GREEN,     # Jugador 2 (segundo cliente)
		Color.ORANGE     # Jugador 3 (tercer cliente)
	]
	
	# Usar el índice del jugador directamente
	var indice_color = indice_jugador % colores_jugadores.size()
	var color_jugador = colores_jugadores[indice_color]
	
	var sprite = get_node_or_null("SpriteJugador")
	
	if sprite and sprite.texture:
			sprite.modulate = color_jugador
			print("Color aplicado al sprite existente: ", color_jugador)
	elif sprite:
			# Si no tiene textura, crear una redonda
			crear_textura_redonda(sprite, color_jugador)
	else:
			print("ERROR: SpriteJugador no encontrado")
	
	print("Jugador ", id_jugador, " configurado con color: ", color_jugador, " (índice: ", indice_jugador, ")")
	
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
		print("¡Botón de ataque presionado!")
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
	# Mostrar indicador de alcance temporalmente
	mostrar_indicador_ataque()
	
	var objetivo = buscar_objetivo_cercano()
	if objetivo:
		var dano = calcular_dano()
		
		# Reproducir sonido de ataque
		if GestorJuego and GestorJuego.has_method("reproducir_sonido_ataque"):
			GestorJuego.reproducir_sonido_ataque(arma_equipada)
		
		if es_ataque_a_distancia():
			if municion_actual > 0:
				municion_actual -= 1
				objetivo.recibir_dano.rpc(dano, id_jugador)
				mostrar_efecto_ataque()
			else:
				print("Sin munición!")
		else:
			objetivo.recibir_dano.rpc(dano, id_jugador)
			mostrar_efecto_ataque()
	else:
		print("No hay objetivos en rango")

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
	var jugadores = get_tree().get_nodes_in_group("jugadores")
	var distancia_ataque = 100.0 if es_ataque_a_distancia() else 60.0
	
	for jugador in jugadores:
		if jugador != self and jugador.vida_actual > 0:
			if position.distance_to(jugador.position) <= distancia_ataque:
				return jugador
	return null

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
func recibir_dano(cantidad: int, atacante_id: int):
	if tiene_escudo and randf() < 0.3:  # 30% de bloqueo con escudo
		print("¡Ataque bloqueado por ", nombre_jugador, "!")
		return
	
	# Guardar el ID del atacante
	ultimo_atacante_id = atacante_id
	
	vida_actual -= cantidad
	vida_cambiada.emit(vida_actual)
	
	# Efecto visual de daño
	mostrar_efecto_dano()
	
	print(nombre_jugador, " recibió ", cantidad, " de daño de jugador ", atacante_id, ". Vida restante: ", vida_actual)
	
	if vida_actual <= 0:
		morir()

func mostrar_efecto_dano():
	# Efecto de parpadeo rojo al recibir daño
	var tween = create_tween()
	tween.tween_property(sprite_jugador, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite_jugador, "modulate", Color.WHITE, 0.1)

func morir():
	print(nombre_jugador, " ha muerto!")
	print("Último atacante: ", ultimo_atacante_id)
	jugador_muerto.emit()
	
	# IMPORTANTE: Pasar el ID del atacante al GestorJuego
	if GestorJuego and GestorJuego.has_method("notificar_muerte_jugador"):
		GestorJuego.notificar_muerte_jugador(id_jugador, ultimo_atacante_id)
	
	# Efectos visuales de muerte
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
#TO-DO	etiqueta_nombre.text = nombre_jugador

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
