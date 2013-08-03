
(function generate-upstart-config (CONTAINER NAME PORT) <<-END
#
# AUTOMATICALLY GENERATED 
#
start on runlevel [2345]
setuid control
chdir #{CONTROL-PATH}/workers/#{CONTAINER}/#{NAME}.app
exec ./#{NAME} -p #{PORT}
respawn
respawn limit 10 90
END)
