local referee = {}

local randomid = require "randomid"
local color = require "color"
local timers = require "timers"
local physics = require "physics"

-- how long to wait before skipping the player's turn, in seconds.
-- added 1 second to account for latency
local TURN_DURATION = 21.000 

local sendMessage
local channel
local players
local num_players
local started
local buildings
local turnOrder
local turn
local projectile

local timer

-- sends a list of all player IDs in a waiting room
local function sendPlayers(players)
  local msg = "<PLAYERS>"
  for _, p in pairs(players) do
    msg = msg .. "<" .. p.pid .. ">"
  end
  sendMessage(msg, channel)
end

-- starts the game and sends the buildings data
local function sendStart(buildings)
  local msg = "<START><" .. #buildings .. ">"
  for i, b in ipairs(buildings) do
    msg = msg .. string.format("<%d><%d><%s>", b.x, b.y, b.color)
  end
  sendMessage(msg, channel)
end

-- starts the turn of a given player
local function sendTurn(pid)
  local msg = "<TURN><" .. pid .. ">"
  sendMessage(msg, channel)
end

-- sends player position and starting hp
local function sendPlayerData(p)
  local msg = string.format(
    "<PLAYERDATA><%s><%d><%d><%d>",
    p.pid,
    p.x,
    p.y,
    p.hp
  )
  sendMessage(msg, channel)
end

-- notifies that a the given player has been skipped
local function sendSkipped(pid)
  local msg = "<SKIPPED><" .. pid .. ">"
  sendMessage(msg, channel)
end

-- tells players to create a projectile
local function sendProjectile(x, y, angle, speed)
  local msg = string.format("<PROJECTILE><%d><%d><%d><%d>", x, y, angle, speed)
  sendMessage(msg, channel)
end

-- updates a player's hp
local function sendPlayerHp(p)
  local msg = string.format("<PLAYERHP><%s><%d>", p.pid, p.hp)
  sendMessage(msg, channel)
end

-- tells players that the game is over and says who's the winner
local function sendGameOver(winner)
  local msg = string.format("<GAMEOVER><%s>", winner.pid)
  sendMessage(msg, channel)
end

-- creates buildings
-- buildings are defined only by their top-left x and y coordinates
-- their width is implied by the next building's x value (there are no gaps between buildings).
-- their height is from the y value to the bottom of the screen.
local function generateBuildings()
  local buildings = {}
  
  local x = 0
  local y = math.random(360, 660)
  while x < 1280-80 do -- create buildings until the screen width is filled
    buildings[#buildings+1] = {
      x = x,
      y = y,
      color = color.tostring(color.random())
    }
    x = x + math.random(80, 160)
    local new_y = math.random(440, 660)
    if math.abs(y - new_y) < 20 then
      new_y = y - 20
    end
    y = new_y
  end
  
  return buildings
end

-- shuffles players to define the turn order.
local function shufflePlayers()
  local turnOrder = {}
  for _, v in pairs(players) do
    turnOrder[#turnOrder+1] = v
  end
  
  -- Fisher-Yates shuffle
  for i = #turnOrder, 2, -1 do
    local j = math.random(i)
    turnOrder[i], turnOrder[j] = turnOrder[j], turnOrder[i]
  end
  
  return turnOrder
end

-- initializes player positions and health
-- players are placed in the center of a random building.
local function initializePlayers()
  local availableBuildings = {}
  for i = 1, #buildings do
    availableBuildings[i] = i
    print("av", i)
  end
  
  for _, p in pairs(players) do
    local b = table.remove(availableBuildings, math.random(#availableBuildings))
    print("b", b)
    local x0 = buildings[b].x
    local x1 = buildings[b+1] and buildings[b+1].x or 1280
    p.x = math.floor((x1 + x0)/2)
    p.y = buildings[b].y - PLAYER_RADIUS
    p.hp = 100
  end
end
  
-- starts the referee module
-- we'll keep a reference to the sendMessage function so we can use the same connection.
-- returns the mqtt channel, which is the room ID.
function referee.load(sendfn)
  sendMessage = sendfn
  channel = randomid("???-???-???")
  players = {}
  num_players = 0
  started = false
  buildings = nil
  turnOrder = nil
  projectile = nil
  turn = nil
  return channel
end

local advanceTurn

local function getActivePlayer()
  return turnOrder[turn]
end

local function skipTurn()
  sendSkipped(getActivePlayer().pid)
  timer = timers.new(2.000, advanceTurn) -- advance to the next turn after 2 seconds
end

advanceTurn = function ()
  turn = (turn or 0) % #turnOrder + 1 -- increment turn number, wrapping around.
  sendTurn(getActivePlayer().pid)
  timer = timers.new(TURN_DURATION, skipTurn) -- skips turn after TURN_DURATION seconds, unless we remove the timer when the player fires.
end

-- removes the given player from the turn order because they're dead
local function removeDeadPlayerFromTurnOrder(player)
  for i = 1, #turnOrder do
    if turnOrder[i] == player then
      table.remove(turnOrder, i)
      -- if the current active player goes before the removed player in the turn
      -- order, we must decrement turn by 1 so that turnOrder[turn] keeps
      -- pointing to the active player.
      if i < turn then 
        turn = turn - 1 
      end
      break
    end
  end
end
  
-- deals damage to a player given the projectile speed
local function damagePlayer(player, projSpeed)
  local delta = math.max(10, math.floor(projSpeed * 50 / 1000)) -- take at least 10 health with every shot
  player.hp = math.max(0, player.hp - delta)
  sendPlayerHp(player)
  if player.hp == 0 then
    removeDeadPlayerFromTurnOrder(player)
  end
end

-- returns false if the game is over
-- returns true and the winner's player table if the game is over.
-- the game is over when there's only one player left.
local function isGameOver()
  if #turnOrder == 1 then
    return true, turnOrder[1]
  end
  return false
end

-- starts the game
function referee.start()
  started = true
  buildings = generateBuildings()
  turnOrder = shufflePlayers()
  sendStart(buildings)
  initializePlayers()
  timer = timers.new(2.000, function () -- wait 2 seconds so players can see the map
    for _, p in pairs(players) do
      sendPlayerData(p)
    end
    timer = timers.new(2.000, advanceTurn) -- wait 2 seconds so players can see where everyone is before playing
  end)
end


function referee.update(dt)
  timers.update(timer, dt)
  if projectile then   
    local playerHit = physics.checkCollisionWithPlayers(projectile, players, getActivePlayer())
    if playerHit then -- projectile hit a player
      damagePlayer(playerHit, physics.getSpeed(projectile))
      projectile = nil
      local isOver, winner = isGameOver()
      if isGameOver() then
        timer = timers.new(2.000, function () -- wait 2 seconds before ending the game
          sendGameOver(winner)
        end)
      else
        timer = timers.new(2.000, advanceTurn) -- wait 2 seconds before advancing the game
      end
    elseif physics.checkCollisionWithBuildings(projectile, buildings) or
        physics.isOutOfBounds(projectile) then -- projectile hit a building or went off the map
      projectile = nil
      timer = timers.new(2.000, advanceTurn) -- wait 2 seconds before advancing the game
    else
      physics.update(projectile, dt) -- update projectile position and velocity
    end
  end
end
  
referee.recv = {
  ["JOIN"] = function (msg) -- sent when a player joins the waiting room
    local pid = msg[2]
    players[pid] = {
      pid = pid
    }
    sendPlayers(players)
  end,
  ["FIRE"] = function (msg) -- sent when a player fires in their turn
    local pid = msg[2]
    local angle = math.clamp(-60, tonumber(msg[3]), 60)
    local speed = math.clamp(0, tonumber(msg[4]), 1000)
    local p = getActivePlayer()
    if pid ~= p.pid then
      return
    end
    
    timer = nil
    
    projectile = physics.new(p.x, p.y, angle, speed)
    sendProjectile(p.x, p.y, angle, speed)
  end
}

return referee