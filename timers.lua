local timers = {}

function timers.new(t, cb)
  return {
    t = t,
    cb = cb,
    expired = false
  }
end

function timers.update(tmr, dt)
  if not tmr or tmr.expired then return end

  tmr.t = tmr.t - dt
  if tmr.t <= 0 then
    tmr.expired = true
    tmr.cb()
  end
end

return timers