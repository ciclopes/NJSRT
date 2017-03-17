#define VERSION 0.1.0-alpha

fs = require 'fs'
execSync = require('child_process').execSync

USAGE_MSG = "\nUsage: coffee redis_setup.coffee <number_of_masters> <number_of_slaves_per_master> [--cleanall] [--save <time_in_secs> <min_num_of_changes> [--save ...]... ] [--port <port>] [--min-slaves-to-write <min_slaves_to_write>] [--max-slaves-room <max_number_of_slaves_per_master>]\n"
MASTER_SLAVE_MUST_BE_NUMBERS_MSG = "\n\n<number_of_masters> and <number_of_slaves_per_master> must be numbers."
WRONG_NUM_OF_SAVE_MSG = "\n\nWrong number of arguments for --save parameter."
WRONG_NUM_OF_PORT_MSG = "\n\nWrong number of arguments for --port parameter."
WRONG_NUM_OF_MIN_SLAVES_MSG = "\n\nWrong number of arguments for --min-slaves-to-write parameter."
WRONG_NUM_OF_MAX_SLAVES_MSG = "\n\nWrong number of arguments for --max-slaves-room parameter."
SAVE_PARAMS_MUST_BE_NUMBERS_MSG = "\n\nThe arguments of --save parameter must be numbers."
PORT_PARAM_MUST_BE_NUMBER_MSG = "\n\nThe argument of --port parameter must be a number."
MIN_SLAVES_PARAM_MUST_BE_NUMBER_MSG = "\n\nThe argument of --min-slaves-to-write parameter must be a number."
MAX_SLAVES_PARAM_MUST_BE_NUMBER_MSG = "\n\nThe argument of --max-slaves-room parameter must be a number."

if process.argv.length is 2
  console.log USAGE_MSG
  return

args = Array::slice.call process.argv
args.shift()
args.shift()

num_masters = +args.shift()
num_slaves_per_master = +args.shift()

if isNaN(num_masters) or isNaN(num_slaves_per_master)
  console.log MASTER_SLAVE_MUST_BE_NUMBERS_MSG
  console.log USAGE_MSG
  return

saves = []
start_port = 6379
masters_room = 356
min_slaves = 1
max_slaves = 4

getSaveParam = ->
  if args.length < 2
    console.log WRONG_NUM_OF_SAVE_MSG
    console.log USAGE_MSG
    return false

  arg1 = +args.shift()
  arg2 = +args.shift()

  if isNaN(arg1) or isNaN(arg2)
    console.log SAVE_PARAMS_MUST_BE_NUMBERS_MSG
    console.log USAGE_MSG
    return false

  saves.push time: arg1, changes: arg2
  return true

getStartPortParam = ->
  if args.length < 1
    console.log WRONG_NUM_OF_PORT_MSG
    console.log USAGE_MSG
    return false

  arg1 = +args.shift()

  if isNaN arg1
    console.log PORT_PARAM_MUST_BE_NUMBER_MSG
    console.log USAGE_MSG
    return false

  start_port = arg1
  return true

getMinSlavesParam = ->
  if args.length < 1
    console.log WRONG_NUM_OF_MIN_SLAVES_MSG
    console.log USAGE_MSG
    return false

  arg1 = +args.shift()

  if isNaN arg1
    console.log MIN_SLAVES_PARAM_MUST_BE_NUMBER_MSG
    console.log USAGE_MSG
    return false

  min_slaves = arg1
  return true

getMaxSlavesParam = ->
  if args.length < 1
    console.log WRONG_NUM_OF_MAX_SLAVES_MSG
    console.log USAGE_MSG
    return false

  arg1 = +args.shift()

  if isNaN arg1
    console.log MAX_SLAVES_PARAM_MUST_BE_NUMBER_MSG
    console.log USAGE_MSG
    return false

  max_slaves = arg1
  return true

buildSavesStr = (saves) ->
  unless saves instanceof Array
    console.log "ERR: The 'saves' var must be an array."
    process.exit(1)

  ret = ''

  `for (var i in saves) {
    ret += 'save ' + saves[i].time + ' ' + saves[i].changes + '\n';
  } //`

  return ret

getOrd = (num) ->
  n = +num

  if isNaN n
    console.log "ERR: 'num' must be an integer."
    process.exit(1)

  switch n
    when 1 then ret = 'st'
    when 2 then ret = 'nd'
    when 3 then ret = 'rd'
    else ret = 'th'

  return ret

cleanAll = ->
  disableStopDeleteService = (filename) ->
    execSync "systemctl stop #{filename}"
    console.log "Service #{filename} stopped."

    execSync "systemctl disable #{filename}"
    console.log "Service #{filename} disabled to execute at start up."

    execSync "rm -rf /lib/systemd/system/#{filename}"
    console.log "Service #{filename} deleted."

  deleteConfigFile = (filename) ->
    execSync "rm -rf /etc/redis/#{filename}"
    console.log "Config file #{filename} deleted."

  deletePidFolder = ->
    execSync "rm -rf /var/run/redis"
    console.log "PID folder deleted."

  service_regex = /\.service$/i

  njsrt_file = fs.readFileSync '/var/NJSRT.files', 'utf8'
  files = njsrt_file.split ','
  configs = []
  services = []

  while files.length > 0
    file = files.shift()

    if file
      if service_regex.test file then services.push file
      else configs.push file

  `for (var k in services) { disableStopDeleteService(services[k]); }
  for (var i in configs) { deleteConfigFile(configs[i]); } //`

  deletePidFolder()

  execSync 'rm -rf /var/NJSRT.files'


while args.length > 0
  param = args.shift()

  switch param
    when '--cleanall'
      cleanAll()
      console.log "\nFinished!"
      return
    when '--save'
      if not getSaveParam() then return
    when '--start-port'
      if not getStartPortParam() then return
    when '--min-slaves-to-write'
      if not getMinSlavesParam() then return
    when '--max-slaves-room'
      if not getMaxSlavesParam() then return
    else
      console.log "ERR: Unknown parameter '#{param}'."
      process.exit(1)

if saves.length is 0
  no_saves = true
  saves = [
    { time: 900, changes: 1},
    { time: 300, changes: 10},
    { time: 60, changes: 10000 }
  ]

save_srt = buildSavesStr saves

console.log '\n*** PARAMETERS: ***'
console.log "Number of masters: #{num_masters}"
console.log "Number of slaves per master: #{num_slaves_per_master}"
console.log "Minimum number of connected slaves to allow write on master: #{min_slaves} #{if min_slaves is 1 then '(default)' else ''}"
console.log "Maximum number of slaves per master: #{max_slaves} #{if max_slaves is 4 then '(default)' else ''}"
console.log "Initial configuration port: #{start_port} #{if start_port is 6379 then '(default)' else ''}"
console.log "Save directives: #{if no_saves then '(default)' else ''}\n#{save_srt}"

readline = require 'readline'
rl = readline.createInterface input: process.stdin, output: process.stdout

doAsk = ->
  rl.question 'These are the parameters that are going to be used to configure the servers.\n\nWould you like to continue? [Y/n] ', (answer) ->
    if answer isnt 'Y' and answer isnt 'y' and answer isnt 'N' and answer isnt 'n'
      console.log 'Please, type either \'y\' or \'n\'.'
      doAsk()
    else if answer is 'Y' or answer is 'y'
      console.log '\nAll right! Let\'s do this!'
      console.log '\nInitiating configuration process.'
      doTheConfig()
    else
      console.log '\nOk, thank you!\n'
      process.exit()

doAsk()

buildConfigFile = (template, replacements) ->
  `for (var i in replacements) {
    template = template.replace(replacements[i].param, replacements[i].replacement);
  } //`

  return template

doTheConfig = ->
  enableStartService = (master_slave, filename) ->
    execSync "systemctl enable #{filename}"
    console.log "#{master_slave} service enabled to execute at system start up."

    execSync "systemctl start #{filename}"
    console.log "#{master_slave} service started."

  createPidFolderWithOwnership = ->
    execSync "mkdir /var/run/redis"
    console.log "PID folder created."

    execSync "chown redis:redis /var/run/redis"
    console.log "Ownership over PID folder given to 'redis' user."


  highest_port_num = start_port + num_masters - 1 + masters_room + (num_masters * num_slaves_per_master - 1) * max_slaves
  master_ord = getOrd num_masters
  slave_ord = getOrd num_slaves_per_master

  if highest_port_num > 65000
    console.log "\nERR: The #{num_slaves_per_master}#{slave_ord} slave of the #{num_masters}#{master_ord} master will have the port number #{highest_port_num}.\nPlease, change your parameters so that this port will be lower than 65000.\n"
    process.exit(1)

  console.log "\nHighest port number of the last master's last slave: #{highest_port_num}"

  config_template = fs.readFileSync './config.template', 'utf8'
  service_template = fs.readFileSync './systemd-service.template', 'utf8'

  current_port = start_port - 1
  last_master_port = current_port + num_masters
  masters_ports = []
  slaves_ports = []
  services = []
  saved_files = ''

  `for (var i = 0; i < num_masters; i++) {
    current_port += 1;

    masters_ports.push(current_port);
    slaves_ports[i] = [];

    for (var n = 0; n < num_slaves_per_master; n++) {
      slaves_ports[i].push(last_master_port + masters_room + (i * num_slaves_per_master + n) * max_slaves);
    }
  }`

  if not fs.existsSync '/var/run/redis' then createPidFolderWithOwnership();

  while masters_ports.length > 0
    m_port = masters_ports.shift()
    s_ports = slaves_ports.shift()

    config_m_filename = "redis_m_#{m_port}.conf"
    service_m_filename = "redis_m_#{m_port}.service"
    pid_m_filename = "redis_#{m_port}.pid"

    wanted_services = []
    config_replacements = [
      { param: /<% port %>/ig, replacement: m_port },
      { param: /<% save_full %>/ig, replacement: 'save ""' },
      { param: /<% slaveof_full %>/ig, replacement: '' },
      { param: /<% min_slaves_to_write %>/ig, replacement: '1' }
    ]
    m_config = buildConfigFile config_template, config_replacements

    fs.writeFileSync "/etc/redis/#{config_m_filename}", m_config, 'utf8'
    console.log "\nMaster config file '#{config_m_filename}' written to disk."

    services.push { master_slave: 'MASTER', service: service_m_filename }

    saved_files += ',' + config_m_filename + ',' + service_m_filename

    while s_ports.length > 0
      s_port = s_ports.shift()

      config_s_filename = "redis_s_#{s_port}.conf"
      service_s_filename = "redis_s_#{s_port}.service"
      pid_s_filename = "redis_#{s_port}.pid"

      wanted_services.push service_s_filename

      config_replacements = [
        { param: /<% port %>/ig, replacement: s_port },
        { param: /<% save_full %>/ig, replacement: save_srt },
        { param: /<% slaveof_full %>/ig, replacement: "slaveof 127.0.0.1 #{m_port}" },
        { param: /<% min_slaves_to_write %>/ig, replacement: '0' }
      ]
      s_config = buildConfigFile config_template, config_replacements

      fs.writeFileSync "/etc/redis/#{config_s_filename}", s_config, 'utf8'
      console.log "Slave config file '#{config_s_filename}' written to disk."

      service_replacements = [
        { param: /<% description %>/ig, replacement: "SLAVE instance on port #{s_port}." },
        { param: /<% wants_full %>/ig, replacement: '' },
        { param: /<% filename %>/ig, replacement: config_s_filename },
        { param: /<% port %>/ig, replacement: s_port },
        { param: /<% pidfile %>/ig, replacement: "/var/run/redis/#{pid_s_filename}" }
      ]
      s_service = buildConfigFile service_template, service_replacements

      fs.writeFileSync "/lib/systemd/system/#{service_s_filename}", s_service, 'utf8'
      console.log "Slave service file '#{service_s_filename}' written to disk."

      services.push { master_slave: 'SLAVE', service: service_s_filename }

      saved_files += ',' + config_s_filename + ',' + service_s_filename

    wntd_svcs = ''
    while wanted_services.length > 0 then wntd_svcs += wanted_services.shift() + " "

    service_replacements = [
      { param: /<% description %>/ig, replacement: "MASTER instance on port #{m_port}." },
      { param: /<% wants_full %>/ig, replacement: "Wants=#{wntd_svcs}" },
      { param: /<% filename %>/ig, replacement: config_m_filename },
      { param: /<% port %>/ig, replacement: m_port },
      { param: /<% pidfile %>/ig, replacement: "/var/run/redis/#{pid_m_filename}" }
    ]
    m_service = buildConfigFile service_template, service_replacements

    fs.writeFileSync "/lib/systemd/system/#{service_m_filename}", m_service, 'utf8'
    console.log "Master service file '#{service_m_filename}' written to disk."

  execSync "systemctl daemon-reload"
  console.log "Reloaded systemctl daemon."

  while services.length > 0
    svc = services.shift()
    enableStartService(svc.master_slave, svc.service)

  njsrt_filepath = '/var/NJSRT.files'

  fs.writeFileSync(njsrt_filepath, saved_files, 'utf8');

  console.log("\nNJSRT file written to disk at '" + njsrt_filepath + "'.");
  console.log '\nFinished!'

  process.exit()