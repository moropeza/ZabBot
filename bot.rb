require 'rubygems'
require 'rubix'
require 'telegrammer'
require 'date'
#require 'zbxapi'

	#Conecta con zabbix
Rubix.connect('http://localhost/zabbix/api_jsonrpc.php', 'Admin', 'zabbix')

bot = Telegrammer.new('114658418:AAF4NGifwHTpIRuF9EjxmCO6IXwjqhqMo3I')

# https://core.telegram.org/bots/api/#replykeyboardhide
reply_markup_hide = Telegrammer::DataTypes::ReplyKeyboardHide.new(
  hide_keyboard: true
)

# GET UPDATES
# https://core.telegram.org/bots/api/#getupdates
bot.get_updates do |message|
  puts "In chat #{message.chat.id}, @#{message.from.username} said: #{message.text}"

  case message.text
   when /start/i
    
   # https://core.telegram.org/bots/api/#replykeyboardmarkup
   reply_markup = Telegrammer::DataTypes::ReplyKeyboardMarkup.new(
     keyboard: [
       ["Option 1.1", "Option 1.2"],
       ["Option 2"],
       ["Option 3.1", "Option 3.2", "Option 3.3"]
     ],
     resize_keyboard: true,
     one_time_keyboard: true,
     selective: false
   )

   # This message will activate a custom keyboard...
   bot.send_message(
     chat_id: message.chat.id,
     text: "Select an option",
     reply_markup: reply_markup
   )
  when /alertas/i	#Comando Alertas
   response = Rubix.connection.request(
	'trigger.get', 
	'filter' => { 'value' => 1 },
	'output' => [ 'triggerid', 'description', 'priority', 'lastchange' ],
	'selectHosts' => [ 'host' ],
	'expandDescription' => 'true',
	'sortfield' => 'priority',
	'sortorder' => 'DESC')

   case
    when response.has_data?
     # Response is a success and "has data" -- it's not empty.  This
     # means we found our host.

    msg  = "Hay " + response.result.size.to_s + " alerta(s) activa(s):\n"
    response.result.each_with_index.map do |result, i|
	k = i+1
	msg += k.to_s + ".- ''" + result['description']
	msg += "'', en ''" + result["hosts"][0]["host"]
	msg += "'', desde el " + Time.at(result['lastchange'].to_i).strftime("%-d-%-m-%Y a las %H:%M") + ".\n"
    end
    bot.send_message(chat_id: message.chat.id, text: msg, reply_markup: reply_markup_hide)
   when response.success?
     # Response was successful but doesn't "have data" -- it's empty, no
     # such host!
    bot.send_message(chat_id: message.chat.id, text: 'No hay alertas activas', reply_markup: reply_markup_hide)
   else
     # Response was an error.  Uh oh!
    bot.send_message(chat_id: message.chat.id, text: response.error_message, reply_markup: reply_markup_hide)
   end

  when /buscar/i	#Comando Buscar
   search = message.text.split

  # if search.size == 1
  #  bot.send_message(chat_id: message.chat.id, text: 'Introduzca texto a buscar', reply_markup: reply_markup_hide)
    #break
  # end

   response = Rubix.connection.request(
	'host.get',
	'output' => [ 'hostid', 'host', 'name' ],
	'selectInventory' => [ 'type', 'location' ],
	'selectInterfaces' => [ 'ip', 'dns', 'main' ],
	'search' => { 'host' => search[1], 'name' => search[1], 'dns' => search[1], 'ip' => search[1] },
        'searchInventory' => { 'type' => search[1], 'location' => search[1] },
	'searchByAny' => 'true'
        )

   case
    when response.has_data?
     # Response is a success and "has data" -- it's not empty.  This
     # means we found our host.

    msg  = "Se encontraron " + response.result.size.to_s + " host(s):\n"
    response.result.each_with_index.map do |result, i|
	k = i+1
	msg += k.to_s + ".- ''" + result['host'] + "'', tipo: ''"
	msg += result['inventory']['type'] + "'', ubicación: ''" + result['inventory']['location'] + "'', IP(s): "
	result['interfaces'].each do |interface|
	  msg += "''" + interface['ip'].to_s + "''"
	end
	msg += ".\n"
    end
    bot.send_message(chat_id: message.chat.id, text: msg, reply_markup: reply_markup_hide)
   when response.success?
     # Response was successful but doesn't "have data" -- it's empty, no
     # such host!
    bot.send_message(chat_id: message.chat.id, text: 'No se encontraron resultados', reply_markup: reply_markup_hide)
   else
     # Response was an error.  Uh oh!
    bot.send_message(chat_id: message.chat.id, text: response.error_message, reply_markup: reply_markup_hide)
   end



  else
   bot.send_message(chat_id: message.chat.id, text: "Comando '#{message.text}' no reconocido", reply_markup: reply_markup_hide)
  end
end
