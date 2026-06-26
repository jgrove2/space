local GridRenderer = require("lib.grid_renderer")

local GridBodyBuilder = {}

function GridBodyBuilder.buildLayer(data_rows, palette, font_size, tileset, color_map)
    local opts = {
        char_to_glyph      = tileset.CHAR_TO_GLYPH,
        char_to_shape      = tileset.CHAR_TO_SHAPE,
        char_to_type       = tileset.CHAR_TYPE,
        glyph_to_color_key = tileset.CHAR_DEFAULTS,
        default_colors     = GridRenderer.DEFAULT_COLORS,
        color_map          = color_map,
    }

    local canvas, tiles, tile_map, width, height, pw, ph =
        GridRenderer.renderGrid(data_rows, palette, font_size, opts)

    local collision = tileset.buildCollisionGrid(data_rows)

    return {
        canvas    = canvas,
        tiles     = tiles,
        tile_map  = tile_map,
        grid_w    = width,
        grid_h    = height,
        pixel_w   = pw,
        pixel_h   = ph,
        collision = collision,
    }
end

function GridBodyBuilder.build(data, palette, font_size, tileset)
    local layers = {}

    layers.exterior = GridBodyBuilder.buildLayer(
        data.exterior, palette, font_size, tileset, data.colors_exterior)

    if data.interior and #data.interior > 0 then
        layers.interior = GridBodyBuilder.buildLayer(
            data.interior, palette, font_size, tileset, data.colors_interior)
    end

    return layers
end

return GridBodyBuilder
