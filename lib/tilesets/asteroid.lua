local GridRenderer = require("lib.grid_renderer")

local AsteroidTileset = {}

AsteroidTileset.CHAR_TO_GLYPH = {
    ["%"] = "▓",
    ["o"] = "O",
    ["*"] = "◆",
}

AsteroidTileset.CHAR_DEFAULTS = {
    ["▓"] = "b",
    ["O"] = "k",
    ["◆"] = "h",
}

AsteroidTileset.CHAR_TYPE = {
    ["%"] = "rock",
    ["o"] = "ore",
    ["*"] = "crystal",
}

AsteroidTileset.CHAR_TO_SHAPE = {
    ["%"] = "fill_rect",
}

AsteroidTileset.INTERACTABLE_CHARS = {
    ["o"] = "ore",
}

AsteroidTileset.WALKABLE_CHARS = {}

function AsteroidTileset.buildCollisionGrid(data_rows)
    local collision = {}
    for row, line in ipairs(data_rows) do
        collision[row] = {}
        local chars = GridRenderer.splitChars(line)
        for col, char in ipairs(chars) do
            collision[row][col] = AsteroidTileset.WALKABLE_CHARS[char] or false
        end
    end
    return collision
end

function AsteroidTileset.scanInteractables(data_rows)
    local interactables = {}
    for row, line in ipairs(data_rows) do
        local chars = GridRenderer.splitChars(line)
        for ci, char in ipairs(chars) do
            local kind = AsteroidTileset.INTERACTABLE_CHARS[char]
            if kind then
                interactables[#interactables + 1] = {
                    kind  = kind,
                    row   = row,
                    col   = ci,
                    layer = "exterior",
                }
            end
        end
    end
    return interactables
end

return AsteroidTileset