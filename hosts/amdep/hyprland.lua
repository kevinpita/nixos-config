local mainMonitor = "desc:ASUSTek COMPUTER INC VG27A M5LMQS167257"
local secondaryMonitor = "desc:ASUSTek COMPUTER INC VG27A M5LMQS167247"

-- Keep workspace banks stable when Hyprland assigns new monitor IDs after reconnecting a screen.
workspaceMonitorBanks = { ["DP-1"] = 0, ["DP-2"] = 1 }

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.monitor({
    output = secondaryMonitor,
    mode = "2560x1440@143.972",
    position = "0x0",
    scale = 1,
    transform = 1,
})

hl.monitor({
    output = mainMonitor,
    mode = "2560x1440@143.972",
    position = "1440x616",
    scale = 1,
})
