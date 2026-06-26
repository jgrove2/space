local GridRenderer   = require("lib.grid_renderer")
local GridBodyBuilder = require("lib.grid_body")
local AsteroidTileset = require("lib.tilesets.asteroid")

local function trimBlankRows(rows)
    if #rows == 0 then return rows end
    local first, last = 1, #rows
    while first <= last and not rows[first]:match("%S") do
        first = first + 1
    end
    while last >= first and not rows[last]:match("%S") do
        last = last - 1
    end
    if first > last then return {} end
    local out = {}
    for i = first, last do
        out[#out + 1] = rows[i]
    end
    return out
end

local function parseAsteroidFile(path)
    local content = love.filesystem.read(path)
    if not content then
        error("Could not read asteroid file: " .. path)
    end

    local data = {
        name      = "Asteroid",
        font_size = 24,
        palette   = {},
        exterior  = {},
        colors_exterior = {},
    }

    local section = nil

    for raw_line in content:gmatch("[^\r\n]+") do
        local trimmed = raw_line:match("^%s*(.-)%s*$")

        if trimmed:match("^%[.+%]$") then
            section = trimmed:lower():match("^%[(.+)%]$")

        elseif section == "exterior" then
            table.insert(data.exterior, raw_line)

        elseif trimmed == "" or trimmed:match("^%-%-") then

        elseif section == "palette" then
            local k, r, g, b = trimmed:match(
                "^(%w)=([%d.%-]+),([%d.%-]+),([%d.%-]+)$")
            if k then
                data.palette[k] = {
                    tonumber(r), tonumber(g), tonumber(b)
                }
            end

        elseif section == "colors_exterior" then
            local r, c, k = trimmed:match("^(%d+),(%d+),(%a)$")
            if r and c and k then
                local rn = tonumber(r)
                local cn = tonumber(c)
                data.colors_exterior[rn] = data.colors_exterior[rn] or {}
                data.colors_exterior[rn][cn] = k
            end

        elseif section == nil then
            if trimmed:match("^name:") then
                data.name = trimmed:match("^name:%s*(.+)$")
            elseif trimmed:match("^font_size:") then
                data.font_size = tonumber(
                    trimmed:match("^font_size:%s*(%d+)$")) or 24
            end
        end
    end

    data.exterior = trimBlankRows(data.exterior)

    return data
end

local Asteroid = {}

function Asteroid.spawn(world, path, x, y, angle)
    local data = parseAsteroidFile(path)
    local reg  = world.registry
    local fs   = data.font_size

    local palette = {}
    for k, v in pairs(GridRenderer.DEFAULT_COLORS) do
        palette[k] = { v[1], v[2], v[3] }
    end
    for k, v in pairs(data.palette) do
        palette[k] = v
    end

    local layers = GridBodyBuilder.build(data, palette, fs, AsteroidTileset)

    local entity_id = reg:addEntity()

    reg:addComponent(entity_id, "transform", {
        x = x, y = y, angle = angle or 0, scale = 1,
    })

    reg:addComponent(entity_id, "grid_body", {
        layers       = layers,
        active_layer = "exterior",
        font_size    = fs,
        bounds       = {
            w = layers.exterior.pixel_w,
            h = layers.exterior.pixel_h,
        },
    })

    local interactables = AsteroidTileset.scanInteractables(data.exterior)
    reg:addComponent(entity_id, "interactables", interactables)

    return entity_id
end

return Asteroid