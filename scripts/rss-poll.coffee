# Description:
#   Polls the rss feeds and posts new content to the user or group chat.
#
# Dependencies:
#   "feed-read": "0.0.1"
#
# Configuration:
#   None
#
# Commands:
#   hubot rss-poll start <rss url> - Start polling for new content from the given rss feed.
#   hubot rss-poll stop <rss url> - Stop polling for content from the given rss feed.
#   hubot rss-poll list [all] - Lists the stored rss feeds for the given room or user.

crypto = require('crypto')
feedRead = require('feed-read')

module.exports = (robot) ->
    feedData =
        config:
            interval: 1
        feeds: { }
    intervalID = null

    getID = (url, to) ->
        crypto.createHash('sha1').update("#{url}+#{to}").digest('hex')

    getData = (url, to) ->
        id = getID(url, to)
        feedData.feeds[id]

    setData = (url, to, type) ->
        return false if getData(url, to)
        id = getID(url, to)
        feedData.feeds[id] =
            check: Date.now()
            url: url
            to: to
            type: type
        robot.brain.data.feedData = feedData
        true

    clearData = (url, to) ->
        return false if !getData(url, to)
        id = getID(url, to)
        delete feedData.feeds[id]
        robot.brain.data.feedData = feedData
        true

    getTo = (msg) ->
        to: msg.message.user.room || msg.message.user.id
        type: if msg.message.user.room then 'room' else 'user'

    getNewContent = (feed, callback) ->
        robot.logger.info "Reading #{feed.url}..."
        time = feed.check
        feed.check = Date.now()
        feedRead feed.url, (err, articles) ->
            if err
                robot.logger.error "Could not parse #{feed.url}"
                console.log err
                return
            newArticles = []
            for article in articles
                published = new Date(article.published).getTime()
                if published > time
                    newArticles.unshift article
            callback(feed, newArticles)

    buildArticlesString = (articles) ->
        ret = []
        for article in articles
            tmp = []
            for key, val of article
                capital = key.charAt(0).toUpperCase() + key.slice(1)
                tmp.push("#{capital}: #{val}") if typeof val == 'string'
            ret.push(tmp.join("\n"))
        ret.join "\n---------------------------\n"

    startProcessing = ->
        clearInterval intervalID
        intervalID = setInterval ->
            for key, feed of feedData.feeds
                getNewContent feed, (aFeed, articles) ->
                    return if articles.length == 0
                    robot.logger.info "Received #{articles.length} new article(s) for #{aFeed.url}"
                    for article in articles
                        robot.logger.info "* #{article.title}"
                    msg = buildArticlesString articles
                    if aFeed.type == 'room'
                        robot.messageRoom aFeed.to, msg
                    else
                        user = robot.brain.userForId aFeed.to
                        robot.send user: user, msg
                    robot.logger.info "Sending article(s) to #{aFeed.type}: #{aFeed.to}"
        , feedData.config.interval * 60000

    robot.brain.on 'loaded', ->
        feedData = robot.brain.data.feedData || feedData
        # Before processing be sure to set all the
        # feed check timestamps to the current time.
        for key, val of feedData.feeds
            val.check = Date.now()
        startProcessing()

    robot.error (err, msg) ->
        console.log err

    robot.respond /rss-poll start (\S+)/i, (msg) ->
        rssUrl = msg.match[1]
        toData = getTo(msg)
        if setData(rssUrl, toData.to, toData.type)
            response = "#{rssUrl} is bound to #{toData.to}."
            console.log response
            msg.send response
        else
            response = "#{rssUrl} is already bound to #{toData.to}."
            console.log response
            msg.send response

    robot.respond /rss-poll stop (\S+)/i, (msg) ->
        rssUrl = msg.match[1]
        toData = getTo(msg)
        if clearData(rssUrl, toData.to)
            response = "#{rssUrl} was removed from #{toData.to}."
            console.log response
            msg.send response
        else
            response = "There was an error removing #{rssUrl} from #{toData.to}."
            console.log response
            msg.send response

    robot.respond /rss-poll list\s*(all)?/i, (msg) ->
        feeds = []
        to = ''
        all = if msg.match[1] then true else false
        if msg.message.user.room and not all
            to = msg.message.user.room
            for key, val of feedData.feeds
                feeds.push(val) if val.to == msg.message.user.room
        else if not all
            to = msg.message.user.id
            for key, val of feedData.feeds
                feeds.push(val) if val.to == msg.message.user.id
        else
            to = 'everyone'
            for key, val of feedData.feeds
                feeds.push val
        ret = []
        ret.push "Feeds for #{to}:"
        ret.push "=========================="
        for feed in feeds
            check = parseInt((Date.now() - feed.check) / 1000)
            ret.push " * To: #{feed.to}"
            ret.push "   Url: #{feed.url}"
            ret.push "   Last check: #{check} seconds ago"
        ret.push " "

        msg.send ret.join("\n")
