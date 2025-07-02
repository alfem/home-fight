extends Area2D

var tipo_objeto: String = ""
var valor: int = 0
var sprite_objeto = null

var configuraciones_objetos = {
	"espada": {"sprite": "res://recursos/sprites/objetos/espada.png", "valor": 0},
	"hacha": {"sprite": "res://recursos/sprites/objetos/hacha.png", "valor": 0},
	"pistola": {"sprite": "res://recursos/sprites/objetos/pistola.png", "valor": 12},
	"rifle": {"sprite": "res://recursos/sprites/objetos/rifle.png", "valor": 30},
	"escudo": {"sprite": "res://recursos/sprites/objetos/escudo.png", "valor": 0},
	"medicina": {"sprite": "res://recursos/sprites/objetos/medicina.png", "valor": 50}
}

func _ready():
	body_entered.connect(_on_jugador_entro)
	area_entered.connect(_on_area_jugador_entro)
	print("ObjetoRecogible iniciado")

func configurar_tipo(nuevo_tipo: String):
	tipo_objeto = nuevo_tipo
	print("Configurando objeto tipo: ", tipo_objeto)
	
	if tipo_objeto in configuraciones_objetos:
		var config = configuraciones_objetos[tipo_objeto]
		valor = config.valor
		
		# Cargar sprite desde archivo
		cargar_sprite_desde_archivo(config.sprite)
		
		# Crear colisión
		crear_colision_objeto()
		
		print("Objeto ", tipo_objeto, " configurado correctamente")
	else:
		print("ERROR: Tipo de objeto desconocido: ", tipo_objeto)

func cargar_sprite_desde_archivo(ruta_sprite: String):
	print("Intentando cargar sprite: ", ruta_sprite)
	
	# Buscar sprite existente o crear uno nuevo
	sprite_objeto = get_node_or_null("Sprite2D")
	if not sprite_objeto:
		sprite_objeto = Sprite2D.new()
		sprite_objeto.name = "Sprite2D"
		add_child(sprite_objeto)
	
	# Centrar el sprite
	sprite_objeto.position = Vector2.ZERO
	
	# Verificar que el archivo existe
	if ResourceLoader.exists(ruta_sprite):
		sprite_objeto.texture = load(ruta_sprite)
		print("Sprite cargado correctamente: ", ruta_sprite)
	else:
		print("ERROR: No se encontró el archivo: ", ruta_sprite)
		# Crear sprite de fallback (color sólido)
		crear_sprite_fallback()

func crear_sprite_fallback():
	print("Creando sprite de fallback para: ", tipo_objeto)
	
	# Colores de fallback por tipo
	var colores_fallback = {
		"espada": Color.SILVER,
		"hacha": Color.BROWN,
		"pistola": Color.DARK_GRAY,
		"rifle": Color.BLACK,
		"escudo": Color.BLUE,
		"medicina": Color.GREEN
	}
	
	var color = colores_fallback.get(tipo_objeto, Color.WHITE)
	
	# Crear textura simple
	var imagen = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	imagen.fill(color)
	
	var textura = ImageTexture.create_from_image(imagen)
	sprite_objeto.texture = textura
	
	print("Sprite de fallback creado con color: ", color)

func crear_colision_objeto():
	var colision = get_node_or_null("CollisionShape2D")
	if not colision:
		colision = CollisionShape2D.new()
		var forma = RectangleShape2D.new()
		forma.size = Vector2(28, 28)  # Ligeramente más pequeño que el sprite
		colision.shape = forma
		colision.position = Vector2.ZERO
		add_child(colision)
		print("Colisión creada")

func _on_jugador_entro(jugador):
	print("Jugador detectado: ", jugador.name)
	if jugador.has_method("equipar_arma") or jugador.has_method("curar"):
		ser_recogido(jugador)

func _on_area_jugador_entro(area):
	var jugador = area.get_parent()
	if jugador and (jugador.has_method("equipar_arma") or jugador.has_method("curar")):
		ser_recogido(jugador)

func ser_recogido(jugador):
	print("Objeto ", tipo_objeto, " recogido por ", jugador.name)
	
	# Reproducir sonido de recogida
	if GestorAudio and GestorAudio.has_method("reproducir_efecto"):
		GestorAudio.reproducir_efecto("recoger_objeto")
	
	# Aplicar efecto según el tipo
	match tipo_objeto:
		"espada", "hacha":
			if jugador.has_method("equipar_arma"):
				jugador.equipar_arma(tipo_objeto)
		"pistola", "rifle":
			if jugador.has_method("equipar_arma"):
				jugador.equipar_arma(tipo_objeto, valor)
		"escudo":
			if jugador.has_method("equipar_escudo"):
				jugador.equipar_escudo()
		"medicina":
			if jugador.has_method("curar"):
				jugador.curar(valor)
	
	# Notificar al gestor del juego
	if GestorJuego and GestorJuego.has_method("jugador_recoge_objeto"):
		var jugador_id = jugador.id_jugador
		GestorJuego.jugador_recoge_objeto(jugador_id, self)
	
	# Eliminar el objeto
	queue_free()
