# Description:
#   Example scripts for you to examine and try out.
#
# Commands:
#   hubot air - Reply with city air information and guide
#   hubot weather - Reply with weather information about today and tomorrow
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

module.exports = (robot) ->

  user = {}
  user.room = process.env.HUBOT_DEPLOY_ROOM || '#general'
  #user.user = 'mariah'
  user.type = 'groupchat'

  jf = require('jsonfile')
  file = 'scripts/data.json'

  APP_KEY = '4bc92446-d191-39a5-936b-0e73f2c64fa5'

  workdaysLunch = ->
    msg = '#Hubot 알림# 곧 점심 시간입니다. 챙겨야 할 것: 식권, 자기 방과 옆 방의 동료, 비더레^^'
    #robot.logger.info msg
    robot.send user, msg

  getCityAirByAirKorea = (callback) ->
    options = {
      agent: agent
    }
    KEY = 'GvlQdz9sKwdP7VKSZcuyxq7X1Fqwo5SoiPtP2qNdveH5tNPFVPj5U%2FTkQvEx7pLIWTYzAkUjq1rlcVhoaM9qMg%3D%3D'
    STATION = '정자1동'
    GRADES = ['', '좋음', '보통', '나쁨', '매우나쁨']
    url = "http://openapi.airkorea.or.kr/openapi/services/rest/ArpltnInforInqireSvc/getCtprvnRltmMesureDnsty?sidoName=경기&_type=json&ServiceKey=#{KEY}"
    robot.http(url, options)
      .header('Accept', 'application/json')
      .get() (err, res, body) ->
        if err
          res.send "Got error: #{err}"
          return

        msg = ""
        parseString = require('xml2js').parseString
        parseString body, (err, result) ->
          try
            i = 0
            arr = result.response.body[0].items[0].item
            while i < arr.length
              item = arr[i]
              msg = "현재 공기상태 (#{STATION} 측정소): #{GRADES[item.pm10Grade]} / 미세먼지(㎍/㎥)(pm10)값: #{item.pm10Value}" if item.stationName[0] is STATION
              i++
          finally
            callback msg

  workdaysQuit = ->
    getCityAirByAirKorea (cityAir) ->
      getWeatherByPlanet cityAir, (text) ->
        msg = "#Hubot 알림# 하루 업무를 마무리할 시간이네요.\n" + text
        robot.send user, msg

  getVerboseWeatherByPlanet = (cityAir, callback) ->
    console.log 'getVerboseWeatherByPlanet'
    options = {
      agent: agent
    }
    robot.http('http://apis.skplanetx.com/weather/forecast/3days?version=1&lat=37.3713180&lon=127.1223530&foretxt=Y', options)
    #robot.http('http://apis.skplanetx.com/weather/forecast/3days?version=1&city=경기&county=성남시 분당구&village=수내&foretxt=Y')
      .header('appKey', APP_KEY)
      .header('Accept', 'application/json')
      .get() (err, res, body) ->
        if err
          res.send "Got error: #{err}"
          return

        msg = ""
        parseString = JSON.parse(body)
        console.log parseString
        try
          if parseString.result.code is 9200
            weather = parseString.weather.forecast3days[0]
            current = weather.fcstext.text1
            tomorrow = weather.fcstext.text2
            msg = msg +
                "[기상개황(오늘)]\n#{current}\n\n" +
                "[기상개황(내일)]\n#{tomorrow}\n"
        finally
          callback msg

  getWeatherByPlanet = (cityAir, callback) ->
    lat = 37.3713180
    lon = 127.1223530
    robot.http("http://apis.skplanetx.com/weather/current/hourly?version=1&lat=#{lat}&lon=#{lon}")
      .header('appKey', APP_KEY)
      .header('Accept', 'application/json')
      .get() (err, res, body) ->
        msg = ""
        currentString = JSON.parse(body)
        if currentString.result.code is 9200
          current = currentString.weather.hourly[0]
          # 단기 예보
          robot.http("http://apis.skplanetx.com/weather/forecast/3days?version=1&lat=#{lat}&lon=#{lon}")
            .header('appKey', '4bc92446-d191-39a5-936b-0e73f2c64fa5')
            .header('Accept', 'application/json')
            .get() (err, res, body) ->
              forecastString = JSON.parse(body)
              try
                if forecastString.result.code is 9200
                  forecast3days = forecastString.weather.forecast3days[0]
                  tomorrow =
                    high: forecast3days.fcstdaily.temperature.tmax2day
                    low: forecast3days.fcstdaily.temperature.tmin2day
                    sky:
                      name: forecast3days.fcst3hour.sky.name16hour
                  msg = msg +
                    "[현재날씨] #{current.sky.name} (#{current.temperature.tc}°)\n" +
                    "[내일날씨] 오전 9시 기준 #{tomorrow.sky.name} (#{tomorrow.high}° #{tomorrow.low}°) (자세한 날씨는 /dm @wsdkbot weather)\n"
              finally
                msg = msg +
                    "[미세먼지] #{cityAir}"
              callback msg

  workdaysScrum = (place) ->
    msg = "#Hubot 알림# 10분 뒤 Daily Scrum 시작(#{place})입니다. 각자 현황판 업데이트 후 정시에 체크인해 주세요."
    robot.send user, msg

  robot.logger.info "Initializing CronJob... #{user.room}"
  require('time')

  #ProxyAgent = require('proxy-agent')
  #proxy = process.env.http_proxy || 'http://168.219.61.252:8080';
  #robot.logger.info "Setting proxy...", proxy
  #agent = new ProxyAgent(proxy)
  agent = null

  CronJob = require('cron').CronJob
  tz = 'Asia/Seoul'
  new CronJob('0 15 11 * * 1-5', workdaysLunch, null, true, tz)
  new CronJob('0 0 18 * * 1-5', workdaysQuit, null, true, tz)
  new CronJob('0 20 10 * * 1', ->
    workdaysScrum('월요일 1113호')
  , null, true, tz)
  new CronJob('0 20 10 * * 2-4', ->
    workdaysScrum('화-목요일 11-2 회의실')
  , null, true, tz)
  new CronJob('0 50 12 * * 5', ->
    workdaysScrum('금요일 11-2 회의실')
  , null, true, tz)

  robot.respond //i, (msg) ->
    msg.send "안녕하세요? Hubot입니다."

  #robot.hear /장소 : (.*) 회의실/i, (msg) ->
  #  msg.send "#Hubot 캠페인# 회의는 간결하게, 회의 시간에는 적극적이고 겸손하게 자신의 의견을 얘기해 주세요~"

  # "#회의"라는 단어가 포함되어 있으면 해당 메시지에서 시간("yyyy.mm.dd hour:min" 포맷만 인식)을 추출해 알람으로 등록
  robot.hear /#회의(.*)/i, (msg) ->
    fullMsg = msg.message.rawText
    beforeMin = 30
    time = fullMsg.match(/(\d{4}).(\d{1,2}).(\d{1,2})\s+\d{2}:\d{2}/)[0]
    console.log fullMsg, time
    return "" if time is null or time is ""
    cronDate = new Date(time)
    cronDate.setMinutes cronDate.getMinutes() - beforeMin
    CronJob = require("cron").CronJob
    job = new CronJob(cronDate, ->
      cronMsg = "#Hubot 알림# 회의 #{beforeMin}분 전입니다.\n" + fullMsg
      robot.send user, cronMsg
      removeAlarmJob fullMsg
      @stop()
    , null, true, tz)
    obj =
      time: time
      msg: fullMsg
    readJSONFile (err, data) ->
      if err
        console.log err
      else
        data.push obj
        writeJSONFile data
    #msg.send "회의 알람이 등록되었습니다."

  robot.respond /(^|\s)air|미세먼지(?=\s|$)/i, (msg) ->
    #help send message
    getCityAirByAirKorea (cityAir) ->
      msg.send "[미세먼지] #{cityAir}\n" +
                "[Air quality index]\n" +
                " 0~30 좋음\n" +
                " 31~80 보통\n" +
                " 81~150 나쁨  장시간 또는 무리한 실외활동 제한, 특히 눈이 아픈 증사이 있거나, 기침이나 목의 통증으로 불편한 사람은 실외활동을 피해야 함\n" +
                " 151~ 매우나쁨  장시간 또는 무리한 실외 활동제한, 목의 통증과 기침등의 증상이 있는 사람은 실외활동을 피해야 함"
    return

  readJSONFile = (callback) ->
    jf.readFile file, (err, data) ->
      if err
        callback err, null
      else
        callback null, data

  writeJSONFile = (data) ->
    jf.writeFile file, data, (err) ->
      console.log err  if err

  removeAlarmJob = (msg) ->
    readJSONFile (err, data) ->
      if err
        console.log err
      else
        tempData = []
        data.forEach (obj) ->
          tempData.push obj  if obj.msg isnt msg
        writeJSONFile tempData

  # 알람 초기화: data.json 파일의 내용을 모두 알람으로 등록
  initAlarms = ->
    readJSONFile (err, data) ->
      if err
        console.log err
      else
        beforeMin = 30
        CronJob = require("cron").CronJob
        data.forEach (obj) ->
          cronDate = new Date(obj.time)
          cronDate.setMinutes cronDate.getMinutes() - beforeMin
          job = new CronJob(cronDate, ->
            cronMsg = "#Hubot 알림# 회의 #{beforeMin}분 전입니다.\n" + obj.msg
            robot.send user, cronMsg
            removeAlarmJob obj.msg
            @stop()
          , null, true, tz)
  initAlarms()

  robot.respond /(^|\s)weather(?=\s|$)/i, (msg) ->
    getVerboseWeatherByPlanet '', (text) ->
      msg.send text
    return

  # robot.hear /badger/i, (msg) ->
  #   msg.send "Badgers? BADGERS? WE DON'T NEED NO STINKIN BADGERS"
  #
  # robot.respond /open the (.*) doors/i, (msg) ->
  #   doorType = msg.match[1]
  #   if doorType is "pod bay"
  #     msg.reply "I'm afraid I can't let you do that."
  #   else
  #     msg.reply "Opening #{doorType} doors"
  #
  # robot.hear /I like pie/i, (msg) ->
  #   msg.emote "makes a freshly baked pie"
  #
  # lulz = ['lol', 'rofl', 'lmao']
  #
  # robot.respond /lulz/i, (msg) ->
  #   msg.send msg.random lulz
  #
  # robot.topic (msg) ->
  #   msg.send "#{msg.message.text}? That's a Paddlin'"
  #
  #
  # enterReplies = ['Hi', 'Target Acquired', 'Firing', 'Hello friend.', 'Gotcha', 'I see you']
  # leaveReplies = ['Are you still there?', 'Target lost', 'Searching']
  #
  # robot.enter (msg) ->
  #   msg.send msg.random enterReplies
  # robot.leave (msg) ->
  #   msg.send msg.random leaveReplies
  #
  # answer = process.env.HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING
  #
  # robot.respond /what is the answer to the ultimate question of life/, (msg) ->
  #   unless answer?
  #     msg.send "Missing HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING in environment: please set and try again"
  #     return
  #   msg.send "#{answer}, but what is the question?"
  #
  # robot.respond /you are a little slow/, (msg) ->
  #   setTimeout () ->
  #     msg.send "Who you calling 'slow'?"
  #   , 60 * 1000
  #
  # annoyIntervalId = null
  #
  # robot.respond /annoy me/, (msg) ->
  #   if annoyIntervalId
  #     msg.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
  #     return
  #
  #   msg.send "Hey, want to hear the most annoying sound in the world?"
  #   annoyIntervalId = setInterval () ->
  #     msg.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
  #   , 1000
  #
  # robot.respond /unannoy me/, (msg) ->
  #   if annoyIntervalId
  #     msg.send "GUYS, GUYS, GUYS!"
  #     clearInterval(annoyIntervalId)
  #     annoyIntervalId = null
  #   else
  #     msg.send "Not annoying you right now, am I?"
  #
  #
  # robot.router.post '/hubot/chatsecrets/:room', (req, res) ->
  #   room   = req.params.room
  #   data   = JSON.parse req.body.payload
  #   secret = data.secret
  #
  #   robot.messageRoom room, "I have a secret: #{secret}"
  #
  #   res.send 'OK'
  #
  # robot.error (err, msg) ->
  #   robot.logger.error "DOES NOT COMPUTE"
  #
  #   if msg?
  #     msg.reply "DOES NOT COMPUTE"
  #
  # robot.respond /have a soda/i, (msg) ->
  #   # Get number of sodas had (coerced to a number).
  #   sodasHad = robot.brain.get('totalSodas') * 1 or 0
  #
  #   if sodasHad > 4
  #     msg.reply "I'm too fizzy.."
  #
  #   else
  #     msg.reply 'Sure!'
  #
  #     robot.brain.set 'totalSodas', sodasHad+1
  #
  # robot.respond /sleep it off/i, (msg) ->
  #   robot.brain.set 'totalSodas', 0
  #   robot.respond 'zzzzz'
