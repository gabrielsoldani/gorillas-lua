local physics = {}

physics.GRAVITY = 400

function physics.new(x, y, angle, speed)
  local rad = angle/180 * math.pi
  local vx = speed * math.sin(rad)
  local vy = -speed * math.cos(rad)
  
  return {
    x = x,
    y = y,
    r = PROJECTILE_RADIUS,
    vx = vx,
    vy = vy
  }
end

function physics.update(obj, dt)
  obj.vy = obj.vy + physics.GRAVITY * dt
  
  obj.x = obj.x + obj.vx * dt
  obj.y = obj.y + obj.vy * dt
end

function physics.checkCollisionWithCircle(obj, x, y, r)
  return (obj.x - x)^2 + (obj.y - y)^2 <= (obj.r + r)^2
end

function physics.checkCollisionWithRect(obj, x, y, w, h)
  return (obj.x+obj.r >= x and obj.x-obj.r < x+w and 
          obj.y+obj.r >= y and obj.y-obj.r < y+h)
end

function physics.getSpeed(obj)
  return math.sqrt(obj.vx^2 + obj.vy^2)
end

function physics.getPosition(obj)
  return obj.x, obj.y
end

function physics.getRadius(obj)
  return obj.r
end

function physics.checkCollisionWithPlayers(obj, players, activePlayer)
  for _, p in pairs(players) do
    if p ~= activePlayer then
      if physics.checkCollisionWithCircle(obj, p.x, p.y, PLAYER_RADIUS) then
        return p
      end
    end
  end
  return nil
end

function physics.checkCollisionWithBuildings(obj, buildings)
  for i = 1, #buildings do
    local bx = buildings[i].x
    local bw = (buildings[i+1] and buildings[i+1].x or 1280) - bx
    local by = buildings[i].y
    local bh = 720-by
    if physics.checkCollisionWithRect(obj, bx, by, bw, bh) then
      return buildings[i]
    end
  end
  return nil
end

function physics.isOutOfBounds(obj)
  return obj.x-obj.r < -100 or obj.x+obj.r > 1380
end

return physics