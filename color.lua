local color = {}

function color.tostring(c)
  return string.format(
    "%02x%02x%02x",
    math.floor(c[1] * 255),
    math.floor(c[2] * 255),
    math.floor(c[3] * 255)
  )
end

function color.totable(s)
  local r, g, b = string.match(s, "(%x%x)(%x%x)(%x%x)")
  return {
    tonumber(r, 16) / 255,
    tonumber(g, 16) / 255,
    tonumber(b, 16) / 255
  }
end

function color.random()
  return {
    math.random(),
    math.random(),
    math.random()
  }
end

return color
