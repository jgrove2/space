-- lib/player.lua
local Player = {}
Player.__index = Player

function Player.new(x, y, font_size)
    return setmetatable({
        x          = x,
        y          = y,
        speed      = 300,
        size       = font_size or 24,
        inside_ship = nil, -- reference to ship entity player is inside, or nil
    }, Player)
end

function Player:update(dt)
    local s = self.speed * dt
    if love.keyboard.isDown("w") or love.keyboard.isDown("up")    then self.y = self.y - s end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down")  then self.y = self.y + s end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left")  then self.x = self.x - s end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then self.x = self.x + s end
end

function Player:draw()
    local hs = self.size / 2

    -- Outer glow
    love.graphics.setColor(0.30, 0.80, 1.00, 0.25)
    love.graphics.rectangle("fill",
        self.x - hs * 2, self.y - hs * 2,
        self.size * 2,   self.size * 2)

    -- Inner body
    love.graphics.setColor(0.30, 0.80, 1.00, 0.9)
    love.graphics.rectangle("fill",
        self.x - hs, self.y - hs,
        self.size,   self.size)
end

function Player:getPosition()
    return { x = self.x, y = self.y }
end

return Player