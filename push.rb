require 'rubygems'
require 'rubix'
require 'telegrammer'

#Constantes
TEXTO_PING_EXITO = 'Ping exitoso 😀'
TEXTO_PING_FALLA = 'Ping fallido 😞'
TEXTO_COMANDO_NO = 'No conozco ese comando 😕'
TEXTO_NO_AUTORIZADO = 'Lo siento, no estoy autorizado para responderte.'
TEXTO_BUSQUEDA_VACIA = 'No se encontraron resultados.'
TEXTO_BIENVENIDO = 'Bienvenido, ¿En qué te puedo ayudar?'
TEXTO_NO_ALERTAS = 'No hay alertas activas.'
TEXTO_PREGUNTAR_IP = '¿A cuál dirección IP debo hacer ping?'
TOKEN = '76761933:AAH-pqzGRpWzJffknFlieDxw8lSExSOaLxE'

	#Conecta con Zabbix
Rubix.connect('http://localhost/zabbix/api_jsonrpc.php', 'Admin', 'zabbix')

	#Conecta con Telegram
bot = Telegrammer::Bot.new(TOKEN)

# Markup para esconder teclado personalizado
reply_markup_hide = Telegrammer::DataTypes::ReplyKeyboardHide.new(
	hide_keyboard: true,
	selective: false
)

# Markup para forzar reply a mensaje
reply_markup_force = Telegrammer::DataTypes::ForceReply.new(
	force_reply: true,
	selective: false
)

# Markup para teclado de comandos
reply_markup_commands = Telegrammer::DataTypes::ReplyKeyboardMarkup.new(
	keyboard: [
		["/alertas", "/buscar", "/ping"]
		],
	resize_keyboard: true,
	one_time_keyboard: false,
	selective: false
)

	# Otras variables
kill = false
menus = Array.new

	# Envía el mensaje
puts "Enviando a #{ARGV[0]}, said: #{ARGV[2]}"
bot.send_message(chat_id: ARGV[0].to_i, text: ARGV[2])
