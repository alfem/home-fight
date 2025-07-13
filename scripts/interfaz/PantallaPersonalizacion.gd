extends Control

@onready var campo_nombre = $VBoxContainer/HBoxNombre/CampoNombre
@onready var boton_cargar_foto = $VBoxContainer/BotonCargarFoto
@onready var vista_previa_foto = $VBoxContainer/VistaPreviaFoto
@onready var boton_guardar = $VBoxContainer/BotonGuardar
@onready var boton_volver = $VBoxContainer/BotonVolver

var foto_jugador: ImageTexture

func _ready():
	# Cargar datos guardados
	cargar_personalizacion()
	
	# Conectar botones
	boton_cargar_foto.pressed.connect(_on_boton_cargar_foto_pressed)
	boton_guardar.pressed.connect(_on_boton_guardar_pressed)
	boton_volver.pressed.connect(_on_boton_volver_pressed)

func cargar_personalizacion():
	# Cargar configuración guardada del jugador
	campo_nombre.text = GlobalData.nombre_jugador
	if GlobalData.foto_jugador:
		vista_previa_foto.texture = GlobalData.foto_jugador
		foto_jugador = GlobalData.foto_jugador

func _on_boton_cargar_foto_pressed():
	GestorAudio.reproducir_efecto("click_boton")
	# Aquí implementarías un diálogo para cargar archivos
	var dialogo = FileDialog.new()
	dialogo.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialogo.access = FileDialog.ACCESS_FILESYSTEM
	dialogo.add_filter("*.png", "Imágenes PNG")
	dialogo.add_filter("*.jpg", "Imágenes JPG")
	dialogo.file_selected.connect(_on_foto_seleccionada)
	add_child(dialogo)
	dialogo.popup_centered(Vector2i(800, 600))

func _on_foto_seleccionada(ruta: String):
	var imagen = Image.new()
	var error = imagen.load(ruta)
	
	if error == OK:
		# Redimensionar imagen para que sea cuadrada y pequeña
		imagen.resize(64, 64)
		foto_jugador = ImageTexture.new()
		foto_jugador.create_from_image(imagen)
		vista_previa_foto.texture = foto_jugador

func _on_boton_guardar_pressed():
	GestorAudio.reproducir_efecto("click_boton")
	
	# Guardar configuración
	GlobalData.nombre_jugador = campo_nombre.text
	if foto_jugador:
		GlobalData.foto_jugador = foto_jugador
	
	# Mostrar confirmación
	var etiqueta_confirmacion = Label.new()
	etiqueta_confirmacion.text = "¡Configuración guardada!"
	etiqueta_confirmacion.modulate = Color.GREEN
	$VBoxContainer.add_child(etiqueta_confirmacion)
	
	# Eliminar mensaje después de 2 segundos
	await get_tree().create_timer(2.0).timeout
	if etiqueta_confirmacion:
		etiqueta_confirmacion.queue_free()

func _on_boton_volver_pressed():
	GestorAudio.reproducir_efecto("click_boton")
	get_tree().change_scene_to_file("res://escenas/interfaz/MenuPrincipal.tscn")
