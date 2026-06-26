-- lib/camera.lua
local Config = require("lib.config")

local Camera = {}
Camera.__index = Camera

function Camera.new(W, H)
    return setmetatable({
        x = 0, y = 0,
        W = W, H = H,
        lerp_speed = Config.camera_lerp_speed,
    }, Camera)
end

function Camera:follow(target, dt)
    local tx = target.x - self.W / 2
    local ty = target.y - self.H / 2
    local t  = math.min(dt * self.lerp_speed, 1)
    self.x   = self.x + (tx - self.x) * t
    self.y   = self.y + (ty - self.y) * t
end

-- Convert screen coords to world coords
function Camera:screenToWorld(sx, sy, canvas_scale, ox, oy)
    local cx = (sx - ox) / canvas_scale + self.x
    local cy = (sy - oy) / canvas_scale + self.y
    return cx, cy
end

return Camera