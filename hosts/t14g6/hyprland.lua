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

local function setLaptopDisplay(disabled)
    hl.monitor({
        output = "eDP-1",
        mode = "preferred",
        position = "auto",
        scale = 1,
        disabled = disabled,
    })
end

local lidState = io.open("/proc/acpi/button/lid/LID/state", "r")
if lidState then
    setLaptopDisplay(lidState:read("*a"):match("closed") ~= nil)
    lidState:close()
end

hl.bind("switch:on:Lid Switch", function()
    setLaptopDisplay(true)
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
    setLaptopDisplay(false)
end, { locked = true })
