extends Node

signal conexion_establecida
signal conexion_fallida
signal jugador_unido(id, info)

const PUERTO_DEFECTO = 7000
const MAX_JUGADORES = 4

var info_jugador = {"nombre": "Jugador", "cara": null}

func crear_servidor(puerto: int = PUERTO_DEFECTO):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(puerto, MAX_JUGADORES)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Servidor creado en puerto ", puerto)
		conexion_establecida.emit()
	else:
		print("Error creando servidor: ", error)
		conexion_fallida.emit()

func unirse_servidor(direccion: String, puerto: int = PUERTO_DEFECTO):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(direccion, puerto)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Intentando conectar a ", direccion, ":", puerto)
	else:
		print("Error conectando: ", error)
		conexion_fallida.emit()

func _ready():
	multiplayer.connected_to_server.connect(_on_conectado_servidor)
	multiplayer.connection_failed.connect(_on_conexion_fallida)
	multiplayer.server_disconnected.connect(_on_servidor_desconectado)

func _on_conectado_servidor():
	print("Conectado al servidor")
	conexion_establecida.emit()

func _on_conexion_fallida():
	print("Falló la conexión")
	conexion_fallida.emit()

func _on_servidor_desconectado():
	print("Servidor desconectado")
	# Volver al menú principal
	get_tree().change_scene_to_file("res://escenas/interfaz/MenuPrincipal.tscn")
