local Transform = require("lib.transform")

local CollisionSystem = {}

local function findOverlapCell(cx, cy, hs, fs, collision, grid_w, grid_h)
    local minCol = math.max(1, math.floor((cx - hs) / fs) + 1)
    local maxCol = math.min(grid_w, math.floor((cx + hs - 0.001) / fs) + 1)
    local minRow = math.max(1, math.floor((cy - hs) / fs) + 1)
    local maxRow = math.min(grid_h, math.floor((cy + hs - 0.001) / fs) + 1)
    for r = minRow, maxRow do
        local rowData = collision[r]
        if rowData then
            for c = minCol, maxCol do
                if not rowData[c] then
                    return true, r, c
                end
            end
        end
    end
    return false
end

function CollisionSystem.update(dt, world)
    local reg = world.registry

    for _, eid in ipairs(reg:query("contained_in", "transform", "collider")) do
        local contained = reg:getComponent(eid, "contained_in")
        local xf = reg:getComponent(eid, "transform")

        local gb = reg:getComponent(contained.ship_id, "grid_body")
        if not gb then goto continue end

        local layer = gb.layers[contained.layer]
        if not layer or not layer.collision then goto continue end

        local ship_xf = reg:getComponent(contained.ship_id, "transform")
        if not ship_xf then goto continue end

        local fs = gb.font_size or 24
        local hs = fs / 2

        local lx, ly = Transform.worldToLocal(ship_xf, layer, xf.x, xf.y)

        local gx = lx + layer.pixel_w / 2
        local gy = ly + layer.pixel_h / 2

        gx = math.max(hs, math.min(layer.pixel_w - hs, gx))
        gy = math.max(hs, math.min(layer.pixel_h - hs, gy))

        local blocked, br, bc = findOverlapCell(gx, gy, hs, fs, layer.collision, layer.grid_w, layer.grid_h)
        if blocked then
            local cellLeft = (bc - 1) * fs
            local cellRight = bc * fs
            local overlapLeft = gx + hs - cellLeft
            local overlapRight = cellRight - (gx - hs)
            if overlapLeft < overlapRight then
                gx = cellLeft - hs
            else
                gx = cellRight + hs
            end
            gx = math.max(hs, math.min(layer.pixel_w - hs, gx))

            local blocked_y, br2 = findOverlapCell(gx, gy, hs, fs, layer.collision, layer.grid_w, layer.grid_h)
            if blocked_y then
                local cellTop = (br2 - 1) * fs
                local cellBottom = br2 * fs
                local overlapTop = gy + hs - cellTop
                local overlapBottom = cellBottom - (gy - hs)
                if overlapTop < overlapBottom then
                    gy = cellTop - hs
                else
                    gy = cellBottom + hs
                end
                gy = math.max(hs, math.min(layer.pixel_h - hs, gy))
            end
        end

        local outLx = gx - layer.pixel_w / 2
        local outLy = gy - layer.pixel_h / 2
        local wx, wy = Transform.localToWorld(ship_xf, layer, outLx, outLy)
        xf.x, xf.y = wx, wy

        ::continue::
    end
end

return CollisionSystem
