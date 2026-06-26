local Transform = require("lib.transform")

local CameraSystem = {}

function CameraSystem.update(dt, world)
    local reg = world.registry

    local tx, ty
    if world.piloting_ship then
        local ship_xf = reg:getComponent(world.piloting_ship, "transform")
        local gb = reg:getComponent(world.piloting_ship, "grid_body")
        if ship_xf and gb then
            local layer = gb.layers[gb.active_layer]
            if layer then
                tx, ty = Transform._center(ship_xf, layer)
            end
        end
    elseif world.player_id then
        local xf = reg:getComponent(world.player_id, "transform")
        if xf then
            tx = xf.x
            ty = xf.y
        end
    end

    if tx and world.camera then
        world.camera:follow({ x = tx, y = ty }, dt)
    end
end

return CameraSystem
