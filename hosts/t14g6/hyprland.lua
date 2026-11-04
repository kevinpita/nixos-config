local mainMonitor = "desc:ASUSTek COMPUTER INC VG27A M5LMQS167257"
local secondaryMonitor = "desc:ASUSTek COMPUTER INC VG27A M5LMQS167247"

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.monitor({
    output = secondaryMonitor,
    mode = "2560x1440@144.006",
    position = "0x0",
    scale = 1,
    transform = 1,
})

hl.monitor({
    output = mainMonitor,
    mode = "2560x1440@144.006",
    position = "1440x620",
    scale = 1,
})

local laptopOutput = "eDP-1"
local lidClosed = false
local laptopDisabled = nil

-- Turn the laptop panel off only while the lid is closed and another monitor
-- is active. Without another monitor logind suspends, and removing the only
-- output during the DMS lock kills the lock screen.
local function updateLaptopDisplay(removed)
    local external = false
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.name ~= laptopOutput and monitor.name ~= removed then
            external = true
        end
    end

    local disabled = lidClosed and external
    if disabled == laptopDisabled then
        return
    end
    laptopDisabled = disabled
    hl.monitor({
        output = laptopOutput,
        mode = "preferred",
        position = "auto",
        scale = 1,
        disabled = disabled,
    })
end

local lidState = io.open("/proc/acpi/button/lid/LID/state", "r")
if lidState then
    lidClosed = lidState:read("*a"):match("closed") ~= nil
    lidState:close()
end
updateLaptopDisplay()

hl.on("monitor.added", function()
    updateLaptopDisplay()
end)

hl.on("monitor.removed", function(monitor)
    updateLaptopDisplay(monitor and monitor.name)
end)

hl.bind("switch:on:Lid Switch", function()
    lidClosed = true
    updateLaptopDisplay()
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
    lidClosed = false
    updateLaptopDisplay()
end, { locked = true })
