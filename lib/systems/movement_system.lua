local MovementSystem = {}

function MovementSystem.update(dt, world)
    local reg = world.registry
    for _, id in ipairs(reg:query("transform", "velocity")) do
        local xf  = reg:getComponent(id, "transform")
        local vel = reg:getComponent(id, "velocity")
        xf.x = xf.x + vel.vx * dt
        xf.y = xf.y + vel.vy * dt
        xf.angle = xf.angle + (vel.vθ or 0) * dt
    end
end

return MovementSystem
