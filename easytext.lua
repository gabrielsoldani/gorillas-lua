local cores = {
  black = {0, 0, 0},
  white = {1, 1, 1},
  red =  {1, 0, 0},
  green =  {0.13, 0.47, 0.18},
  light_green = {0.15, 0.75, 0.25},
  blue =  {0.25, 0.1, 0.85},
  light_blue = {0.1, 0.7, 0.85}
}

local ancoras = {
  -- valores válidos para ancoras:
  no = true,
  n = true,
  ne = true,
  o = true,
  c = true,
  e = true,
  so = true,
  s = true,
  se = true
}

local easytext = {}

easytext.new = function (fontname, tam, str)
  local meutexto = {}
  local fonte
  if type(fontname) == "string" then
    fonte = love.graphics.newFont(fontname .. ".ttf", tam)
  else
    -- se não houver fontname, assume que o usuário passou só o tamanho e quer
    -- a fonte padrão
    tam, str = fontname, tam
    fonte = love.graphics.newFont(tam)
  end
  local textoLove = love.graphics.newText(fonte, str)
  meutexto.textoLove = textoLove
  meutexto.cor = cores.black
  return meutexto
end


easytext.setString = function (meutexto, str)
  meutexto.textoLove:set(str)
end

easytext.setColor = function (meutexto, cor1, cor2, cor3)
  if type(cor1) == "string" then
    -- verifica se passou uma cor válida
    assert (cores[cor1], "cor inexistente")
    meutexto.cor = cores[cor1]
  else
    -- assumo que passou diretamente uma tripla rgb
    meutexto.cor = {cor1, cor2, cor3}
  end
end

easytext.setLineColor = function (meutexto, cor1, cor2, cor3)
  if type(cor1) == "nil" then
    -- assumo que quer remover a linha
    meutexto.corLine = nil
  elseif type(cor1) == "string" then
    -- verifica se passou uma cor válida
    assert (cores[cor1], "cor inexistente")
    meutexto.corLine = cores[cor1]
  else
    -- assumo que passou diretamente uma tripla rgb
    meutexto.corLine = {cor1, cor2, cor3}
  end
end

easytext.getDimensions = function (meutexto)
  local w, h =  meutexto.textoLove:getDimensions()
  return w, h
end

easytext.getTopLeft = function (meutexto, x, y, ancora)
  ancora = ancora or "c"
  assert (ancoras[ancora], "ancora inexistente")
  
  local w, h = easytext.getDimensions(meutexto)
  
  if ancora == "no" then
    -- nada
  elseif ancora == "n" then
    x = x - (w / 2)
  elseif ancora == "ne" then
    x = x - w
  elseif ancora == "o" then
    y = y - (h / 2)
  elseif ancora == "c" then
    x = x - (w / 2)
    y = y - (h / 2)
  elseif ancora == "e" then
    x = x - w
    y = y - (h / 2)
  elseif ancora == "so" then
    y = y - h
  elseif ancora == "s" then
    x = x - (w / 2)
    y = y - h
  elseif ancora == "se" then
    x = x - w
    y = y - h
  end
  
  return math.floor(x), math.floor(y)
end

easytext.draw = function (meutexto, x, y, ancora)
  local w, h = easytext.getDimensions(meutexto)
  local novox, novoy = easytext.getTopLeft(meutexto, x, y, ancora)
  
  if meutexto.corLine then
    love.graphics.setColor(meutexto.corLine)
    love.graphics.rectangle('line', novox, novoy, w, h)
  end
  
  love.graphics.setColor(meutexto.cor)
  love.graphics.draw(meutexto.textoLove, novox, novoy)
end

return easytext
