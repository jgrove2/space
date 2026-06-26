local EntityManager   = require("lib.entity_manager")
local Ship            = require("lib.ship")
local Camera          = require("lib.camera")
local ShipRenderer    = require("lib.ship_renderer")
local Config          = require("lib.config")
local RenderSystem    = require("lib.systems.render_system")
local Spawn           = require("lib.spawn")

local SYSTEMS = {
    require("lib.systems.input_system"),
    require("lib.systems.pilot_system"),
    require("lib.systems.movement_system"),
    require("lib.systems.collision_system"),
    require("lib.systems.interaction_system"),
    require("lib.systems.boarding_system"),
    require("lib.systems.camera_system"),
}

local World = {}
World.__index = World

function World.new()
    local self = setmetatable({}, World)
    self.registry = EntityManager.new()
    self.camera   = Camera.new(Config.W, Config.H)

    local ship_id = Ship.spawn(self, "ships/flatiron_ship.txt", 0, 0, 0)
    self.player_ship_id = ship_id

    Spawn.spawn(self, "asteroid", "ships/asteroid1.txt", 800, 0, 0)

    local fs = Config.font_size
    local ship_gb = self.registry:getComponent(ship_id, "grid_body")
    local ship_layer = ship_gb and ship_gb.layers["exterior"]

    local player_id = self.registry:addEntity()
    self.registry:addComponent(player_id, "transform", {
        x = ship_layer and ship_layer.pixel_w / 2 or 0,
        y = ship_layer and ship_layer.pixel_h / 2 or 0,
        angle = 0, scale = 1, origin = "center",
    })
    self.registry:addComponent(player_id, "velocity", { vx = 0, vy = 0, vθ = 0 })
    self.registry:addComponent(player_id, "controlled_by", { by = "player" })
    self.registry:addComponent(player_id, "collider", { kind = "player", solid = true })

    local player_canvas = love.graphics.newCanvas(fs, fs)
    love.graphics.setCanvas(player_canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(0.30, 0.80, 1.00, 0.9)
    love.graphics.rectangle("fill", 0, 0, fs, fs)
    love.graphics.setCanvas()

    self.registry:addComponent(player_id, "grid_body", {
        layers = {
            exterior = {
                canvas    = player_canvas,
                tiles     = {},
                tile_map  = {},
                grid_w    = 1,
                grid_h    = 1,
                pixel_w   = fs,
                pixel_h   = fs,
                collision = { [1] = { [1] = true } },
            },
        },
        active_layer = "exterior",
        font_size    = fs,
        bounds       = { w = fs, h = fs },
    })
    self.player_id = player_id

    self.interaction_state  = "idle"
    self.interaction_prompt = nil
    self.interaction_action = nil
    self.near_ship_id       = nil
    self.near_tile          = nil
    self.piloting_ship      = nil

    return self
end

function World:update(dt)
    for _, system in ipairs(SYSTEMS) do
        system.update(dt, self)
    end
    for _, id in ipairs(self.registry:query("ship_stats")) do
        local ss = self.registry:getComponent(id, "ship_stats")
        if ss then
            ss.thruster_time = ss.thruster_time + dt
        end
    end
end

function World:draw()
    RenderSystem.draw(self)
end

function World:keypressed(key)
    if key ~= "f" then return end

    if self.interaction_state == "near_airlock_enter" and self.near_ship_id then
        self.interaction_state = "idle"
        self.interaction_action = {
            action = "board",
            ship_id = self.near_ship_id,
            tile = self.near_tile,
        }
    elseif self.interaction_state == "near_airlock_exit" and self.near_ship_id then
        self.interaction_state = "idle"
        self.interaction_action = {
            action = "disembark",
            ship_id = self.near_ship_id,
            tile = self.near_tile,
        }
    elseif self.interaction_state == "near_captain" then
        self.interaction_state = "piloting"
        self.interaction_prompt = "[F] Leave Helm"
        self.interaction_action = {
            action = "start_pilot",
            ship_id = self.near_ship_id,
        }
    elseif self.interaction_state == "piloting" then
        self.interaction_state = "idle"
        self.interaction_prompt = nil
        self.interaction_action = {
            action = "stop_pilot",
        }
    end
end

return World
