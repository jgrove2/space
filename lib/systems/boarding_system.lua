local Transform = require("lib.transform")

local BoardingSystem = {}

local function findMatchingAirlock(ship_xf, gb, source_tile, target_layer)
    local source_layer = gb.layers[source_tile.layer]
    if not source_layer then return nil end

    local target = gb.layers[target_layer]
    if not target then return nil end

    local fs = gb.font_size

    local sx, sy = Transform.gridRCToWorldCenter(ship_xf, source_layer, fs, source_tile.row, source_tile.col)

    local best, best_dist
    for r, row in pairs(target.tile_map) do
        for c, entry in pairs(row) do
            if entry.char == "A" then
                local crow, ccol = r + 1, c + 1
                local wx, wy = Transform.gridRCToWorldCenter(ship_xf, target, fs, crow, ccol)
                local dx, dy = wx - sx, wy - sy
                local dist = dx * dx + dy * dy
                if not best or dist < best_dist then
                    best = { row = crow, col = ccol }
                    best_dist = dist
                end
            end
        end
    end
    return best
end

local function isTileWalkable(layer, row, col)
    local rowData = layer.collision[row]
    return rowData and rowData[col] == true
end

local function findNearestWalkable(layer, start_row, start_col, max_radius)
    for radius = 0, max_radius do
        for dr = -radius, radius do
            for dc = -radius, radius do
                local r, c = start_row + dr, start_col + dc
                if r >= 1 and r <= layer.grid_h and c >= 1 and c <= layer.grid_w then
                    if isTileWalkable(layer, r, c) then
                        return { row = r, col = c }
                    end
                end
            end
        end
    end
    return { row = start_row, col = start_col }
end

local function getOutwardDirection(tile_map, dest_row, dest_col, grid_w, grid_h)
    local dirs = {
        { dr = -1, dc = 0,  name = "up" },
        { dr = 1,  dc = 0,  name = "down" },
        { dr = 0,  dc = -1, name = "left" },
        { dr = 0,  dc = 1,  name = "right" },
    }

    for _, d in ipairs(dirs) do
        local nr = (dest_row - 1) + d.dr
        local nc = (dest_col - 1) + d.dc
        if nr < 0 or nr >= grid_h or nc < 0 or nc >= grid_w then
            return d.name
        end
        local rdata = tile_map[nr]
        if not rdata or not rdata[nc] then
            return d.name
        end
    end

    for _, d in ipairs(dirs) do
        local nr = (dest_row - 1) + d.dr
        local nc = (dest_col - 1) + d.dc
        if nr >= 0 and nr < grid_h and nc >= 0 and nc < grid_w then
            return d.name
        end
    end
    return "down"
end

function BoardingSystem.update(dt, world)
    local action = world.interaction_action
    if not action then return end
    world.interaction_action = nil

    local reg = world.registry
    local player_id = world.player_id
    if not player_id or not reg:alive(player_id) then return end

    local xf = reg:getComponent(player_id, "transform")
    if not xf then return end

    if action.action == "board" then
        local gb = reg:getComponent(action.ship_id, "grid_body")
        if not gb then return end

        gb.active_layer = "interior"

        local interior = gb.layers["interior"]
        if not interior then return end

        local ship_xf = reg:getComponent(action.ship_id, "transform")
        if not ship_xf then return end

        local dest = findMatchingAirlock(ship_xf, gb, action.tile, "interior")
        if dest then
            local adj = findNearestWalkable(interior, dest.row, dest.col, 3)
            local wx, wy = Transform.gridRCToWorldCenter(ship_xf, interior, gb.font_size, adj.row, adj.col)
            xf.x = wx
            xf.y = wy
        else
            local cx, cy = Transform._center(ship_xf, interior)
            xf.x = cx
            xf.y = cy
        end

        reg:addComponent(player_id, "contained_in", {
            ship_id = action.ship_id,
            layer = "interior",
        })

    elseif action.action == "disembark" then
        local gb = reg:getComponent(action.ship_id, "grid_body")
        if not gb then return end

        gb.active_layer = "exterior"

        local exterior = gb.layers["exterior"]
        if not exterior then return end

        local ship_xf = reg:getComponent(action.ship_id, "transform")
        if not ship_xf then return end

        local dest = findMatchingAirlock(ship_xf, gb, action.tile, "exterior")
        if dest then
            local dir = getOutwardDirection(exterior.tile_map, dest.row, dest.col, exterior.grid_w, exterior.grid_h)
            local adj = findNearestWalkable(exterior, dest.row, dest.col, 2)
            local wx, wy = Transform.gridRCToWorldCenter(ship_xf, exterior, gb.font_size, adj.row, adj.col)
            if dir == "up" then
                wy = wy - gb.font_size
            elseif dir == "down" then
                wy = wy + gb.font_size
            elseif dir == "left" then
                wx = wx - gb.font_size
            elseif dir == "right" then
                wx = wx + gb.font_size
            end
            xf.x = wx
            xf.y = wy
        end

        reg:removeComponent(player_id, "contained_in")

    elseif action.action == "start_pilot" then
        world.piloting_ship = action.ship_id

    elseif action.action == "stop_pilot" then
        world.piloting_ship = nil
    end
end

return BoardingSystem
