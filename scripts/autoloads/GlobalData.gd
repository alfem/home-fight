extends Node

var nombre_jugador: String = "Jugador"
var foto_jugador: ImageTexture
var modo_conexion: String = "servidor"  # "servidor" o "cliente"

func _ready():
	# Cargar datos guardados si existen
	cargar_configuracion()

func cargar_configuracion():
	# Aquí podrías cargar desde un archivo de configuración
	# Por simplicidad, usamos valores por defecto
	pass

func guardar_configuracion():
	# Aquí podrías guardar en un archivo de configuración
	pass