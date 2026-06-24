-- lib/ship_renderer.lua
local ShipRenderer = {}

function ShipRenderer.update(ship, dt)
    ship.thruster_time = (ship.thruster_time or 0) + dt
end

function ShipRenderer.drawWorld(ship, sx, sy, dt)
    if ship.mode == "interior" and ship.int_canvas then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(ship.int_canvas, sx, sy)
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(ship.ext_canvas, sx, sy)
        ShipRenderer.drawThrusters(ship, sx, sy)
    end
end

function ShipRenderer.drawThrusters(ship, sx, sy)
    if #ship.thrusters == 0 then return end
    local t  = ship.thruster_time or 0
    local fs = ship.font_size
    for _, thr in ipairs(ship.thrusters) do
        if thr.active then
            ShipRenderer._drawFlame(thr, t, fs, sx, sy)
        end
    end
end

function ShipRenderer._drawFlame(thr, t, fs, sx, sy)
    local row, col, dir = thr.row, thr.col, thr.dir
    local throttle       = thr.throttle or 1.0
    local cx = sx + (col - 1) * fs + fs / 2
    local cy = sy + (row - 1) * fs + fs / 2

    local flicker = math.sin(t * 18 + row * 3.1 + col * 7.3) * 0.15 + 0.85
    local len     = math.max(2, math.floor(
        (2 + throttle * 4) +
        math.sin(t * 9 + row * 5 + col * 3) * 1.2
    ))

    love.graphics.setColor(1.0, 0.45, 0.05, 0.18 * flicker * throttle)
    love.graphics.circle("fill", cx, cy, fs * 0.9 * throttle)

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

        local hw = (fs * 0.4) * (1.0 - frac * 0.95)

        if dir == "down" then
            local py = cy + (i - 1) * fs * 0.52
            love.graphics.polygon("fill",
                cx + wobble,      py,
                cx - hw + wobble, py + fs * 0.5,
                cx + hw + wobble, py + fs * 0.5)
        elseif dir == "up" then
            local py = cy - (i - 1) * fs * 0.52
            love.graphics.polygon("fill",
                cx + wobble,      py,
                cx - hw + wobble, py - fs * 0.5,
                cx + hw + wobble, py - fs * 0.5)
        elseif dir == "left" then
            local px = cx - (i - 1) * fs * 0.52
            love.graphics.polygon("fill",
                px,             cy + wobble,
                px - fs * 0.5, cy - hw + wobble,
                px - fs * 0.5, cy + hw + wobble)
        elseif dir == "right" then
            local px = cx + (i - 1) * fs * 0.52
            love.graphics.polygon("fill",
                px,             cy + wobble,
                px + fs * 0.5, cy - hw + wobble,
                px + fs * 0.5, cy + hw + wobble)
        end
    end
end

function ShipRenderer.drawMinimap(ship, screen_x, screen_y, scale,
                                   player_wx, player_wy)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.draw(ship.ext_canvas, screen_x, screen_y, 0, scale, scale)
    local lx    = player_wx - ship.x
    local ly    = player_wy - ship.y
    local dot_x = screen_x + lx * scale
    local dot_y = screen_y + ly * scale
    love.graphics.setColor(0.3, 1.0, 0.3)
    love.graphics.circle("fill", dot_x, dot_y, 3)
end

function ShipRenderer.drawHUD(ship, screen_x, screen_y)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print(ship.name, screen_x, screen_y)
    love.graphics.print(
        "MODE: " .. ship.mode:upper(),
        screen_x, screen_y + 18)
    local thr = ship.thrusters[1]
    if thr then
        local bw       = 80
        local throttle = thr.throttle or 1.0
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", screen_x, screen_y + 40, bw, 6)
        love.graphics.setColor(1.0, 0.45, 0.05)
        love.graphics.rectangle("fill",
            screen_x, screen_y + 40, bw * throttle, 6)
    end
end

-- ── Interaction prompt ────────────────────────────────────────────────────
--
-- Call this in screen space (after love.graphics.setCanvas() is reset),
-- passing the interaction system from world and the canvas scale/offset
-- so the prompt can be positioned near the player in screen space.

function ShipRenderer.drawInteractionPrompt(
    interaction, player, camera, canvas_scale, ox, oy, W, H)

    local prompt = interaction.prompt
    if not prompt then return end

    -- Convert player world pos to canvas pos then to screen pos
    local cx = (player.x - camera.x) * canvas_scale + ox
    local cy = (player.y - camera.y) * canvas_scale + oy

    local font     = love.graphics.getFont()
    local tw       = font:getWidth(prompt)
    local th       = font:getHeight()
    local pad      = 6
    local bw       = tw + pad * 2
    local bh       = th + pad * 2
    local bx       = cx - bw / 2
    local by       = cy - 48 * canvas_scale -- float above player

    -- Background pill
    love.graphics.setColor(0.08, 0.08, 0.12, 0.88)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)

    -- Border
    love.graphics.setColor(0.30, 0.80, 1.00, 0.6)
    love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)

    -- Text
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(prompt, bx + pad, by + pad)
end

return ShipRenderer