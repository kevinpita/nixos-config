hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(89b4faff)", "rgba(cba6f7ff)" }, angle = 45 },
            inactive_border = "rgba(45475aaa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 8,
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
            color = 0xee11111b,
        },
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
        },
    },
    animations = {
        enabled = true,
    },
    input = {
        kb_layout = "es",
        resolve_binds_by_sym = true,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

for workspace = 1, 5 do
    hl.workspace_rule({
        workspace = tostring(workspace),
        persistent = true,
    })
end

local mainMod = "SUPER"
local areaScreenshot = [[geometry="$(slurp)" && grim -g "$geometry" - | swappy -f -]]
local dms = "dms ipc call "

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("uwsm app -- ghostty"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(dms .. "spotlight toggle"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(dms .. "lock lock"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(dms .. "notifications toggle"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(dms .. "clipboard toggle"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(areaScreenshot))

local directions = {
    { key = "left", direction = "left" },
    { key = "right", direction = "right" },
    { key = "up", direction = "up" },
    { key = "down", direction = "down" },
}

for _, binding in ipairs(directions) do
    hl.bind(mainMod .. " + " .. binding.key, hl.dsp.focus({ direction = binding.direction }))
    hl.bind(mainMod .. " + SHIFT + " .. binding.key, hl.dsp.window.move({ direction = binding.direction }))
end

for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy && notify-send 'Screenshot' 'Copied to clipboard'"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(areaScreenshot))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(dms .. "audio increment 5"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(dms .. "audio decrement 5"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(dms .. "audio mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(dms .. "audio micmute"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(dms .. "brightness increment 5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(dms .. "brightness decrement 5"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- DMS Include Configs
require("dms.outputs")
