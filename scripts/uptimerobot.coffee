# Description
#   A hubot script to list, pause and resume monitor checks
#
# Configuration:
#   HUBOT_UPTIMEROBOT_APIKEY
#
# Commands:
#   hubot uptime list - Lists all checks in private message
#   hubot uptime pause [id] - Pauses check by id
#   hubot uptime resume [id] - Resumes check by id
#
# Forked from script by patcon@myplanetdigital

apiKey = process.env.HUBOT_UPTIMEROBOT_APIKEY

module.exports = (robot) ->

  REGEX = ///
    uptime
    (       # 1)
      \s+   #    whitespace
      (.*)  # 2) filter
    )?
  ///i
  robot.respond REGEX, (msg) ->
    msg.send "List of available commands:"
    msg.send "uptime list - lists all checks in private message"
    msg.send "uptime pause [id] - pauses check by id"
    msg.send "uptime resume [id] - resumes check by id"

  robot.respond /uptime list/i, (msg) ->
    Client = require 'uptime-robot'
    client = new Client apiKey

    filter = msg.match[2]
    data = {}

    client.getMonitors data, (err, res) ->
      if err
        throw err

      monitors = res

      if filter
        query = require 'array-query'
        monitors = query('friendlyname')
          .regex(new RegExp filter, 'i')
          .on res

    msg.send "@" + msg.message.user.mention_name + " sent details as private message"
    robot.send({
      user: msg.message.user.jid
    },
      for monitor, i in monitors
        name   = monitor.friendlyname
        id     = monitor.id

        "#{name} -> #{id}");

