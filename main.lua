local randomid = require "randomid"
local color = require "color"
local msgr = require "mqttLoveLibrary"
local easytext = require "easytext"
local referee = require "referee"
local timers = require "timers"
local physics = require "physics"

function math.clamp(min, value, max)
  return math.max(min, math.min(value, max))
end

local host = "broker.hivemq.com"
PLAYER_RADIUS = 30
PROJECTILE_RADIUS = 10
local channel
local myId
local isreferee

local state = "title"
local players = {}
local num_players = 0
local buildings = {}
local activeplayer
local lastspeed
local speed
local angle
local phase
local projectile
local timer

local title_selectedoption = "join"
local title_txtJoinRoom

local title_txtCreateRoom
local title_txtControls

local joining_code = { '_', '_', '_', '_', '_', '_', '_', '_', '_' }
local joining_cursor = 1
local joining_txtPlayerLabel
local joining_txtPlayerName
local joining_txtRoomPrompt
local joining_txtRoomCode

local waiting_txtRoomCode
local waiting_txtPlayersLabel

local playing_txtTitle
local playing_txtSubtitle

function love.load()
  io.stdout:setvbuf("no") -- makes the console output update more frequently
  
  math.randomseed(os.time())
  myId = randomid('?????-?????') -- generates a random player ID
  
  love.window.setTitle("Gorillas - " .. myId)
  
  love.keyboard.setKeyRepeat(true)
  
  -- Title Screen
  
  title_txtJoinRoom = easytext.new(48, "> Entrar em uma sala <")
  easytext.setColor(title_txtJoinRoom, 1, 1, 1)
  
  title_txtCreateRoom = easytext.new(48, "Criar uma sala")
  easytext.setColor(title_txtCreateRoom, 1, 1, 1)
  
  title_txtControls = easytext.new(32, "Controles: <Up> <Down> <Left> <Right> <Space>")
  easytext.setColor(title_txtControls, 1, 1, 1)
  
  -- Joining State
  
  joining_txtPlayerLabel = easytext.new(32, "Seu nome:")
  easytext.setColor(joining_txtPlayerLabel, 1, 1, 1)
  
  joining_txtPlayerName = easytext.new(48, myId)
  easytext.setColor(joining_txtPlayerName, 1, 1, 1)
  
  joining_txtRoomPrompt = easytext.new(32, "Digite o código da sala:")
  easytext.setColor(joining_txtRoomPrompt, 1, 1, 1)
  
  joining_txtRoomCode = easytext.new(48, "_ _ _ - _ _ _ - _ _ _")
  easytext.setColor(joining_txtRoomCode, 1, 1, 1)
  
  -- Waiting State
  
  waiting_txtRoomCode = easytext.new(24, "Sala: ???-???-???")
  easytext.setColor(waiting_txtRoomCode, 1, 1, 1)
  
  waiting_txtPlayersLabel = easytext.new(24, "Jogadores:")
  easytext.setColor(waiting_txtPlayersLabel, 1, 1, 1)
  
  waiting_txtWaitingMsg = easytext.new(32, "Aguarde o início do jogo...")
  easytext.setColor(waiting_txtWaitingMsg, 1, 1, 1)
  
  -- Playing State
  
  playing_txtTitle = easytext.new(32, "O jogo já vai começar...")
  easytext.setColor(playing_txtTitle, 1, 1, 1)
  
  playing_txtSubtitle = easytext.new(16)
  easytext.setColor(playing_txtSubtitle, 1, 1, 1)
  
  -- GameOver State
  
  gameover_txtGameOver = easytext.new(32, "Fim do jogo")
  easytext.setColor(gameover_txtGameOver, 1, 1, 1)
  
  gameover_txtWinnerName = easytext.new(24)
  easytext.setColor(gameover_txtWinnerName, 1, 1, 1)
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  local line_height = 1.2
  
  if state == "title" then
    love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
    local y = h/2
    local _, th = easytext.getDimensions(title_txtJoinRoom)
    easytext.draw(title_txtJoinRoom, w/2, y, "n")
    y = y + th * line_height
    easytext.draw(title_txtCreateRoom, w/2, y, "n")
    easytext.draw(title_txtControls, w/2, 0.8*h, "n")
  elseif state == "joining" then
    love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
    local y = 0.2*h
    local _, th = easytext.getDimensions(joining_txtPlayerLabel)
    easytext.draw(joining_txtPlayerLabel, w/2, y, "n")
    y = y + th * line_height
    _, th = easytext.getDimensions(joining_txtPlayerName)
    easytext.draw(joining_txtPlayerName, w/2, y, "n")
    y = y + th * line_height * 2
    _, th = easytext.getDimensions(joining_txtRoomPrompt)
    easytext.draw(joining_txtRoomPrompt, w/2, y, "n")
    y = y + th * line_height
    _, th = easytext.getDimensions(joining_txtRoomCode)
    easytext.draw(joining_txtRoomCode, w/2, y, "n")
    y = y + th * line_height
  elseif state == "waiting" then
    love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
    easytext.draw(waiting_txtWaitingMsg, w/2, 0.1*h)
    easytext.draw(waiting_txtRoomCode, w/2, 0.9*h)    
    local y = 0.2*h
    local _, th = easytext.getDimensions(waiting_txtPlayersLabel)
    easytext.draw(waiting_txtPlayersLabel, w/2, y, "n")
    y = y + th * line_height * 2
    
    for id, p in pairs(players) do
      _, th = easytext.getDimensions(p.txtname)
      easytext.draw(p.txtname, w/2, y, "n")
      y = y + th * line_height
    end
  elseif state == "playing" then
    love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
    
    for i = 1, #buildings do
      local bx = buildings[i].x
      local bw = (buildings[i+1] and buildings[i+1].x or w) - bx
      local by = buildings[i].y
      local bh = h-by
      local bc = buildings[i].color
      love.graphics.setColor(bc[1], bc[2], bc[3])
      love.graphics.rectangle("fill", bx, by, bw, bh)
    end
    
    for pid, p in pairs(players) do
      if p.x ~= nil and p.y ~= nil then
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        
        if p.hp == 0 then
          love.graphics.setColor(0.4, 0.4, 0.4)
        elseif pid == myId then
          love.graphics.setColor(0.0, 1.0, 0.0)
        else
          love.graphics.setColor(1.0, 0.0, 0.0)
        end
        
        -- draws angle arrow
        love.graphics.push()
        local ang = (pid == myId and angle or p.angle or 0)/180 * math.pi
        love.graphics.rotate(-math.pi/2 + ang)
        love.graphics.line(0, 0, PLAYER_RADIUS*2.0, 0)
        love.graphics.pop()
        
        -- draws player body
        love.graphics.circle("fill", 0, 0, PLAYER_RADIUS)
        
        -- draws player name
        easytext.draw(p.txtname, 0, -30 - PLAYER_RADIUS, "s")
        
        -- draws player hp bar
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", -50, 5 + PLAYER_RADIUS, 100, 5)
        if p.hp > 30 then
          love.graphics.setColor(0.1, 0.8, 0.0)
        elseif p.hp > 0 then
          love.graphics.setColor(0.8, 0.0, 0.0)
        end
        love.graphics.rectangle("fill", -50, 5 + PLAYER_RADIUS, p.hp, 5)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1.0, 1.0, 1.0)
        love.graphics.rectangle("line", -50, 5 + PLAYER_RADIUS, 100, 5)
        
        love.graphics.pop()
      end
    end
    
    if not phase or phase == "idle" then
      local y = 0.2*h
      local _, th = easytext.getDimensions(playing_txtTitle)
      easytext.draw(playing_txtTitle, w/2, y, "n")
      y = y + th * line_height * 2
      easytext.draw(playing_txtSubtitle, w/2, y, "n")
    end
    
    if projectile then
      local x, y = physics.getPosition(projectile)
      love.graphics.setColor(1.0, 0.0, 0.0)
      love.graphics.circle("fill", x, y, PROJECTILE_RADIUS)
    end
    
    if activeplayer and activeplayer.pid == myId then
      -- draws the charging bar
      love.graphics.setColor(0.4, 0.4, 0.4)
      love.graphics.rectangle("fill", 0, 0, w, 50)
      if lastspeed then
        love.graphics.setColor(0.4, 0.4, 0)
        love.graphics.rectangle("fill", 0, 0, lastspeed * w, 50)
      end
      love.graphics.setColor(0.8, 0.8, 0)
      love.graphics.rectangle("fill", 0, 0, speed * w, 50)
    end
  elseif state == "gameover" then
    love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
    local y = h/2
    local _, th = easytext.getDimensions(gameover_txtGameOver)
    easytext.draw(gameover_txtGameOver, w/2, y, "n")
    y = y + th * line_height
    easytext.draw(gameover_txtWinnerName, w/2, y, "n")
  end
end

local recv = {
  ["PLAYERS"] = function (msg) -- sent when we join a room
    for i = 2, #msg do
      local pid = msg[i]
      if players[pid] == nil then
        local txtname = easytext.new(24, pid)
        if pid == myId then
          easytext.setColor(txtname, 0.0, 1.0, 0.0)
        else
          easytext.setColor(txtname, 1.0, 1.0, 1.0)
        end
        
        players[pid] = {
          pid = pid,
          txtname = txtname
        }
        num_players = num_players + 1
      end
    end
  end,
  ["START"] = function (msg) -- sent when the referee started the game
    local num_buildings = msg[2]
    buildings = {}
    for i = 3, 3+num_buildings*3-1, 3 do
      local x = tonumber(msg[i])
      local y = tonumber(msg[i+1])
      local color = color.totable(msg[i+2])
      buildings[#buildings+1] = {
        x = x,
        y = y,
        color = color
      }
      print("building", x, y, msg[i+2])
    end
    
    angle = math.random(2) == 1 and -30 or 30
    
    state = "playing"
  end,
  ["PLAYERDATA"] = function (msg) -- sent at the start when the referee places a player in the map
    local pid = msg[2]
    local p = players[pid]
    p.x = tonumber(msg[3])
    p.y = tonumber(msg[4])
    p.hp = tonumber(msg[5])
  end,
  ["TURN"] = function (msg) -- sent every time someone's turn starts
    local pid = msg[2]
    activeplayer = players[pid]
    phase = "idle"
    speed = 0
    if pid == myId then
      easytext.setString(playing_txtTitle, "Sua vez! Aperte e segure <Space>")
      easytext.setColor(playing_txtTitle, 0.0, 1.0, 0.0)
    else
      easytext.setString(playing_txtTitle, "É a vez de " .. pid)
      easytext.setColor(playing_txtTitle, 1.0, 1.0, 1.0)
    end
    easytext.setString(playing_txtSubtitle, "20 segundos restantes")
    easytext.setColor(playing_txtSubtitle, 0.8, 0.8, 0.8)
    local totaltime = 20
    local cb
    cb = function ()
      totaltime = totaltime - 1
      easytext.setString(playing_txtSubtitle, totaltime .. " segundos restantes")
      if totaltime >= 15 then
        easytext.setColor(playing_txtSubtitle, 0.8, 0.8, 0.8)
      elseif totaltime >= 10 then
        easytext.setColor(playing_txtSubtitle, 0.8, 0.8, 0.0)
      elseif totaltime >= 5 then
        easytext.setColor(playing_txtSubtitle, 1.0, 0.0, 0.0)
      end
      if totaltime > 0 then
        timer = timers.new(1.000, cb)
      end
    end
    timer = timers.new(1.000, cb)
  end,
  ["ANGLE"] = function (msg) -- sent every time someone changes their angle
    local pid = msg[2]
    local ang = tonumber(msg[3])
    if pid ~= myId and players[pid] then
      players[pid].angle = ang
    end
  end,
  ["SKIPPED"] = function (msg) -- sent when someone didn't fire in time and was skipped
    local pid = msg[2]
    easytext.setString(playing_txtTitle, pid .. " perdeu a vez.")
    easytext.setColor(playing_txtTitle, 0.8, 0.8, 0.8)
    easytext.setString(playing_txtSubtitle, "")
    timer = nil
  end,
  ["PROJECTILE"] = function (msg) -- sent after someone fires
    local x = tonumber(msg[2])
    local y = tonumber(msg[3])
    local angle = tonumber(msg[4])
    local speed = tonumber(msg[5])
    
    timer = nil
    projectile = physics.new(x, y, angle, speed)
  end,
  ["PLAYERHP"] = function (msg) -- sent after someone's hp changed
    local pid = msg[2]
    local hp = tonumber(msg[3])
    if players[pid] then
      players[pid].hp = hp
    end
  end,
  ["GAMEOVER"] = function (msg) -- sent when there's only one player left alive.
    local pid = msg[2]
    timer = nil
    state = "gameover"
    if pid == myId then
      easytext.setString(gameover_txtWinnerName, "Você venceu!")
      easytext.setColor(gameover_txtWinnerName, 0.0, 1.0, 0.0)
    else
      easytext.setString(gameover_txtWinnerName, pid .. " venceu!")
      easytext.setColor(gameover_txtWinnerName, 1.0, 1.0, 1.0)
    end
  end
}

local function messageReceived(msgstring)
  local parts = {}
  for s in string.gmatch(msgstring, "<(.-)>") do
    table.insert(parts, s)
  end
  
  if recv[parts[1]] then
    recv[parts[1]](parts)
  end
  
  if isreferee and referee.recv[parts[1]] then
    referee.recv[parts[1]](parts)
  end
end     

function love.update(dt)
  if state ~= "title" and state ~= "joining" and state ~= "gameover" then
    msgr.checkMessages()
  end
  
  -- if it's our turn and we're holding space, increment the speed bar
  if phase == "firing" then
    speed = speed + dt/4
  end
  
  if projectile then
    local delete = (
      physics.checkCollisionWithPlayers(projectile, players, activeplayer) or
      physics.checkCollisionWithBuildings(projectile, buildings) or
      physics.isOutOfBounds(projectile)
    )
    
    if delete then
      projectile = nil
    else
      physics.update(projectile, dt)
    end
  end
  
  if isreferee then
    referee.update(dt)
  end
  
  timers.update(timer, dt)
end

function love.textinput(text)
  if state == "joining" then
    if not string.match(text, "%a") then return end
    
    joining_code[joining_cursor] = text
    joining_cursor = joining_cursor + 1
    
    easytext.setString(joining_txtRoomCode,
      table.concat(joining_code,' ', 1, 3) .. ' - ' .. 
      table.concat(joining_code,' ', 4, 6) .. ' - ' .. 
      table.concat(joining_code,' ', 7, 9)
    )
    
    if joining_cursor > #joining_code then
      channel = (table.concat(joining_code, '', 1, 3) .. '-' ..
                 table.concat(joining_code, '', 4, 6) .. '-' ..
                 table.concat(joining_code, '', 7, 9))
      state = "waiting"
      easytext.setString(waiting_txtWaitingMsg, "Aguarde o início do jogo...")
      easytext.setString(waiting_txtRoomCode, "Sala: " .. channel)
      msgr.start(host, myId, channel, messageReceived)
      msgr.sendMessage(string.format("<JOIN><%s>", myId), channel)
    end
  end
end

function love.keypressed(key, scancode, isrepeat)
  if state == "title" then
    if key == "up" or key == "down" or key == "left" or key == "right" then
      if title_selectedoption == "join" then
        title_selectedoption = "create"
        easytext.setString(title_txtJoinRoom, "Entrar em uma sala")
        easytext.setString(title_txtCreateRoom, "> Criar uma sala <")
      else
        title_selectedoption = "join"
        easytext.setString(title_txtJoinRoom, "> Entrar em uma sala <")
        easytext.setString(title_txtCreateRoom, "Criar uma sala")
      end
    elseif key == "space" then
      if title_selectedoption == "join" then
        state = "joining"
        isreferee = false
      else
        state = "waiting"
        isreferee = true
        channel = referee.load(msgr.sendMessage)
        easytext.setString(waiting_txtWaitingMsg, "Aperte <Space> para começar")
        easytext.setString(waiting_txtRoomCode, "Sala: " .. channel)
        msgr.start(host, myId, channel, messageReceived)
        msgr.sendMessage(string.format("<JOIN><%s>", myId), channel)
      end
    end
  elseif state == "joining" then
    if key == "backspace" then
      joining_cursor = math.max(1, joining_cursor-1)
      joining_code[joining_cursor] = '_'
      
      easytext.setString(joining_txtRoomCode,
        table.concat(joining_code,' ', 1, 3) .. ' - ' .. 
        table.concat(joining_code,' ', 4, 6) .. ' - ' .. 
        table.concat(joining_code,' ', 7, 9)
      )
    end
  elseif state == "waiting" and isreferee and num_players >= 1 and key == "space" then
    referee.start()
  elseif state == "playing" then
    if key == "up" then
      angle = math.clamp(-60, angle - 1, 60)
    elseif key == "down" then
      angle = math.clamp(-60, angle + 1, 60)
    elseif (key == "left" and angle > 0) or (key == "right" and angle < 0) then
      angle = -angle
      msgr.sendMessage(string.format("<ANGLE><%s><%d>", myId, angle), channel)
    elseif key == "space" and not isrepeat then
      if activeplayer and activeplayer.pid == myId and phase == "idle" then
        speed = 0
        phase = "firing"
      end
    end
  elseif state == "gameover" then
    love.event.quit()
  end
end

function love.keyreleased(key, scancode)
  if state == "playing" then
    if key == "up" or key == "down" then
      msgr.sendMessage(string.format("<ANGLE><%s><%d>", myId, angle), channel)
    elseif key == "space" and phase == "firing" then
      timer = nil
      phase = "fired"
      lastspeed = speed
      msgr.sendMessage(string.format(
        "<FIRE><%s><%d><%d>",
        myId,
        angle,
        math.floor(speed*1000)
      ), channel)
    end
  end
end
