resque = require "coffee-resque"

module.exports = {
  get_connection: () ->
    redis_host = process.env.REDIS_HOST || "localhost"
    redis_port = process.env.REDIS_PORT || "6379"
    redis_password = process.env.REDIS_PASSWORD || ""

    console.log redis_host, redis_port, redis_password
    connection = resque.connect(host: redis_host , port: redis_port, password:redis_password )
    return connection
}
