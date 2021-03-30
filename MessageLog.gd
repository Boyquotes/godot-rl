extends Label

var messages = []
var max_messages = 3

func _on_ready():
	# clear
	self.text = ""

func add_message(text):
	messages.append(text)
	if messages.size() > max_messages:
		messages.remove(0)
	
	# clear
	self.text = ""
	# print out messages from array
	for t in range (0, messages.size()):
		self.text += "> " + messages[t]
		# newline unless lowest message
		if t < (messages.size() - 1):
			self.text += "\n"

# TODO: clear old messages after a while
