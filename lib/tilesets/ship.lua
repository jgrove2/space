local GridRenderer = require("lib.grid_renderer")

local ShipTileset = {}

ShipTileset.CHAR_TO_GLYPH = {
    ["#"] = "█", ["@"] = "▓", ["."] = "░",
    ["/"] = "╱", ["\\"] = "╲",
    ["="] = "═", ["|"] = "║", ["-"] = "─", ["!"] = "│",
    ["+"] = "┼", ["~"] = "~",
    ["["] = "╔", ["]"] = "╗", ["{"] = "╚", ["}"] = "╝",
    ["o"] = "O", ["*"] = "◆",
    ["v"] = "▼", ["^"] = "▲", ["<"] = "◄", [">"] = "►",
    ["A"] = "A", ["C"] = "C",
    ["S"] = "◈", ["E"] = "⊞",
}

ShipTileset.CHAR_DEFAULTS = {
    ["█"] = "a", ["▓"] = "a", ["░"] = "e",
    ["╱"] = "b", ["╲"] = "b",
    ["═"] = "a", ["║"] = "a", ["─"] = "b", ["│"] = "b",
    ["╔"] = "a", ["╗"] = "a", ["╚"] = "a", ["╝"] = "a",
    ["┼"] = "b", ["~"] = "h",
    ["O"] = "c", ["◆"] = "h",
    ["▼"] = "f", ["▲"] = "f", ["◄"] = "f", ["►"] = "f",
    ["A"] = "c",
    ["C"] = "g",
    ["◈"] = "h",
    ["⊞"] = "f",
}

ShipTileset.CHAR_TYPE = {
    ["#"] = "hull",      ["."] = "deck",
    ["/"] = "slant_se",  ["\\"] = "slant_sw",
    ["="] = "hwall",     ["|"] = "vwall",
    ["-"] = "hpanel",    ["!"] = "vpanel",
    ["+"] = "junction",  ["~"] = "conduit",
    ["["] = "corner_tl", ["]"] = "corner_tr",
    ["{"] = "corner_bl", ["}"] = "corner_br",
    ["o"] = "window",    ["*"] = "console",
    ["v"] = "thruster_d", ["^"] = "thruster_u",
    ["<"] = "thruster_l", [">"] = "thruster_r",
    ["A"] = "airlock",   ["C"] = "captain",
    ["S"] = "shield",    ["E"] = "engine",
}

ShipTileset.CHAR_TO_SHAPE = {
    ["#"] = "fill_rect", ["@"] = "fill_rect", ["."] = "fill_rect",
    ["/"] = "tri_br",    ["\\"] = "tri_bl",
    ["="] = "hbar",      ["|"] = "vbar",     ["-"] = "hbar",     ["!"] = "vbar",
    ["["] = "corner_tl", ["]"] = "corner_tr",
    ["{"] = "corner_bl", ["}"] = "corner_br",
    ["+"] = "junction",
}

ShipTileset.THRUSTER_CHARS = {
    ["v"] = "down", ["^"] = "up",
    ["<"] = "left", [">"] = "right",
}

ShipTileset.INTERACTABLE_CHARS = {
    ["A"] = "airlock",
    ["C"] = "captain",
    ["S"] = "shield",
    ["E"] = "engine",
}

ShipTileset.WALKABLE_CHARS = {
    ["."] = true,
    ["A"] = true,
    ["C"] = true,
    ["*"] = true,
    ["~"] = true,
    ["S"] = true,
    ["E"] = true,
    ["o"] = true,
}

function ShipTileset.autoDetectThrusters(data_rows)
    local thrusters = {}
    for row, line in ipairs(data_rows) do
        local chars = GridRenderer.splitChars(line)
        for ci, char in ipairs(chars) do
            local dir = ShipTileset.THRUSTER_CHARS[char]
            if dir then
                thrusters[#thrusters + 1] = {
                    row      = row,
                    col      = ci,
                    dir      = dir,
                    active   = true,
                    throttle = 1.0,
                }
            end
        end
    end
    return thrusters
end

function ShipTileset.scanInteractables(ext_rows, int_rows)
    local interactables = {}

    local function scan(rows, layer)
        for row, line in ipairs(rows) do
            local chars = GridRenderer.splitChars(line)
            for ci, char in ipairs(chars) do
                local kind = ShipTileset.INTERACTABLE_CHARS[char]
                if kind then
                    interactables[#interactables + 1] = {
                        kind  = kind,
                        row   = row,
                        col   = ci,
                        layer = layer,
                    }
                end
            end
        end
    end

    scan(ext_rows, "exterior")
    if int_rows then scan(int_rows, "interior") end

    return interactables
end

function ShipTileset.buildCollisionGrid(data_rows)
    local collision = {}
    for row, line in ipairs(data_rows) do
        collision[row] = {}
        local chars = GridRenderer.splitChars(line)
        for col, char in ipairs(chars) do
            collision[row][col] = ShipTileset.WALKABLE_CHARS[char] or false
        end
    end
    return collision
end

return ShipTileset
