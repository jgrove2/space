-- lib/world.lua
local EntityManager = require("lib.entity_manager")
local Player        = require("lib.player")
local Ship          = require("lib.ship")
local ShipRenderer  = require("lib.ship_renderer")
local Interaction   = require("lib.interaction")

local World = {}
World.__index = World

function World.new()
    local self = setmetatable({}, World)

    self.entities = EntityManager.new()

    local ship   = Ship.loadFromFile("ships/flatiron_ship.txt")
    local pw, ph = ship:getPixelSize()
    ship.x       = -pw / 2
    ship.y       = -ph / 2
    ship.type    = "ship"
    ship.update  = function(s, dt) ShipRenderer.update(s, dt) end
    ship.draw    = function(s, dt)
        ShipRenderer.drawWorld(s, s.x, s.y, dt)
    end

    self.player_ship_id = self.entities:add(ship)

    self.player   = Player.new(0, 0, ship.font_size)
    self.player.x = ship.x + pw / 2
    self.player.y = ship.y + ph / 2

    self.interaction = Interaction.new()

    -- Piloting state
    self.piloting_ship = nil

    return self
end

-- ── Update ────────────────────────────────────────────────────────────────

function World:update(dt)
    self.entities:update(dt)

    -- Player movement is locked while piloting
    if not self.piloting_ship then
        self.player:update(dt)
        self:_clampPlayerToShipIfInside()
    end

    self.interaction:update(
        self.player,
        self.entities.entities,
        nil -- font_size unused in Interaction, ships carry it themselves
    )
end

function World:draw(dt)
    local ship = self.entities:get(self.player_ship_id)

    if ship.mode == "interior" then
        -- Draw dark overlay over the whole world first so the outside
        -- world is blacked out, then draw the interior on top
        love.graphics.setColor(0.12, 0.12, 0.18, 1)
        love.graphics.rectangle("fill",
            ship.x - 4000, ship.y - 4000, 8000, 8000)
    end

    -- Draw all entities (ships handle their own mode internally)
    self.entities:draw(dt)

    -- Player is drawn on top of ship but below UI
    if not self.piloting_ship then
        self.player:draw()
    end
end

-- ── Keypressed ────────────────────────────────────────────────────────────

function World:keypressed(key)
    if key == "f" then
        local cmd = self.interaction:interact(self.player)
        if cmd then self:_handleInteraction(cmd) end
    end
end

-- ── Interaction handler ───────────────────────────────────────────────────

function World:_handleInteraction(cmd)
    if cmd.action == "board" then
        local ship = cmd.ship
        ship:setMode("interior")

        -- Find the matching interior airlock tile and teleport player there
        local dest = self:_findMatchingAirlock(ship, cmd.tile, "interior")
        if dest then
            local wx, wy = ship:gridToWorld(dest.row, dest.col)
            self.player.x = wx
            self.player.y = wy
        end
        self.player.inside_ship = ship

    elseif cmd.action == "disembark" then
        local ship = cmd.ship
        ship:setMode("exterior")

        -- Place player just outside the exterior airlock tile
        local dest = self:_findMatchingAirlock(ship, cmd.tile, "exterior")
        if dest then
            local wx, wy = ship:gridToWorld(dest.row, dest.col)
            -- Offset one tile outward so player is outside hull
            wy = wy + ship.font_size
            self.player.x = wx
            self.player.y = wy
        end
        self.player.inside_ship = nil

    elseif cmd.action == "start_pilot" then
        self.piloting_ship = cmd.ship

    elseif cmd.action == "stop_pilot" then
        self.piloting_ship = nil
    end
end

-- Find the closest airlock tile on the target layer to match a source tile.
-- For small ships with two airlocks this picks the nearest one by row/col.
function World:_findMatchingAirlock(ship, source_tile, target_layer)
    local best, best_dist
    for _, a in ipairs(ship.airlocks) do
        if a.layer == target_layer then
            local dr   = a.row - source_tile.row
            local dc   = a.col - source_tile.col
            local dist = dr * dr + dc * dc
            if not best or dist < best_dist then
                best      = a
                best_dist = dist
            end
        end
    end
    return best
end

-- Clamp player position to the interior hull if they are inside a ship.
-- Prevents walking through walls (simple bounding-box clamp for now;
-- tile-level collision can replace this later).
function World:_clampPlayerToShipIfInside()
    local ship = self.player.inside_ship
    if not ship then return end

    local hs  = self.player.size / 2
    local min_x = ship.x + hs
    local min_y = ship.y + hs
    local max_x = ship.x + ship.pixel_w - hs
    local max_y = ship.y + ship.pixel_h - hs

    self.player.x = math.max(min_x, math.min(max_x, self.player.x))
    self.player.y = math.max(min_y, math.min(max_y, self.player.y))
end

function World:getPlayerPosition()
    -- When piloting, camera follows the ship center instead
    if self.piloting_ship then
        local ship = self.piloting_ship
        local pw, ph = ship:getPixelSize()
        return {
            x = ship.x + pw / 2,
            y = ship.y + ph / 2,
        }
    end
    return self.player:getPosition()
end

function World:getInteraction()
    return self.interaction
end

return World