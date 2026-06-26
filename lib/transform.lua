local Transform = {}

function Transform._center(xf, layer)
    if xf.origin == "center" then
        return xf.x, xf.y
    end
    return xf.x + layer.pixel_w / 2, xf.y + layer.pixel_h / 2
end

function Transform.worldToLocal(xf, layer, wx, wy)
    local cx, cy = Transform._center(xf, layer)
    local lx = wx - cx
    local ly = wy - cy
    local a = -(xf.angle or 0)
    local c = math.cos(a)
    local s = math.sin(a)
    return lx * c - ly * s, lx * s + ly * c
end

function Transform.localToWorld(xf, layer, lx, ly)
    local cx, cy = Transform._center(xf, layer)
    local a = xf.angle or 0
    local c = math.cos(a)
    local s = math.sin(a)
    local rx = lx * c - ly * s
    local ry = lx * s + ly * c
    return cx + rx, cy + ry
end

function Transform.worldToGridRC(xf, layer, font_size, wx, wy)
    local lx, ly = Transform.worldToLocal(xf, layer, wx, wy)
    lx = lx + layer.pixel_w / 2
    ly = ly + layer.pixel_h / 2
    local col = math.floor(lx / font_size) + 1
    local row = math.floor(ly / font_size) + 1
    return row, col
end

function Transform.gridRCToWorldCenter(xf, layer, font_size, row, col)
    local lx = (col - 1) * font_size + font_size / 2
    local ly = (row - 1) * font_size + font_size / 2
    lx = lx - layer.pixel_w / 2
    ly = ly - layer.pixel_h / 2
    return Transform.localToWorld(xf, layer, lx, ly)
end

return Transform
