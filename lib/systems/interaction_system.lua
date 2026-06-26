local Transform = require("lib.transform")

local InteractionSystem = {}

local PROXIMITY_TILES = 1.5

local PROMPTS = {
    airlock = {
        exterior = { state = "near_airlock_enter", prompt = "[F] Enter Airlock" },
        interior = { state = "near_airlock_exit",  prompt = "[F] Exit Airlock" },
    },
    captain = {
        _default = { state = "near_captain", prompt = "[F] Use Captain's Seat" },
    },
}

function InteractionSystem.registerKind(kind, layer, cfg)
    if not PROMPTS[kind] then PROMPTS[kind] = {} end
    PROMPTS[kind][layer or "_default"] = cfg
end

local function tileDistance(r1, c1, r2, c2)
    local dr = r1 - r2
    local dc = c1 - c2
    return math.sqrt(dr * dr + dc * dc)
end

local function findNearest(reg, player_id, entity_ids)
    local px = reg:getComponent(player_id, "transform")
    if not px then return end

    local best_dist = PROXIMITY_TILES + 1
    local best_kind, best_eid, best_tile

    for _, eid in ipairs(entity_ids) do
        local gb = reg:getComponent(eid, "grid_body")
        if not gb then break end

        local exf = reg:getComponent(eid, "transform")
        if not exf then break end

        local active_layer = gb.active_layer or "exterior"
        local layer = gb.layers[active_layer]
        if not layer then break end

        local row, col = Transform.worldToGridRC(exf, layer, gb.font_size, px.x, px.y)

        local interactables = reg:getComponent(eid, "interactables")
        if not interactables then break end

        for _, entry in ipairs(interactables) do
            if entry.layer == active_layer then
                local d = tileDistance(row, col, entry.row, entry.col)
                if d <= PROXIMITY_TILES and d < best_dist then
                    best_dist = d
                    best_eid = eid
                    best_tile = entry
                    best_kind = entry.kind
                end
            end
        end
    end

    if best_eid then
        return best_eid, best_tile, best_kind
    end
end

local function lookupPrompt(kind, active_layer)
    local kind_cfg = PROMPTS[kind]
    if not kind_cfg then return nil, nil end
    local entry = kind_cfg[active_layer] or kind_cfg._default
    if entry then
        return entry.state, entry.prompt
    end
    return nil, nil
end

function InteractionSystem.update(dt, world)
    local reg = world.registry
    if not world.player_id then return end

    if world.piloting_ship then
        world.interaction_state = "piloting"
        world.interaction_prompt = "[F] Leave Helm"
        return
    end

    local entity_ids = reg:query("grid_body", "interactables")
    local eid, tile, kind = findNearest(reg, world.player_id, entity_ids)

    if eid and tile then
        world.near_ship_id = eid
        world.near_tile = tile

        local gb = reg:getComponent(eid, "grid_body")
        local active_layer = gb and gb.active_layer or "exterior"
        local state, prompt = lookupPrompt(kind, active_layer)
        if state then
            world.interaction_state = state
            world.interaction_prompt = prompt
        end
    else
        world.near_ship_id = nil
        world.near_tile = nil
        world.interaction_prompt = nil
        if world.interaction_state ~= "piloting" then
            world.interaction_state = "idle"
        end
    end
end

return InteractionSystem
