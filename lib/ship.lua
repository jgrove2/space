-- lib/ship.lua
local Ship = {}
Ship.__index = Ship

local CHAR_TO_GLYPH = {
    ["#"] = "█", ["@"] = "▓", ["%"] = "▒", ["."] = "░",
    ["/"] = "╱", ["\\"] = "╲",
    ["="] = "═", ["|"] = "║", ["-"] = "─", ["!"] = "│",
    ["+"] = "┼", ["~"] = "~",
    ["["] = "╔", ["]"] = "╗", ["{"] = "╚", ["}"] = "╝",
    ["o"] = "O", ["*"] = "◆",
    ["v"] = "▼", ["^"] = "▲", ["<"] = "◄", [">"] = "►",
    ["A"] = "A", ["C"] = "C",
}

local CHAR_DEFAULTS = {
    ["█"] = "a", ["▓"] = "b", ["▒"] = "d", ["░"] = "e",
    ["╱"] = "b", ["╲"] = "b",
    ["═"] = "a", ["║"] = "a", ["─"] = "b", ["│"] = "b",
    ["╔"] = "a", ["╗"] = "a", ["╚"] = "a", ["╝"] = "a",
    ["┼"] = "b", ["~"] = "h",
    ["O"] = "c", ["◆"] = "h",
    ["▼"] = "f", ["▲"] = "f", ["◄"] = "f", ["►"] = "f",
    ["A"] = "c", -- cyan, same as windows so it stands out
    ["C"] = "g", -- dark slate for the captain's seat
}

local function splitChars(s)
    local chars = {}
    for c in s:gmatch(".[\128-\191]*") do
        table.insert(chars, c)
    end
    return chars
end

local function resolveColor(glyph, palette)
    local dk = CHAR_DEFAULTS[glyph]
    if dk then
        local entry = palette[dk]
        if entry then return entry[1], entry[2], entry[3] end
    end
    return 0.7, 0.7, 0.7
end

local function parseLayer(data_rows, palette, font_size)
    local tiles     = {}
    local width     = 0
    local height    = #data_rows

    for row, line in ipairs(data_rows) do
        local chars = splitChars(line)
        local n     = #chars
        if n > width then width = n end

        for ci, char in ipairs(chars) do
            if char ~= " " then
                local glyph = CHAR_TO_GLYPH[char] or char
                local r, g, b = resolveColor(glyph, palette)
                local shape = (char == "/" and "br")
                           or (char == "\\" and "bl")
                           or nil
                tiles[#tiles + 1] = {
                    glyph = glyph,
                    col   = ci - 1,
                    row   = row - 1,
                    r     = r, g = g, b = b,
                    shape = shape,
                    char  = char,
                }
            end
        end
    end

    local pw, ph = width * font_size, height * font_size
    local canvas  = love.graphics.newCanvas(pw, ph)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    for _, t in ipairs(tiles) do
        love.graphics.setColor(t.r, t.g, t.b)
        local x = t.col * font_size
        local y = t.row * font_size

        if t.shape == "br" then
            love.graphics.polygon("fill",
                x,             y + font_size,
                x + font_size, y + font_size,
                x + font_size, y)
        elseif t.shape == "bl" then
            love.graphics.polygon("fill",
                x, y,
                x, y + font_size,
                x + font_size, y + font_size)
        else
            love.graphics.rectangle("fill", x, y, font_size, font_size)
        end
    end

    love.graphics.setCanvas()

    local tiles_map = {}
    for _, t in ipairs(tiles) do
        local r0 = t.row
        if not tiles_map[r0] then tiles_map[r0] = {} end
        tiles_map[r0][t.col] = t
    end

    return canvas, tiles, tiles_map, width, height, pw, ph
end

local THRUSTER_CHARS = {
    ["v"] = "down", ["^"] = "up",
    ["<"] = "left", [">"] = "right",
}

local function autoDetectThrusters(data_rows)
    local thrusters = {}
    for row, line in ipairs(data_rows) do
        local chars = splitChars(line)
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

-- Scan both layers for special interactive tiles (A = airlock, C = captain)
local function detectInteractables(ext_rows, int_rows)
    local airlocks       = {}
    local captains_seats = {}

    local function scan(rows, layer)
        for row, line in ipairs(rows) do
            local chars = splitChars(line)
            for ci, char in ipairs(chars) do
                if char == "A" then
                    airlocks[#airlocks + 1] = {
                        row   = row,
                        col   = ci,
                        layer = layer,
                    }
                elseif char == "C" then
                    captains_seats[#captains_seats + 1] = {
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

    return airlocks, captains_seats
end

-- ── Ship.new ──────────────────────────────────────────────────────────────

function Ship.new(data)
    local self      = setmetatable({}, Ship)
    self.name       = data.name      or "Unnamed"
    self.font_size  = data.font_size or 24
    self.palette    = data.palette   or {}
    self.mode       = "exterior"
    self.x          = 0
    self.y          = 0
    self.type       = "ship"

    self.ext_canvas, self.ext_tiles, self.ext_map,
        self.ext_width, self.ext_height,
        self.pixel_w,   self.pixel_h =
            parseLayer(data.exterior, self.palette, self.font_size)

    if data.interior then
        self.int_canvas, self.int_tiles, self.int_map,
            self.int_width, self.int_height =
                parseLayer(data.interior, self.palette, self.font_size)
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

    self.airlocks, self.captains_seats =
        detectInteractables(data.exterior, data.interior)

    self.thruster_time = 0
    return self
end

-- ── File loading ──────────────────────────────────────────────────────────

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

    for line in content:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")

        if trimmed == "" or trimmed:match("^#") then
            -- skip

        elseif trimmed:match("^%[.+%]$") then
            section = trimmed:lower():match("^%[(.+)%]$")
            if section == "interior" then
                data.interior = data.interior or {}
            end

        elseif trimmed:match("^name:") then
            data.name = trimmed:match("^name:%s*(.+)$")

        elseif trimmed:match("^font_size:") then
            data.font_size = tonumber(
                trimmed:match("^font_size:%s*(%d+)$"))

        elseif section == "palette" then
            local k, r, g, b = trimmed:match(
                "^(%w)=([%d.%-]+),([%d.%-]+),([%d.%-]+)$")
            if k then
                data.palette[k] = {
                    tonumber(r), tonumber(g), tonumber(b)
                }
            end

        elseif section == "exterior" then
            table.insert(data.exterior, line)

        elseif section == "interior" then
            table.insert(data.interior, line)

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
        end
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