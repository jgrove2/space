-- lib/interaction.lua
--
-- Handles proximity detection and interaction state for interactable tiles
-- (airlocks, captain's seat). Called by world.lua each update.
--
-- Interaction range: player must be within 1 tile (in any direction)
-- of the interactable tile center.
--
-- State machine per interaction context:
--   idle      -> near_airlock | near_captain
--   near_*    -> show prompt, wait for F key
--   boarding  -> transition player into ship interior
--   piloting  -> player locked, ship takes input

local Interaction = {}
Interaction.__index = Interaction

local INTERACT_KEY    = "f"
local PROXIMITY_TILES = 1.5  -- tile-distance threshold

function Interaction.new()
    return setmetatable({
        state          = "idle",
        -- prompt shown to player
        prompt         = nil,
        -- which ship and interactable we are near
        near_ship      = nil,
        near_tile      = nil,
    }, Interaction)
end

-- Returns tile-space distance between two grid positions
local function tileDistance(r1, c1, r2, c2)
    local dr = r1 - r2
    local dc = c1 - c2
    return math.sqrt(dr * dr + dc * dc)
end

-- Find the closest interactable tile to the player on the active layer.
-- Returns: ship, tile_entry, kind ("airlock"|"captain"), distance
-- or nil if nothing in range.
function Interaction.findNearest(player, entities, font_size)
    local best_dist = PROXIMITY_TILES + 1
    local best_ship, best_tile, best_kind

    for _, entity in pairs(entities) do
        if entity.type == "ship" then
            local ship = entity

            -- Which layer's interactables are relevant right now
            local layer = ship.mode
            local col_p, row_p = ship:worldToGrid(player.x, player.y)

            local function checkList(list, kind)
                for _, tile in ipairs(list) do
                    if tile.layer == layer then
                        local d = tileDistance(
                            row_p, col_p, tile.row, tile.col)
                        if d <= PROXIMITY_TILES and d < best_dist then
                            best_dist = d
                            best_ship = ship
                            best_tile = tile
                            best_kind = kind
                        end
                    end
                end
            end

            checkList(ship.airlocks,       "airlock")
            checkList(ship.captains_seats, "captain")
        end
    end

    if best_ship then
        return best_ship, best_tile, best_kind, best_dist
    end
end

function Interaction:update(player, entities, font_size)
    -- Don't scan if player is actively piloting
    if self.state == "piloting" then
        self.prompt = "[F] Leave Helm"
        return
    end

    local ship, tile, kind = Interaction.findNearest(
        player, entities, font_size)

    if ship and tile then
        self.near_ship = ship
        self.near_tile = tile

        if kind == "airlock" then
            if ship.mode == "exterior" then
                self.prompt = "[F] Enter Airlock"
                self.state  = "near_airlock_enter"
            else
                self.prompt = "[F] Exit Airlock"
                self.state  = "near_airlock_exit"
            end

        elseif kind == "captain" then
            self.prompt = "[F] Use Captain's Seat"
            self.state  = "near_captain"
        end
    else
        self.near_ship = nil
        self.near_tile = nil
        self.prompt    = nil
        if self.state ~= "piloting" then
            self.state = "idle"
        end
    end
end

-- Called by world.lua when the player presses F.
-- Returns a command table describing what should happen, or nil.
function Interaction:interact(player)
    if self.state == "near_airlock_enter" then
        self.state = "idle"
        return {
            action = "board",
            ship   = self.near_ship,
            tile   = self.near_tile,
        }

    elseif self.state == "near_airlock_exit" then
        self.state = "idle"
        return {
            action = "disembark",
            ship   = self.near_ship,
            tile   = self.near_tile,
        }

    elseif self.state == "near_captain" then
        self.state  = "piloting"
        self.prompt = "[F] Leave Helm"
        return {
            action = "start_pilot",
            ship   = self.near_ship,
        }

    elseif self.state == "piloting" then
        self.state  = "idle"
        self.prompt = nil
        return {
            action = "stop_pilot",
            ship   = self.near_ship,
        }
    end

    return nil
end

return Interaction