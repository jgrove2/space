local Components = {}

Components.Transform = {
    x      = 0,
    y      = 0,
    angle  = 0,
    scale  = 1,
    origin = "top_left",  -- "top_left" or "center"
}

Components.GridBody = {
    layers       = {},
    active_layer = "exterior",
    font_size    = 24,
    bounds       = {},
}

Components.ShipStats = {
    thrusters     = {},
    thruster_time = 0,
}

Components.Interactables = {}

Components.Velocity = {
    vx = 0,
    vy = 0,
    vθ = 0,
}

Components.Collider = {
    kind  = "entity",
    solid = true,
}

Components.Interactable = {
    kind   = "",
    prompt = "",
    row    = 0,
    col    = 0,
    layer  = "",
}

Components.ControlledBy = {
    by = "player",
}

Components.Pilotable = {
    thrust          = 0,
    shield_capacity = 0,
    thrust_bonus    = 0,
}

Components.ContainedIn = {
    ship_id = nil,
    layer   = "",
}

-- Stubs for later phases
Components.AIBrain     = {}
Components.Perception  = {}
Components.Faction     = {}
Components.Pathing     = {}
Components.CrewMember  = {}

return Components
