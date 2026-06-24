-- lib/ship.lua
local GridRenderer = require("lib.grid_renderer")
local Ship = {}
Ship.__index = Ship

local CHAR_TO_GLYPH = {
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

local CHAR_DEFAULTS = {
    ["█"] = "a", ["▓"] = "b", ["░"] = "e",
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

local CHAR_TYPE = {
    ["#"] = "armor",     ["@"] = "hull",      ["."] = "deck",
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

local CHAR_TO_SHAPE = {
    ["#"] = "fill_rect", ["@"] = "fill_rect", ["."] = "fill_rect",
    ["/"] = "tri_br",    ["\\"] = "tri_bl",
    ["="] = "hbar",      ["|"] = "vbar",     ["-"] = "hbar",     ["!"] = "vbar",
    ["["] = "corner_tl", ["]"] = "corner_tr",
    ["{"] = "corner_bl", ["}"] = "corner_br",
    ["+"] = "junction",
}

local DEFAULT_COLORS = {
    a = {0.55, 0.55, 0.62},
    b = {0.40, 0.40, 0.48},
    c = {0.30, 0.80, 1.00},
    d = {0.50, 0.50, 0.58},
    e = {0.65, 0.65, 0.72},
    f = {0.80, 0.20, 0.20},
    g = {0.20, 0.25, 0.35},
    h = {0.10, 0.50, 0.90},
}

local THRUSTER_CHARS = {
    ["v"] = "down", ["^"] = "up",
    ["<"] = "left", [">"] = "right",
}

local function autoDetectThrusters(data_rows)
    local thrusters = {}
    for row, line in ipairs(data_rows) do
        local chars = GridRenderer.splitChars(line)
        for ci, char in ipairs(chars) do
            local dir = THRUSTER_CHARS[char]
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

local function detectInteractables(ext_rows, int_rows)
    local airlocks       = {}
    local captains_seats = {}
    local shield_gens    = {}
    local engines        = {}

    local function scan(rows, layer)
        for row, line in ipairs(rows) do
            local chars = GridRenderer.splitChars(line)
            for ci, char in ipairs(chars) do
                local entry = { row = row, col = ci, layer = layer }
                if char == "A" then
                    airlocks[#airlocks + 1] = entry
                elseif char == "C" then
                    captains_seats[#captains_seats + 1] = entry
                elseif char == "S" then
                    shield_gens[#shield_gens + 1] = entry
                elseif char == "E" then
                    engines[#engines + 1] = entry
                end
            end
        end
    end

    scan(ext_rows, "exterior")
    if int_rows then scan(int_rows, "interior") end

    return airlocks, captains_seats, shield_gens, engines
end

-- ── Ship.new ──────────────────────────────────────────────────────────────

function Ship.new(data)
    local self     = setmetatable({}, Ship)
    self.name      = data.name      or "Unnamed"
    self.font_size = data.font_size or 24
    self.palette   = {}
    for k, v in pairs(DEFAULT_COLORS) do
        self.palette[k] = { v[1], v[2], v[3] }
    end
    if data.palette then
        for k, v in pairs(data.palette) do
            self.palette[k] = v
        end
    end
    self.mode = "exterior"
    self.x    = 0
    self.y    = 0
    self.type = "ship"

    local renderOpts = {
        char_to_glyph      = CHAR_TO_GLYPH,
        char_to_shape      = CHAR_TO_SHAPE,
        char_to_type       = CHAR_TYPE,
        glyph_to_color_key = CHAR_DEFAULTS,
        default_colors     = DEFAULT_COLORS,
    }

    self.ext_canvas, self.ext_tiles, self.ext_map,
        self.ext_width, self.ext_height,
        self.pixel_w,   self.pixel_h =
            GridRenderer.renderGrid(data.exterior, self.palette, self.font_size, renderOpts)

    if data.interior then
        self.int_canvas, self.int_tiles, self.int_map,
            self.int_width, self.int_height,
            self.int_pixel_w, self.int_pixel_h =
                GridRenderer.renderGrid(data.interior, self.palette, self.font_size, renderOpts)
    end

    if data.thrusters and #data.thrusters > 0 then
        self.thrusters = data.thrusters
        for _, t in ipairs(self.thrusters) do
            t.active   = t.active   ~= false
            t.throttle = t.throttle or 1.0
        end
    else
        self.thrusters = autoDetectThrusters(data.exterior)
    end

    self.airlocks, self.captains_seats,
        self.shield_gens, self.engines =
            detectInteractables(data.exterior, data.interior)

    self.shield_capacity = #self.shield_gens * 50
    self.thrust_bonus    = #self.engines     * 10
    self.thruster_time   = 0

    return self
end

-- ── File loading ──────────────────────────────────────────────────────────

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

-- Grid-section names that capture raw lines verbatim
local GRID_SECTIONS = { exterior = true, interior = true }

function Ship.loadFromFile(path)
    local content = love.filesystem.read(path)
    if not content then
        error("Could not read ship file: " .. path)
    end

    local data = {
        name      = "Unnamed",
        font_size = 24,
        palette   = {},
        exterior  = {},
        interior  = nil,
        thrusters = {},
    }

    local section = nil

    for raw_line in content:gmatch("[^\r\n]+") do
        local trimmed = raw_line:match("^%s*(.-)%s*$")

        -- ── Section header — always takes priority ────────────────────────
        -- Check this BEFORE the grid-capture branches so that a header like
        -- [interior] inside an [exterior] block correctly ends the section.
        if trimmed:match("^%[.+%]$") then
            section = trimmed:lower():match("^%[(.+)%]$")

        -- ── Grid sections — capture raw line verbatim ─────────────────────
        elseif section == "exterior" then
            table.insert(data.exterior, raw_line)

        elseif section == "interior" then
            data.interior = data.interior or {}
            table.insert(data.interior, raw_line)

        -- ── Non-grid sections ─────────────────────────────────────────────
        elseif trimmed == "" or trimmed:match("^%-%-") then
            -- skip blank lines and Lua-style comments

        elseif section == "thrusters" then
            local row, col, dir =
                trimmed:match("^(%d+),(%d+),(%a+)$")
            if row then
                table.insert(data.thrusters, {
                    row      = tonumber(row),
                    col      = tonumber(col),
                    dir      = dir,
                    active   = true,
                    throttle = 1.0,
                })
            end

        elseif section == "palette" then
            local k, r, g, b = trimmed:match(
                "^(%w)=([%d.%-]+),([%d.%-]+),([%d.%-]+)$")
            if k then
                data.palette[k] = {
                    tonumber(r), tonumber(g), tonumber(b)
                }
            end

        elseif section == nil then
            -- Header key=value lines before any section header
            if trimmed:match("^name:") then
                data.name = trimmed:match("^name:%s*(.+)$")
            elseif trimmed:match("^font_size:") then
                data.font_size = tonumber(
                    trimmed:match("^font_size:%s*(%d+)$")) or 24
            end
        end
    end

    data.exterior = trimBlankRows(data.exterior)
    if data.interior then
        data.interior = trimBlankRows(data.interior)
    end

    return Ship.new(data)
end

-- ── Public API ────────────────────────────────────────────────────────────

function Ship:setMode(mode)
    assert(mode == "exterior" or mode == "interior",
        "Ship:setMode expects 'exterior' or 'interior'")
    if mode == "interior" and not self.int_canvas then
        print("Warning: ship '" .. self.name ..
              "' has no interior, staying exterior")
        return
    end
    self.mode = mode
end

function Ship:getCanvas()
    if self.mode == "interior" and self.int_canvas then
        return self.int_canvas
    end
    return self.ext_canvas
end

function Ship:getTileAt(row, col, layer)
    local map = (layer == "interior") and self.int_map or self.ext_map
    if not map then return nil end
    local r = map[row - 1]
    return r and r[col - 1] or nil
end

function Ship:getGridSize()
    return self.ext_width, self.ext_height
end

function Ship:worldToGrid(wx, wy)
    local lx  = wx - self.x
    local ly  = wy - self.y
    local col = math.floor(lx / self.font_size) + 1
    local row = math.floor(ly / self.font_size) + 1
    return col, row
end

function Ship:gridToWorld(row, col)
    local wx = self.x + (col - 1) * self.font_size + self.font_size / 2
    local wy = self.y + (row - 1) * self.font_size + self.font_size / 2
    return wx, wy
end

function Ship:isInsideBounds(wx, wy)
    local lx = wx - self.x
    local ly = wy - self.y
    return lx >= 0 and lx < self.pixel_w
       and ly >= 0 and ly < self.pixel_h
end

function Ship:getPixelSize()
    return self.pixel_w, self.pixel_h
end

function Ship:setThrusterActive(row, col, active)
    for _, t in ipairs(self.thrusters) do
        if t.row == row and t.col == col then
            t.active = active
            return
        end
    end
end

function Ship:setThrottle(throttle)
    throttle = math.max(0, math.min(1, throttle))
    for _, t in ipairs(self.thrusters) do
        t.throttle = throttle
    end
end

return Ship