local EventBus = {
    _listeners = {},
}

function EventBus:subscribe(name, fn)
    if not self._listeners[name] then
        self._listeners[name] = {}
    end
    table.insert(self._listeners[name], fn)
end

function EventBus:emit(name, payload)
    local list = self._listeners[name]
    if not list then return end
    for _, fn in ipairs(list) do
        fn(payload)
    end
end

function EventBus:clear(name)
    if name then
        self._listeners[name] = nil
    else
        self._listeners = {}
    end
end

return EventBus
