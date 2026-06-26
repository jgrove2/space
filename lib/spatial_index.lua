local SpatialIndex = {}
SpatialIndex.__index = SpatialIndex

function SpatialIndex.new(cell_size)
    return setmetatable({
        cell_size = cell_size or 256,
        cells     = {},
    }, SpatialIndex)
end

function SpatialIndex:_cellKey(x, y)
    local cx = math.floor(x / self.cell_size)
    local cy = math.floor(y / self.cell_size)
    return cx .. "," .. cy
end

function SpatialIndex:insert(entity_id, aabb)
    local min_key = self:_cellKey(aabb.x, aabb.y)
    local max_key = self:_cellKey(aabb.x + aabb.w, aabb.y + aabb.h)
    local min_cx, min_cy = math.floor(aabb.x / self.cell_size), math.floor(aabb.y / self.cell_size)
    local max_cx, max_cy = math.floor((aabb.x + aabb.w) / self.cell_size), math.floor((aabb.y + aabb.h) / self.cell_size)
    for cx = min_cx, max_cx do
        for cy = min_cy, max_cy do
            local key = cx .. "," .. cy
            if not self.cells[key] then
                self.cells[key] = {}
            end
            self.cells[key][entity_id] = true
        end
    end
end

function SpatialIndex:remove(entity_id)
    for _, ids in pairs(self.cells) do
        ids[entity_id] = nil
    end
end

function SpatialIndex:clear()
    self.cells = {}
end

function SpatialIndex:queryRegion(aabb)
    local result = {}
    local seen   = {}
    local min_cx = math.floor(aabb.x / self.cell_size)
    local min_cy = math.floor(aabb.y / self.cell_size)
    local max_cx = math.floor((aabb.x + aabb.w) / self.cell_size)
    local max_cy = math.floor((aabb.y + aabb.h) / self.cell_size)
    for cx = min_cx, max_cx do
        for cy = min_cy, max_cy do
            local key = cx .. "," .. cy
            local ids = self.cells[key]
            if ids then
                for id in pairs(ids) do
                    if not seen[id] then
                        seen[id] = true
                        result[#result + 1] = id
                    end
                end
            end
        end
    end
    return result
end

return SpatialIndex
