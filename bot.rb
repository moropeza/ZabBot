require 'rubygems'
require 'rubix'
require 'telegrammer'
require 'date'
require 'net/ping/icmp'

#Constantes
MAX_QUERY = 10
ZBX_USR = 'gtelecom'
ZBX_PWD = 'gtelecom'
TEXTO_DELIMITADOR = '--------'
TEXTO_PING_EXITO = 'Ping exitoso 😀'
TEXTO_PING_FALLA = 'Ping fallido 😞'
TEXTO_COMANDO_NO = 'No conozco ese comando 😕'
TEXTO_NO_AUTORIZADO = 'Lo siento, no estoy autorizado para responderte 😶'
TEXTO_BUSQUEDA_VACIA = 'No se encontraron resultados.'
TEXTO_BIENVENIDO = 'Bienvenido, ¿En qué te puedo ayudar?'
TEXTO_NO_ALERTAS = 'No hay alertas activas.'
TEXTO_PREGUNTAR_IP = '¿A cuál dirección IP debo hacer ping?'
TEXTO_PREGUNTAR_BUSCAR = 'Texto a buscar (puede ser parte de un nombre, sitio, tipo de equipo ó dirección IP):'
TEXTO_HOST_INVALIDO = 'Dirección IP o DNS inválido 😕'
TEXTO_HELP = "help - Esta ayuda.\nalertas - Lista las alertas activas.\nbuscar - Lista los hosts que coinciden con el criterio de búsqueda.\nping - Realiza un comando ping y devuelve el resultado."
TOKEN = '76761933:AAH-pqzGRpWzJffknFlieDxw8lSExSOaLxE'
REGEXP_IP = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
#REGEXP_DNS = '^(?![0-9]+$)(?!-)[a-zA-Z0-9-]{,63}(?<!-)$'
REGEXP_DNS = '(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)'

	#Rutina para ping
def up?(host)
	check = Net::Ping::ICMP.new(host)
	check.ping
end

	#Rutina para verificar identidad del usuario
def check_auth(user_id)
	auth = 0	# El usuario no estará autorizado hasta que se compruebe lo contrario
	response = Rubix.connection.request(	# Busca si existe un usario en Zabbix con el userid de Telegram asociado
		'usermedia.get', 
		'filter' => { 'sendto' => user_id },
		'countOutput' => 'true')
	if response.has_data?
	 # Response is a success and "has data" -- it's not empty.
		auth = response.result.to_i
	end 
	auth
end


	#Rutina que realiza ping a un host y envía el resultado a un telegram bot
def ping_to_bot(host, retries, bot, chat, reply)

	retries = 1 if retries == 0	#Al menos 1 intento
	
	if host =~ /#{REGEXP_IP}|#{REGEXP_DNS}/
		(1..retries).to_a.each do	# Realiza el ping tantas veces como fue requerido
			if up?(host)
				bot.send_message(chat_id: chat, text: TEXTO_PING_EXITO, reply_markup: reply)
			else
				bot.send_message(chat_id: chat, text: TEXTO_PING_FALLA, reply_markup: reply)
			end
		end
	else	
		#host no es una dirección IP o un DNS válido
		bot.send_message(chat_id: chat, text: TEXTO_HOST_INVALIDO, reply_markup: reply)
	end
end

	#Rutina que realiza una búsqueda de host con la API de Zabbix y envía el resultado a un telegram bot
def search_to_bot(search, zabbix, bot, chat, reply)
	response = zabbix.connection.request(	# Usa la API de Zabbix para buscar hosts con el criterio indicado
		'host.get',			# en el mensaje
		'output' => [ 'hostid', 'host', 'name' ],
		'selectInventory' => [ 'type', 'location' ],
		'selectInterfaces' => [ 'ip', 'dns', 'main', 'type' ],
		'search' => { 'host' => search, 'name' => search, 'dns' => search, 'ip' => search },
		'searchInventory' => { 'type' => search, 'location' => search },
		'limit' => MAX_QUERY,
		'searchByAny' => 'true'
		)
	case
	when response.has_data?
		# Response is a success and "has data" -- it's not empty.

		case response.result.size
		when 1
			msg = "Se encontró un host:\n"
		when MAX_QUERY
			msg = "Sólo se muestran los primeros " + MAX_QUERY.to_s + " hosts encontrados.\n"
		else
			msg = "Se encontraron " + response.result.size.to_s + " hosts:\n"
		end
		response.result.each_with_index do |result, i|
			k = i+1
			msg += k.to_s + ".- ''" + result['host'] + "'', tipo: ''"
			msg += result['inventory']['type'] + "'', ubicación: ''" + result['inventory']['location'] + "'', IP: "
			result['interfaces'].each do |interface|
				if (interface['main'].to_i == 1) and (interface['type'].to_i == 1)
					msg += "''" + interface['ip'].to_s + "''.\n"
				end
			end
			msg += TEXTO_DELIMITADOR + "\n"
		end
 		bot.send_message(chat_id: chat, text: msg, reply_markup: reply)
	when response.success?
		# Response was successful but doesn't "have data" -- it's empty
		bot.send_message(chat_id: chat, text: TEXTO_BUSQUEDA_VACIA, reply_markup: reply)
	else
		# Response was an error. Uh oh!
		bot.send_message(chat_id: chat, text: response.error_message, reply_markup: reply)
	end		
end

	#Conecta con Zabbix
Rubix.connect('http://localhost/zabbix/api_jsonrpc.php', ZBX_USR, ZBX_PWD)

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
#	selective: true
)

	# Otras variables
kill = false
menus = Array.new

# Ciclo de escucha en Telegram
bot.get_updates do |message|
	#puts "In chat #{message.chat.id}, @#{message.from.username} said: #{message.text}"
	
	#Sale
	if kill
		break
	end

	#Verifica identidad del usuario
	if not check_auth(message.chat.id)
		bot.send_message(chat_id: message.chat.id, text: TEXTO_NO_AUTORIZADO)
 		next	# No continúa procesando el comando recibido si el usuario no está autorizado
	end

	case message.text	# Interpreta mensaje recibido
 	when /start/i
		#------------- Comando /start ------------------#		

		bot.send_message(chat_id: message.chat.id, text: TEXTO_BIENVENIDO, reply_markup: reply_markup_commands)

 	when /help/i
		#------------- Comando /help ------------------#		

		bot.send_message(chat_id: message.chat.id, text: TEXTO_HELP, reply_markup: reply_markup_commands)

	when /alertas/i
		#------------- Comando /alertas ------------------#

		response = Rubix.connection.request(	# Usa la API de Zabbix para buscar los triggers habilitados, válidos y en estado de alerta
			'trigger.get', 
			'filter' => { 'value' => 1, 'status' => 0, 'state' => '0' },
			'output' => [ 'triggerid', 'description', 'priority', 'lastchange' ],
			'selectHosts' => [ 'host' ],
			'expandDescription' => 'true',
			'sortfield' => 'priority',
			'limit' => MAX_QUERY,
			'active' => 'true',
			'sortorder' => 'DESC')
		case
		when response.has_data?
			# Response is a success and "has data" -- it's not empty.

			case response.result.size
			when 1
				msg = "Hay una alerta activa:\n"
			when MAX_QUERY
				msg = "Sólo se muestran las primeras " + MAX_QUERY.to_s + " alertas activas.\n"
			else
				msg = "Hay " + response.result.size.to_s + " alertas activas:\n"
			end
			response.result.each_with_index.map do |result, i|
				k = i+1
				msg += k.to_s + ".- ''" + result['description']
				msg += "'', en ''" + result["hosts"][0]["host"]
				msg += "'', desde el " + Time.at(result['lastchange'].to_i).strftime("%-d-%-m-%Y a las %H:%M") + ".\n"
				msg += TEXTO_DELIMITADOR + "\n"
			end
			bot.send_message(chat_id: message.chat.id, text: msg, reply_markup: reply_markup_commands)
		when response.success?
			# Response was successful but doesn't "have data" -- it's empty
			bot.send_message(chat_id: message.chat.id, text: TEXTO_NO_ALERTAS)
		else
			# Response was an error. Uh oh!
			bot.send_message(chat_id: message.chat.id, text: response.error_message, reply_markup: reply_markup_commands)
		end

	when /buscar/i
		#------------- Comando /buscar ------------------#

		#Verifica si el usuario envió el texto a buscar
		search = message.text.split
		if search.size > 1
			search_to_bot(search[1], Rubix, bot, message.chat.id, reply_markup_commands)
		else
			bot.send_message(chat_id: message.chat.id, text: TEXTO_PREGUNTAR_BUSCAR, reply_markup: reply_markup_hide)
		end

	when /kill/i
		#------------- Comando /kill ------------------#

		bot.send_message(chat_id: message.chat.id, text: "Hasta logo!", reply_markup: reply_markup_hide)
		kill = true

	when /ping/i
		#------------- Comando /ping ------------------#

		#Verifica si el usuario envió el host a hacer ping
		host = message.text.split
		if host.size > 1
			ping_to_bot(host[1], host[2].to_i, bot, message.chat.id, reply_markup_commands)
		else
			bot.send_message(chat_id: message.chat.id, text: TEXTO_PREGUNTAR_IP, reply_markup: reply_markup_hide)
		end

	else
		#------------- No se recibió un comando válido, pero puede ser información útil ------------------#

		case menus[message.chat.id]	# El mensaje recibido se procesa de acuerdo al último comando válido
		when /ping/i
			host = message.text.split
			ping_to_bot(host[0], host[1].to_i, bot, message.chat.id, reply_markup_commands)
		when /buscar/i
			search = message.text.split
			search_to_bot(search[0], Rubix, bot, message.chat.id, reply_markup_commands)
		else
			# En definitiva el mensaje recibido no es válido
			bot.send_message(chat_id: message.chat.id, text: TEXTO_COMANDO_NO, reply_markup: reply_markup_commands)
		end
	end

		#Guarda el último comando solicitado por el usuario
	if not message.text.nil?
		menus[message.chat.id.abs] = message.text.split[0]
	end
end
