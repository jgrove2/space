local ShipRenderer = require("lib.ship_renderer")
local Transform   = require("lib.transform")

local RenderSystem = {}

function RenderSystem.draw(world)
    local reg = world.registry

    local player_contained
    if world.player_id then
        player_contained = reg:getComponent(world.player_id, "contained_in")
    end
    if player_contained then
        local gb = reg:getComponent(player_contained.ship_id, "grid_body")
        if gb then
            local layer = gb.layers[player_contained.layer]
            if layer then
                local ship_xf = reg:getComponent(player_contained.ship_id, "transform")
                if ship_xf then
                    local cx, cy = Transform._center(ship_xf, layer)
                    love.graphics.setColor(0.12, 0.12, 0.18, 1)
                    love.graphics.rectangle("fill",
                        cx - 4000, cy - 4000, 8000, 8000)
                end
            end
        end
    end

    for _, id in ipairs(reg:query("transform", "grid_body")) do
        local xf = reg:getComponent(id, "transform")
        local gb = reg:getComponent(id, "grid_body")

        local active_layer = gb.active_layer or "exterior"
        local layer = gb.layers[active_layer]
        if layer and layer.canvas then
            local cx, cy = Transform._center(xf, layer)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(layer.canvas, cx, cy, xf.angle or 0,
                1, 1, layer.pixel_w / 2, layer.pixel_h / 2)
        end

        if active_layer == "exterior" then
            local ss = reg:getComponent(id, "ship_stats")
            if ss and #ss.thrusters > 0 then
                ShipRenderer.drawThrusters(
                    ss.thrusters, ss.thruster_time,
                    xf.x, xf.y, gb.font_size,
                    xf.angle or 0, layer.pixel_w, layer.pixel_h)
            end
        end
    end
end

return RenderSystem
