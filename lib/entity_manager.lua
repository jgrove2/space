local EntityManager = {}
EntityManager.__index = EntityManager

function EntityManager.new()
    return setmetatable({
        _entities   = {},
        _components = {},
        _next_id    = 1,
    }, EntityManager)
end

function EntityManager:addEntity()
    local id = self._next_id
    self._next_id = self._next_id + 1
    self._entities[id] = true
    return id
end

function EntityManager:removeEntity(id)
    self._entities[id] = nil
    for _, comps in pairs(self._components) do
        comps[id] = nil
    end
end

function EntityManager:alive(id)
    return self._entities[id] ~= nil
end

function EntityManager:addComponent(id, name, data)
    if not self._entities[id] then return end
    if not self._components[name] then
        self._components[name] = {}
    end
    self._components[name][id] = data
end

function EntityManager:getComponent(id, name)
    local comps = self._components[name]
    return comps and comps[id] or nil
end

function EntityManager:removeComponent(id, name)
    local comps = self._components[name]
    if comps then comps[id] = nil end
end

function EntityManager:hasComponent(id, name)
    local comps = self._components[name]
    return comps and comps[id] ~= nil
end

function EntityManager:query(...)
    local names = { ... }
    if #names == 0 then
        local ids = {}
        for id in pairs(self._entities) do
            ids[#ids + 1] = id
        end
        return ids
    end

    local base = self._components[names[1]]
    if not base then return {} end

    local result = {}
    for id in pairs(base) do
        if self._entities[id] then
            local ok = true
            for i = 2, #names do
                local c = self._components[names[i]]
                if not c or not c[id] then ok = false; break end
            end
            if ok then result[#result + 1] = id end
        end
    end
    return result
end

function EntityManager:count()
    local n = 0
    for _ in pairs(self._entities) do n = n + 1 end
    return n
end

return EntityManager
