extends Node
class_name WebSocketClient

var socket = WebSocketPeer.new()
var last_state = WebSocketPeer.STATE_CLOSED

signal connected_to_server()
signal connection_closed()
signal message_received(message: Variant)

func get_socket() -> WebSocketPeer:
	return socket

# Poll for data continuously
func poll() -> void:
	# Always call poll regardless of socket state to ensure it processes data
	socket.poll()
	
	var state = socket.get_ready_state()
	
	# Check for state change
	if last_state != state:
		last_state = state
		
		if state == socket.STATE_OPEN:
			emit_signal("connected_to_server")
		elif state == socket.STATE_CLOSED:
			emit_signal("connection_closed")
	
	# Read all available packets
	while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count() > 0:
		var message = get_message()
		emit_signal("message_received", message)

# Send message
func send(message) -> int:
	if typeof(message) == TYPE_STRING:
		return socket.send_text(message)
	return socket.send(var_to_bytes(message))

# Retrieve message from the WebSocket
func get_message() -> Variant:
	if socket.get_available_packet_count() < 1:
		return null
	
	var packet = socket.get_packet()
	if socket.was_string_packet():
		return packet.get_string_from_utf8()
	return bytes_to_var(packet)

# Connect to WebSocket URL
func connect_to_url(url) -> int:
	var error = socket.connect_to_url(url)
	if error != OK:
		return error
	
	last_state = socket.get_ready_state()
	return OK

# Close the WebSocket connection
func close(code := 1000, reason := "") -> void:
	socket.close(code, reason)
	last_state = socket.get_ready_state()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	poll()  # Polling the WebSocket continuously
