local Config    = require("lib.config")
local Transform = require("lib.transform")

local PilotSystem = {}

function PilotSystem.update(dt, world)
    local ship_id = world.piloting_ship
    if not ship_id then return end

    local reg = world.registry
    local xf = reg:getComponent(ship_id, "transform")
    if not xf then return end

    local gb = reg:getComponent(ship_id, "grid_body")
    if not gb then return end
    local layer = gb.layers[gb.active_layer or "exterior"]
    if not layer then return end

    local cx, cy = Transform._center(xf, layer)

    local sw, sh = love.graphics.getDimensions()
    local canvas_scale = math.min(sw / Config.W, sh / Config.H)
    local vw, vh = Config.W * canvas_scale, Config.H * canvas_scale
    local ox = (sw - vw) / 2
    local oy = (sh - vh) / 2

    local mx, my = love.mouse.getPosition()
    local wx, wy = world.camera:screenToWorld(mx, my, canvas_scale, ox, oy)
    local target_angle = math.atan2(wy - cy, wx - cx)

    local rotate_speed = math.rad(180)

    if love.keyboard.isDown("q") then
        xf.angle = xf.angle - rotate_speed * dt
    elseif love.keyboard.isDown("e") then
        xf.angle = xf.angle + rotate_speed * dt
    else
        local diff = target_angle - xf.angle
        diff = math.atan2(math.sin(diff), math.cos(diff))
        local max_step = rotate_speed * dt
        if math.abs(diff) > max_step then
            diff = (diff > 0 and 1 or -1) * max_step
        end
        xf.angle = xf.angle + diff
    end

    local vel = reg:getComponent(ship_id, "velocity")
    if vel then
        local thrust = 0
        if love.keyboard.isDown("w") then
            thrust = 200
        elseif love.keyboard.isDown("s") then
            thrust = -100
        end

        local fx = math.cos(xf.angle)
        local fy = math.sin(xf.angle)
        vel.vx = fx * thrust
        vel.vy = fy * thrust
        vel.vθ = 0
    end
end

return PilotSystem
