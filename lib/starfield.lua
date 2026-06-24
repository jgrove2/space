-- lib/starfield.lua
local Starfield = {}
Starfield.__index = Starfield

function Starfield.new(count, W, H)
    local self = setmetatable({ stars = {}, W = W, H = H }, Starfield)
    math.randomseed(42)
    for i = 1, count do
        self.stars[i] = {
            -- Store as fractions so they tile infinitely
            fx          = math.random(),
            fy          = math.random(),
            r           = math.random(1, 2),
            brightness  = math.random(80, 255) / 255,
            parallax    = math.random(20, 80) / 1000, -- 0.02 – 0.08
        }
    end
    return self
end

function Starfield:draw(camera, W, H)
    for _, s in ipairs(self.stars) do
        -- Shift star position by a fraction of the camera offset (parallax)
        local wx = (s.fx * W - camera.x * s.parallax) % W
        local wy = (s.fy * H - camera.y * s.parallax) % H
        love.graphics.setColor(s.brightness, s.brightness, s.brightness)
        love.graphics.circle("fill", wx, wy, s.r)
    end
end

return Starfield