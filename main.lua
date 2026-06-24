-- main.lua
local World        = require("lib.world")
local Camera       = require("lib.camera")
local Starfield    = require("lib.starfield")
local ShipRenderer = require("lib.ship_renderer")

local W, H    = 1920, 1080
local canvas
local world
local camera
local starfield
local dt_last  = 0
local scale    = 1
local ox, oy   = 0, 0

function love.load()
    canvas    = love.graphics.newCanvas(W, H)
    world     = World.new()
    camera    = Camera.new(W, H)
    starfield = Starfield.new(400, W, H)
    love.graphics.setBackgroundColor(0, 0, 0)
end

function love.update(dt)
    dt_last = dt
    world:update(dt)
    camera:follow(world:getPlayerPosition(), dt)
end

function love.draw()
    -- ── Render world to canvas ────────────────────────────────────────────
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)

    starfield:draw(camera, W, H)

    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)
    world:draw(dt_last)
    love.graphics.pop()

    love.graphics.setCanvas()

    -- ── Blit canvas to screen ─────────────────────────────────────────────
    local sw, sh = love.graphics.getDimensions()
    scale        = math.min(sw / W, sh / H)
    local vw, vh = W * scale, H * scale
    ox           = (sw - vw) / 2
    oy           = (sh - vh) / 2

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, ox, oy, 0, scale, scale)

    -- ── Screen-space UI (drawn after canvas blit) ─────────────────────────
    ShipRenderer.drawInteractionPrompt(
        world:getInteraction(),
        world.player,
        camera,
        scale, ox, oy,
        W, H
    )
end

function love.keypressed(key)
    if key == "f11" then
        love.window.setFullscreen(
            not love.window.getFullscreen(), "desktop")
    end
    world:keypressed(key)
end

function love.resize() end