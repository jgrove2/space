local ShipRenderer = {}

function ShipRenderer.drawThrusters(thrusters, thruster_time, sx, sy, font_size, angle, pw, ph)
    if #thrusters == 0 then return end
    local t  = thruster_time or 0
    local fs = font_size
    local cx = sx + pw / 2
    local cy = sy + ph / 2

    for _, thr in ipairs(thrusters) do
        if thr.active then
            ShipRenderer._drawFlame(thr, t, fs, cx, cy, angle, pw, ph)
        end
    end
end

function ShipRenderer._drawFlame(thr, t, fs, cx, cy, angle, pw, ph)
    local row, col, dir = thr.row, thr.col, thr.dir
    local throttle = thr.throttle or 1.0

    local lx = (col - 1) * fs + fs / 2
    local ly = (row - 1) * fs + fs / 2
    local rlx = lx - pw / 2
    local rly = ly - ph / 2

    local flicker = math.sin(t * 18 + row * 3.1 + col * 7.3) * 0.15 + 0.85
    local len = math.max(2, math.floor(
        (2 + throttle * 4) +
        math.sin(t * 9 + row * 5 + col * 3) * 1.2
    ))

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle or 0)

    love.graphics.setColor(1.0, 0.45, 0.05, 0.18 * flicker * throttle)
    love.graphics.circle("fill", rlx, rly, fs * 0.9 * throttle)

    for i = 1, len do
        local frac      = (i - 1) / math.max(len - 1, 1)
        local intensity = (1.0 - frac * 0.9) * flicker * throttle
        local wobble    = math.sin(t * 14 + i * 2.3 + col * 1.7) * (fs * 0.08)

        local cr, cg, cb
        if frac < 0.5 then
            local f2 = frac * 2
            cr = 1.0
            cg = 0.95 - f2 * 0.50
            cb = 0.60 - f2 * 0.55
        else
            local f2 = (frac - 0.5) * 2
            cr = 1.0  - f2 * 0.30
            cg = 0.45 - f2 * 0.40
            cb = 0.05
        end
        love.graphics.setColor(
            cr * intensity, cg * intensity, cb * intensity)

        local hw   = (fs * 0.4) * (1.0 - frac * 0.95)
        local dist = (i - 1) * fs * 0.52

        if dir == "down" then
            love.graphics.polygon("fill",
                rlx + wobble,      rly + dist,
                rlx - hw + wobble, rly + dist + fs * 0.5,
                rlx + hw + wobble, rly + dist + fs * 0.5)
        elseif dir == "up" then
            love.graphics.polygon("fill",
                rlx + wobble,      rly - dist,
                rlx - hw + wobble, rly - dist - fs * 0.5,
                rlx + hw + wobble, rly - dist - fs * 0.5)
        elseif dir == "left" then
            love.graphics.polygon("fill",
                rlx - dist,             rly + wobble,
                rlx - dist - fs * 0.5, rly - hw + wobble,
                rlx - dist - fs * 0.5, rly + hw + wobble)
        elseif dir == "right" then
            love.graphics.polygon("fill",
                rlx + dist,             rly + wobble,
                rlx + dist + fs * 0.5, rly - hw + wobble,
                rlx + dist + fs * 0.5, rly + hw + wobble)
        end
    end

    love.graphics.pop()
end

function ShipRenderer.drawInteractionPrompt(
    prompt, px, py, camera, canvas_scale, ox, oy, W, H)

    if not prompt then return end

    local cx = (px - camera.x) * canvas_scale + ox
    local cy = (py - camera.y) * canvas_scale + oy

    local font     = love.graphics.getFont()
    local tw       = font:getWidth(prompt)
    local th       = font:getHeight()
    local pad      = 6
    local bw       = tw + pad * 2
    local bh       = th + pad * 2
    local bx       = cx - bw / 2
    local by       = cy - 48 * canvas_scale

    love.graphics.setColor(0.08, 0.08, 0.12, 0.88)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)

    love.graphics.setColor(0.30, 0.80, 1.00, 0.6)
    love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(prompt, bx + pad, by + pad)
end

return ShipRenderer
