local chars = "abcdefghijklmnopqrstuvwxyz"

local function randomChar()
  local index = math.random(#chars)
  return string.sub(chars, index, index)
end

return function (s)
  return string.gsub(s, "%?", randomChar)
end