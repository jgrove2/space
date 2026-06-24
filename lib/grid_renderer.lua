-- lib/grid_renderer.lua
-- Generic ASCII grid → LÖVE canvas renderer.
--
-- Takes a 2D grid of ASCII characters, a palette, and optional
-- look-up tables for glyphs, shapes, and color keys, and bakes
-- the result into a LÖVE Canvas.

local GridRenderer = {}

-- Default color palette (canonical source — 16 colors a–p)
local DEFAULT_COLORS = {
    a = {0.62, 0.62, 0.62},  -- #9E9E9E  hull, thick walls
    b = {0.38, 0.38, 0.38},  -- #616161  border, panel lines
    c = {0.50, 0.87, 0.92},  -- #80DEEA  windows, airlocks
    d = {0.29, 0.24, 0.27},  -- #4B3D44  damage
    e = {1.00, 0.98, 0.77},  -- #FFF9C4  floor
    f = {0.84, 0.00, 0.00},  -- #D50000  thruster nozzles
    g = {0.47, 0.33, 0.28},  -- #795548  captain's seat
    h = {0.01, 0.47, 0.74},  -- #0277BD  energy, consoles
    i = {0.00, 0.00, 0.00},  -- #000000  void
    j = {0.67, 0.28, 0.74},  -- #AB47BC  special
    k = {1.00, 0.76, 0.03},  -- #FFC107  warning
    l = {0.61, 0.80, 0.40},  -- #9CCC65  shield
    m = {1.00, 1.00, 1.00},  -- #FFFFFF  highlight
    n = {1.00, 0.25, 0.51},  -- #FF4081  special
    o = {0.67, 0.61, 0.56},  -- #AB9B8E  hull alt
    p = {1.00, 0.56, 0.00},  -- #FF8F00  engine
}

GridRenderer.DEFAULT_COLORS = DEFAULT_COLORS

function GridRenderer.loadFont(font_size)
    local candidates = {
        "assets/fonts/NotoSansMono-Regular.ttf",
        "assets/fonts/DejaVuSansMono.ttf",
        "assets/fonts/font.ttf",
    }
    for _, path in ipairs(candidates) do
        if love.filesystem.getInfo(path) then
            return love.graphics.newFont(path, font_size)
        end
    end
    return love.graphics.newFont(font_size)
end

function GridRenderer.splitChars(s)
    local chars = {}
    for c in s:gmatch(".[\128-\191]*") do
        table.insert(chars, c)
    end
    return chars
end

local function resolveColor(glyph, palette, glyph_to_color_key, default_colors)
    local dk = glyph_to_color_key and glyph_to_color_key[glyph]
    if dk then
        local entry = palette[dk]
        if not entry then
            entry = default_colors and default_colors[dk]
        end
        if entry then return entry[1], entry[2], entry[3] end
    end
    return 0.7, 0.7, 0.7
end

function GridRenderer.renderGrid(data_rows, palette, font_size, opts)
    opts = opts or {}

    local char_to_glyph      = opts.char_to_glyph      or {}
    local char_to_shape      = opts.char_to_shape      or {}
    local char_to_type       = opts.char_to_type       or {}
    local glyph_to_color_key = opts.glyph_to_color_key or {}
    local default_colors     = opts.default_colors     or DEFAULT_COLORS

    local tiles  = {}
    local width  = 0
    local height = #data_rows

    if height == 0 then
        local canvas = love.graphics.newCanvas(1, 1)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setCanvas()
        return canvas, tiles, {}, 0, 0, 1, 1
    end

    for row, line in ipairs(data_rows) do
        local chars = GridRenderer.splitChars(line)
        local n     = #chars
        if n > width then width = n end

        for ci, char in ipairs(chars) do
            if char ~= " " then
                local glyph = char_to_glyph[char] or char
                local r, g, b = resolveColor(glyph, palette, glyph_to_color_key, default_colors)
                local shape = char_to_shape[char] or "text"
                tiles[#tiles + 1] = {
                    glyph = glyph,
                    col   = ci - 1,
                    row   = row - 1,
                    r     = r, g = g, b = b,
                    shape = shape,
                    char  = char,
                    type  = char_to_type[char],
                }
            end
        end
    end

    local pw     = width * font_size
    local ph     = height * font_size
    local canvas = love.graphics.newCanvas(pw, ph)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local font = GridRenderer.loadFont(font_size)
    love.graphics.setFont(font)

    for _, t in ipairs(tiles) do
        love.graphics.setColor(t.r, t.g, t.b)
        local x  = t.col * font_size
        local y  = t.row * font_size
        local fs = font_size

        if t.shape == "tri_br" then
            love.graphics.polygon("fill",
                x,      y + fs,
                x + fs, y + fs,
                x + fs, y)
        elseif t.shape == "tri_bl" then
            love.graphics.polygon("fill",
                x,      y,
                x,      y + fs,
                x + fs, y + fs)
        elseif t.shape == "fill_rect" then
            love.graphics.rectangle("fill", x, y, fs, fs)
        elseif t.shape == "hbar" then
            local th = math.max(2, fs * 0.18)
            love.graphics.rectangle("fill", x, y + (fs - th) / 2, fs, th)
        elseif t.shape == "vbar" then
            local tw = math.max(2, fs * 0.18)
            love.graphics.rectangle("fill", x + (fs - tw) / 2, y, tw, fs)
        elseif t.shape == "corner_tl" then
            local b = math.max(2, fs * 0.18)
            love.graphics.rectangle("fill", x + (fs-b)/2, y,            b,  fs/2 + b/2)
            love.graphics.rectangle("fill", x + (fs-b)/2, y,            fs/2 + b/2, b)
        elseif t.shape == "corner_tr" then
            local b = math.max(2, fs * 0.18)
            love.graphics.rectangle("fill", x + (fs-b)/2, y,            b,  fs/2 + b/2)
            love.graphics.rectangle("fill", x,            y,            fs/2 + b/2, b)
        elseif t.shape == "corner_bl" then
            local b = math.max(2, fs * 0.18)
            love.graphics.rectangle("fill", x + (fs-b)/2, y + fs/2-b/2, b,  fs/2 + b/2)
            love.graphics.rectangle("fill", x + (fs-b)/2, y + fs  - b,  fs/2 + b/2, b)
        elseif t.shape == "corner_br" then
            local b = math.max(2, fs * 0.18)
            love.graphics.rectangle("fill", x + (fs-b)/2, y + fs/2-b/2, b,  fs/2 + b/2)
            love.graphics.rectangle("fill", x,            y + fs  - b,  fs/2 + b/2, b)
        elseif t.shape == "junction" then
            local b = math.max(2, fs * 0.18)
            love.graphics.rectangle("fill", x,            y + (fs-b)/2, fs, b)
            love.graphics.rectangle("fill", x + (fs-b)/2, y,            b,  fs)
        else
            love.graphics.print(t.glyph, x, y)
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

return GridRenderer
