extends Node2D
#class_name Laberinto

@export var tamano_celda = 64
@export var ancho_laberinto = 25
@export var alto_laberinto = 19
@export var seed_laberinto = 12345

var mapa_laberinto = []
var posiciones_spawn = []
var posiciones_libres = []
var paredes_instanciadas = []

# Nodos hijos
@onready var contenedor_paredes = $ContenedorParedes
@onready var contenedor_suelo = $ContenedorSuelo
@onready var puntos_spawn = $PuntosSpawn
@onready var zonas_objetos = $ZonasObjetos

func _ready():
	print("=== LABERINTO INICIADO ===")
	print("Dimensiones: ", ancho_laberinto, "x", alto_laberinto)
	print("Tamaño celda: ", tamano_celda)
	print("Contenedor suelo: ", contenedor_suelo)

	
	# Establecer semilla para generar siempre el mismo laberinto
	seed(seed_laberinto)
	
	generar_laberinto_mejorado()
	crear_sprites_laberinto()
	encontrar_posiciones_spawn()
	encontrar_posiciones_libres()
	crear_indicadores_spawn()

func generar_laberinto_mejorado():
	# Inicializar matriz
	mapa_laberinto = []
	for y in range(alto_laberinto):
		var fila = []
		for x in range(ancho_laberinto):
			fila.append(0)  # Todo empieza libre
		mapa_laberinto.append(fila)
	
	# Crear bordes exteriores
	crear_bordes()
	
	# Crear estructura interna del laberinto
	crear_estructura_interna()
	
	# Asegurar que hay caminos entre las esquinas
	crear_caminos_principales()
	
	# Añadir paredes decorativas
	añadir_paredes_decorativas()

func crear_bordes():
	# Bordes superior e inferior
	for x in range(ancho_laberinto):
		mapa_laberinto[0][x] = 1
		mapa_laberinto[alto_laberinto - 1][x] = 1
	
	# Bordes izquierdo y derecho
	for y in range(alto_laberinto):
		mapa_laberinto[y][0] = 1
		mapa_laberinto[y][ancho_laberinto - 1] = 1

func crear_estructura_interna():
	# Crear habitaciones y pasillos
	crear_habitaciones_centrales()
	crear_pasillos_principales()
	crear_obstaculos_aleatorios()

func crear_obstaculos_aleatorios():
	# TO-DO
	pass

func crear_habitaciones_centrales():
	# Habitación central grande
	var centro_x = ancho_laberinto / 2
	var centro_y = alto_laberinto / 2
	
	for y in range(centro_y - 2, centro_y + 3):
		for x in range(centro_x - 3, centro_x + 4):
			if x > 0 and x < ancho_laberinto - 1 and y > 0 and y < alto_laberinto - 1:
				mapa_laberinto[y][x] = 0
	
	# Habitaciones en las esquinas (más pequeñas)
	crear_habitacion_esquina(2, 2, 3, 3)  # Superior izquierda
	crear_habitacion_esquina(ancho_laberinto - 5, 2, 3, 3)  # Superior derecha
	crear_habitacion_esquina(2, alto_laberinto - 5, 3, 3)  # Inferior izquierda
	crear_habitacion_esquina(ancho_laberinto - 5, alto_laberinto - 5, 3, 3)  # Inferior derecha

func crear_habitacion_esquina(inicio_x: int, inicio_y: int, ancho: int, alto: int):
	for y in range(inicio_y, inicio_y + alto):
		for x in range(inicio_x, inicio_x + ancho):
			if x > 0 and x < ancho_laberinto - 1 and y > 0 and y < alto_laberinto - 1:
				mapa_laberinto[y][x] = 0

func crear_pasillos_principales():
	var centro_x = ancho_laberinto / 2
	var centro_y = alto_laberinto / 2
	
	# Pasillo horizontal central
	for x in range(1, ancho_laberinto - 1):
		mapa_laberinto[centro_y][x] = 0
		# Hacer el pasillo más ancho
		if centro_y > 1:
			mapa_laberinto[centro_y - 1][x] = 0
		if centro_y < alto_laberinto - 2:
			mapa_laberinto[centro_y + 1][x] = 0
	
	# Pasillo vertical central
	for y in range(1, alto_laberinto - 1):
		mapa_laberinto[y][centro_x] = 0
		# Hacer el pasillo más ancho
		if centro_x > 1:
			mapa_laberinto[y][centro_x - 1] = 0
		if centro_x < ancho_laberinto - 2:
			mapa_laberinto[y][centro_x + 1] = 0

func crear_caminos_principales():
	# Conectar esquinas con el centro
	crear_camino_diagonal(3, 3, ancho_laberinto / 2, alto_laberinto / 2)
	crear_camino_diagonal(ancho_laberinto - 4, 3, ancho_laberinto / 2, alto_laberinto / 2)
	crear_camino_diagonal(3, alto_laberinto - 4, ancho_laberinto / 2, alto_laberinto / 2)
	crear_camino_diagonal(ancho_laberinto - 4, alto_laberinto - 4, ancho_laberinto / 2, alto_laberinto / 2)

func crear_camino_diagonal(desde_x: int, desde_y: int, hasta_x: int, hasta_y: int):
	var x = desde_x
	var y = desde_y
	
	while x != hasta_x or y != hasta_y:
		mapa_laberinto[y][x] = 0
		
		if x < hasta_x:
			x += 1
		elif x > hasta_x:
			x -= 1
		
		if y < hasta_y:
			y += 1
		elif y > hasta_y:
			y -= 1

func añadir_paredes_decorativas():
	# Añadir algunas paredes internas para hacer el laberinto más interesante
	for i in range(15):  # 15 grupos de paredes aleatorias
		var x = randi_range(3, ancho_laberinto - 4)
		var y = randi_range(3, alto_laberinto - 4)
		
		# Solo añadir pared si no bloquea completamente el paso
		if puede_añadir_pared(x, y):
			mapa_laberinto[y][x] = 1
			
			# Añadir algunas paredes adyacentes
			if randf() < 0.5:
				if puede_añadir_pared(x + 1, y):
					mapa_laberinto[y][x + 1] = 1
			if randf() < 0.5:
				if puede_añadir_pared(x, y + 1):
					mapa_laberinto[y + 1][x] = 1

func puede_añadir_pared(x: int, y: int) -> bool:
	# Verificar que no bloquee completamente el paso
	if x <= 1 or x >= ancho_laberinto - 2 or y <= 1 or y >= alto_laberinto - 2:
		return false
	
	# No añadir en pasillos principales
	var centro_x = ancho_laberinto / 2
	var centro_y = alto_laberinto / 2
	
	if abs(x - centro_x) <= 2 and abs(y - centro_y) <= 2:
		return false
	
	return true

func crear_sprites_laberinto():
	# Crear sprites para el suelo
	crear_suelo_completo()
	
	# Crear sprites para las paredes
	for y in range(alto_laberinto):
		for x in range(ancho_laberinto):
			if mapa_laberinto[y][x] == 1:
				crear_pared(x, y)

func crear_suelo_completo():
	for y in range(alto_laberinto):
		for x in range(ancho_laberinto):
			crear_tile_suelo(x, y)

func crear_tile_suelo(x: int, y: int):
	
	var tile_suelo = Sprite2D.new()
	tile_suelo.name = "Suelo_" + str(x) + "_" + str(y)
	tile_suelo.position = Vector2(x * tamano_celda + tamano_celda/2, y * tamano_celda + tamano_celda/2)
	
	# Crear textura temporal para el suelo
	var imagen = Image.create(tamano_celda, tamano_celda, false, Image.FORMAT_RGBA8)
	
	# Patrón de damero sutil para el suelo
	var color_base = Color(0.3, 0.3, 0.35)  # Gris azulado
	var color_alt = Color(0.28, 0.28, 0.33)  # Ligeramente más oscuro
	
	var color_final = color_base if (x + y) % 2 == 0 else color_alt
	imagen.fill(color_final)
	
	var textura = ImageTexture.create_from_image(imagen)
	tile_suelo.texture = textura
	
	contenedor_suelo.add_child(tile_suelo)

func crear_pared(x: int, y: int):
	var pared = StaticBody2D.new()
	var sprite = Sprite2D.new()
	var colision = CollisionShape2D.new()
	var forma = RectangleShape2D.new()
	
	# Configurar forma de colisión
	forma.size = Vector2(tamano_celda, tamano_celda)
	colision.shape = forma
	
	# CRÍTICO: Configurar capas de colisión correctamente
	pared.collision_layer = 1     # Está en capa "paredes" (bit 1)
	pared.collision_mask = 0      # No necesita detectar nada
	
	# NO centrar los hijos, centrar el padre
	colision.position = Vector2.ZERO
	sprite.position = Vector2.ZERO
	
	# Configurar sprite
	sprite.modulate = Color(0.4, 0.4, 0.5)
	
	# Crear textura simple
	var imagen = Image.create(tamano_celda, tamano_celda, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(0.4, 0.4, 0.5))
	var textura = ImageTexture.create_from_image(imagen)
	sprite.texture = textura
	
	# Configurar pared - CENTRAR AQUÍ
	pared.name = "Pared_" + str(x) + "_" + str(y)
	pared.position = Vector2(x * tamano_celda + tamano_celda/2, y * tamano_celda + tamano_celda/2)
	
	# Ensamblar nodos
	pared.add_child(sprite)
	pared.add_child(colision)
	contenedor_paredes.add_child(pared)
	
	paredes_instanciadas.append(pared)
	
	#print("Pared creada en (", x, ",", y, ") con collision_layer=", pared.collision_layer)

func determinar_color_pared(x: int, y: int) -> Color:
	# Paredes exteriores más oscuras
	if x == 0 or x == ancho_laberinto - 1 or y == 0 or y == alto_laberinto - 1:
		return Color(0.2, 0.2, 0.25)  # Gris muy oscuro
	
	# Paredes internas
	return Color(0.4, 0.4, 0.5)  # Gris medio

func encontrar_posiciones_spawn():
	posiciones_spawn.clear()
	
	# Definir posiciones de spawn en las esquinas de las habitaciones
	var candidatos = [
		Vector2(3, 3),  # Superior izquierda
		Vector2(ancho_laberinto - 4, 3),  # Superior derecha
		Vector2(3, alto_laberinto - 4),  # Inferior izquierda
		Vector2(ancho_laberinto - 4, alto_laberinto - 4)  # Inferior derecha
	]
	
	for pos in candidatos:
		if es_posicion_libre(pos * tamano_celda):
			posiciones_spawn.append(pos * tamano_celda + Vector2(tamano_celda/2, tamano_celda/2))

func encontrar_posiciones_libres():
	posiciones_libres.clear()
	for y in range(1, alto_laberinto - 1):
		for x in range(1, ancho_laberinto - 1):
			if mapa_laberinto[y][x] == 0:
				# No incluir posiciones de spawn
				var pos_mundial = Vector2(x * tamano_celda + tamano_celda/2, y * tamano_celda + tamano_celda/2)
				var es_spawn = false
				for spawn_pos in posiciones_spawn:
					if pos_mundial.distance_to(spawn_pos) < tamano_celda:
						es_spawn = true
						break
				
				if not es_spawn:
					posiciones_libres.append(pos_mundial)

func crear_indicadores_spawn():
	# Crear indicadores visuales para las posiciones de spawn
	for i in range(posiciones_spawn.size()):
		var indicador = Sprite2D.new()
		indicador.name = "SpawnPoint_" + str(i)
		indicador.position = posiciones_spawn[i]
		
		# Crear textura circular para el spawn point
		var imagen = Image.create(tamano_celda, tamano_celda, false, Image.FORMAT_RGBA8)
		imagen.fill(Color.TRANSPARENT)
		
		# Dibujar círculo
		var centro = tamano_celda / 2
		var radio = tamano_celda / 4
		
		for y in range(tamano_celda):
			for x in range(tamano_celda):
				var distancia = Vector2(x - centro, y - centro).length()
				if distancia <= radio:
					var alpha = 1.0 - (distancia / radio) * 0.5
					imagen.set_pixel(x, y, Color(0.2, 0.8, 0.2, alpha))
		
		var textura = ImageTexture.create_from_image(imagen)
		indicador.texture = textura
		
		puntos_spawn.add_child(indicador)

func obtener_posicion_spawn(indice: int) -> Vector2:
	if indice < posiciones_spawn.size():
		return posiciones_spawn[indice]
	
	# Si no hay suficientes spawns, usar el centro
	return Vector2(ancho_laberinto * tamano_celda / 2, alto_laberinto * tamano_celda / 2)

func obtener_posicion_libre_aleatoria() -> Vector2:
	if posiciones_libres.size() > 0:
		return posiciones_libres[randi() % posiciones_libres.size()]
	
	# Fallback: devolver el centro
	return Vector2(ancho_laberinto * tamano_celda / 2, alto_laberinto * tamano_celda / 2)

func es_posicion_libre(pos: Vector2) -> bool:
	var celda_x = int(pos.x / tamano_celda)
	var celda_y = int(pos.y / tamano_celda)
	
	if celda_x < 0 or celda_x >= ancho_laberinto or celda_y < 0 or celda_y >= alto_laberinto:
		return false
	
	return mapa_laberinto[celda_y][celda_x] == 0

func obtener_dimensiones_mundo() -> Vector2:
	return Vector2(ancho_laberinto * tamano_celda, alto_laberinto * tamano_celda)

func obtener_centro_mundo() -> Vector2:
	return obtener_dimensiones_mundo() / 2

# Función para debugging - mostrar el mapa en consola
func debug_imprimir_mapa():
	print("=== MAPA DEL LABERINTO ===")
	for y in range(alto_laberinto):
		var linea = ""
		for x in range(ancho_laberinto):
			if mapa_laberinto[y][x] == 1:
				linea += "█"
			else:
				linea += " "
		print(linea)
	print("=========================")
