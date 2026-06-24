-- lib/entity_manager.lua
--
-- Manages all world entities: ships, asteroids, planets, stations, etc.
-- Each entity must implement:
--   entity:update(dt)
--   entity:draw(dt)
--   entity.x, entity.y        (world position)
--   entity.type               (string: "ship", "asteroid", "planet", etc.)
--
-- Future work: spatial hashing / quadtree for large entity counts.

local EntityManager = {}
EntityManager.__index = EntityManager

function EntityManager.new()
    return setmetatable({
        entities = {},
        _next_id = 1,
    }, EntityManager)
end

function EntityManager:add(entity)
    local id = self._next_id
    self._next_id = self._next_id + 1
    entity._id = id
    self.entities[id] = entity
    return id
end

function EntityManager:remove(id)
    self.entities[id] = nil
end

function EntityManager:get(id)
    return self.entities[id]
end

-- Return all entities matching a type string
function EntityManager:getByType(type_str)
    local result = {}
    for _, e in pairs(self.entities) do
        if e.type == type_str then
            result[#result + 1] = e
        end
    end
    return result
end

function EntityManager:update(dt)
    for _, e in pairs(self.entities) do
        if e.update then e:update(dt) end
    end
end

function EntityManager:draw(dt)
    -- TODO: depth sort by entity.y or entity.z_order when needed
    for _, e in pairs(self.entities) do
        if e.draw then e:draw(dt) end
    end
end

return EntityManager