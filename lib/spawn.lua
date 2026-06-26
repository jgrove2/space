local Ship     = require("lib.ship")
local Asteroid = require("lib.asteroid")

local Spawn = {}

local CATALOG = {
    ship     = Ship.spawn,
    asteroid = Asteroid.spawn,
}

function Spawn.spawn(world, type, source, x, y, angle)
    local loader = CATALOG[type]
    if not loader then
        error("Unknown object type: " .. tostring(type))
    end
    return loader(world, source, x, y, angle)
end

function Spawn.registerType(type, loader)
    CATALOG[type] = loader
end

return Spawn
