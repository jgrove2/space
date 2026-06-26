local InputSystem = {}

function InputSystem.update(dt, world)
    local reg = world.registry
    local player_id = world.player_id
    if not player_id or not reg:alive(player_id) then return end

    local controlled = reg:getComponent(player_id, "controlled_by")
    if not controlled or controlled.by ~= "player" then return end

    if world.piloting_ship then return end

    local vx, vy = 0, 0
    local speed = 300

    if love.keyboard.isDown("w", "up")    then vy = -speed end
    if love.keyboard.isDown("s", "down")  then vy =  speed end
    if love.keyboard.isDown("a", "left")  then vx = -speed end
    if love.keyboard.isDown("d", "right") then vx =  speed end

    local vel = reg:getComponent(player_id, "velocity")
    if vel then
        vel.vx = vx
        vel.vy = vy
    end
end

return InputSystem
