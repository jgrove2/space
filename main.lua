local Config       = require("lib.config")
local World        = require("lib.world")
local Starfield    = require("lib.starfield")
local ShipRenderer = require("lib.ship_renderer")

local canvas
local world
local camera
local starfield
local scale    = 1
local ox, oy   = 0, 0

function love.load()
    canvas    = love.graphics.newCanvas(Config.W, Config.H)
    world     = World.new()
    starfield = Starfield.new(Config.star_count, Config.W, Config.H)
end

function love.update(dt)
    world:update(dt)
end

local function drawWorldToCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)

    starfield:draw(world.camera, Config.W, Config.H)

    love.graphics.push()
    love.graphics.translate(-world.camera.x, -world.camera.y)
    world:draw()
    love.graphics.pop()

    love.graphics.setCanvas()
end

local function blitCanvas()
    local sw, sh = love.graphics.getDimensions()
    scale        = math.min(sw / Config.W, sh / Config.H)
    local vw, vh = Config.W * scale, Config.H * scale
    ox           = (sw - vw) / 2
    oy           = (sh - vh) / 2

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, ox, oy, 0, scale, scale)
end

local function drawUI()
    local prompt = world.interaction_prompt
    if prompt and world.player_id then
        local reg = world.registry
        local xf  = reg:getComponent(world.player_id, "transform")
        if xf then
            ShipRenderer.drawInteractionPrompt(
                prompt, xf.x, xf.y, world.camera,
                scale, ox, oy, Config.W, Config.H)
        end
    end
end

function love.draw()
    drawWorldToCanvas()
    blitCanvas()
    drawUI()
end

function love.keypressed(key)
    if key == "f11" then
        love.window.setFullscreen(
            not love.window.getFullscreen(), "desktop")
    end
    world:keypressed(key)
end

function love.resize() end
