extends Node

@onready var reproductor_musica = AudioStreamPlayer.new()
@onready var reproductor_efectos = AudioStreamPlayer.new()

var musicas = {}
var efectos_sonido = {}
var volumen_musica = 0.7
var volumen_efectos = 0.8

func _ready():
	# Configurar reproductores de audio
	add_child(reproductor_musica)
	add_child(reproductor_efectos)
	
	reproductor_musica.volume_db = linear_to_db(volumen_musica)
	reproductor_efectos.volume_db = linear_to_db(volumen_efectos)
	
	cargar_recursos_audio()

func cargar_recursos_audio():
	# Cargar música (comentado hasta que tengas los archivos)
	musicas["menu"] = preload("res://recursos/sonidos/musica/musica_menu.ogg")
	
	# Cargar efectos de sonido (comentado hasta que tengas los archivos)
	#efectos_sonido["disparo_pistola"] = preload("res://recursos/sonidos/efectos/disparo_pistola.ogg")
	#efectos_sonido["disparo_rifle"] = preload("res://recursos/sonidos/efectos/disparo_rifle.ogg")
	efectos_sonido["golpe_espada"] = preload("res://recursos/sonidos/efectos/golpe_espada.ogg")
	efectos_sonido["recoger_objeto"] = preload("res://recursos/sonidos/efectos/recoger_objeto.ogg")
	#efectos_sonido["muerte_jugador"] = preload("res://recursos/sonidos/efectos/muerte_jugador.ogg")
	efectos_sonido["click_boton"] = preload("res://recursos/sonidos/efectos/click_boton.ogg")
	
	print("Sistema de audio inicializado")

func reproducir_musica(nombre_musica: String, loop: bool = true):
	if nombre_musica in musicas:
		reproductor_musica.stream = musicas[nombre_musica]
		reproductor_musica.play()
	else:
		print("Música no encontrada: ", nombre_musica)

func detener_musica():
	reproductor_musica.stop()

func reproducir_efecto(nombre_efecto: String):
	if nombre_efecto in efectos_sonido:
		reproductor_efectos.stream = efectos_sonido[nombre_efecto]
		reproductor_efectos.play()
	else:
		print("Efecto de sonido no encontrado: ", nombre_efecto)

func establecer_volumen_musica(volumen: float):
	volumen_musica = clamp(volumen, 0.0, 1.0)
	reproductor_musica.volume_db = linear_to_db(volumen_musica)

func establecer_volumen_efectos(volumen: float):
	volumen_efectos = clamp(volumen, 0.0, 1.0)
	reproductor_efectos.volume_db = linear_to_db(volumen_efectos)
