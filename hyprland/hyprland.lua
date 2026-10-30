pcall(require, "dms.outputs")

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
        -- ~/.config/xkb/symbols/es-caret from modules/ui/desktop.nix.
        kb_layout = "es-caret",
        resolve_binds_by_sym = true,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
        },
    },
    cursor = {
        enable_hyprcursor = false,
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

local workspaceCount = 10
local workspacesPerMonitor = 5

local function workspace_id(monitor, slot)
    local bank = workspaceMonitorBanks and workspaceMonitorBanks[monitor.name] or monitor.id
    return bank * workspacesPerMonitor + slot
end

local function configure_monitor_workspaces(monitor)
    for slot = 1, workspacesPerMonitor do
        hl.workspace_rule({
            workspace = tostring(workspace_id(monitor, slot)),
            monitor = monitor.name,
            persistent = true,
            default = slot == 1,
        })
    end
end

for _, monitor in ipairs(hl.get_monitors()) do
    configure_monitor_workspaces(monitor)
end

hl.on("monitor.added", configure_monitor_workspaces)

local mainMod = "SUPER"
local dms = "dms ipc call "

local function focus_or_launch(selector, command)
    return function()
        if hl.get_window(selector) then
            hl.dispatch(hl.dsp.focus({ window = selector }))
        else
            hl.dispatch(hl.dsp.exec_cmd(command))
        end
    end
end

local musicWorkspace = "special:music"
local soneSelector = "class:^(sone)$"

local function is_sone(window)
    return window.class == "sone"
end

local function move_to_regular_workspace(window, follow)
    local target = window.monitor and window.monitor.active_workspace
    if target then
        hl.dispatch(hl.dsp.window.move({ workspace = target, window = window, follow = follow }))
    end
end

-- The music overlay holds only Sone. Windows that spawn while it has focus
-- go to the regular workspace below it, and the overlay closes.
hl.on("window.open", function(window)
    if window.workspace and window.workspace.name == musicWorkspace and not is_sone(window) then
        move_to_regular_workspace(window, true)
    end
end)

-- Sone can leave the overlay, for example with a window move bind. Return it
-- before the toggle so the toggle always acts on the window.
local function toggle_music()
    local sone = hl.get_window(soneSelector)
    if not sone then
        hl.dispatch(hl.dsp.exec_cmd("uwsm app -- sone"))
        return
    end

    local music = hl.get_workspace(musicWorkspace)
    if music then
        for _, window in ipairs(hl.get_workspace_windows(music)) do
            if not is_sone(window) then
                move_to_regular_workspace(window, false)
            end
        end
    end

    if sone.workspace and sone.workspace.name ~= musicWorkspace then
        local wasVisible = sone.workspace.visible
        hl.dispatch(hl.dsp.window.move({ workspace = musicWorkspace, window = sone, follow = false }))
        if wasVisible then
            return
        end
    end

    hl.dispatch(hl.dsp.workspace.toggle_special("music"))
end

local function toggle_scratch()
    local scratch = hl.get_workspace("special:scratch")
    local isEmpty = not scratch or scratch.windows == 0
    hl.dispatch(hl.dsp.workspace.toggle_special("scratch"))
    if isEmpty then
        hl.dispatch(hl.dsp.exec_cmd("uwsm app -- ghostty"))
    end
end

hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("super-double-tap"), { release = true })
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("uwsm app -- ghostty"))
hl.bind(mainMod .. " + SHIFT + Return", toggle_scratch)
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("uwsm app -- brave"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("uwsm app -- google-chrome-stable --new-window about:blank"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("uwsm app -- nautilus --new-window"))
hl.bind(mainMod .. " + H", focus_or_launch("class:^(herdr-app)$", "uwsm app -- herdr-app"))
hl.bind(mainMod .. " + M", toggle_music)
hl.bind(mainMod .. " + N", function()
    if hl.get_window("class:^(heynote|Heynote)$") then
        hl.dispatch(hl.dsp.workspace.toggle_special("notes"))
    else
        hl.dispatch(hl.dsp.exec_cmd("uwsm app -- heynote"))
    end
end)
hl.bind(mainMod .. " + O", focus_or_launch("class:^(obsidian)$", "uwsm app -- obsidian"))
hl.bind(mainMod .. " + S", focus_or_launch("class:^(slack|Slack)$", "uwsm app -- slack"))
hl.bind(mainMod .. " + T", focus_or_launch("class:^(org.telegram.desktop|TelegramDesktop)$", "uwsm app -- Telegram"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("omasnap"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(dms .. "lock lock"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(dms .. "notifications toggle"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(dms .. "clipboard toggle"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("omasnap"))

local directions = {
    { key = "left", direction = "left" },
    { key = "right", direction = "right" },
    { key = "up", direction = "up" },
    { key = "down", direction = "down" },
}

for _, binding in ipairs(directions) do
    hl.bind(mainMod .. " + SHIFT + " .. binding.key, hl.dsp.window.move({ direction = binding.direction }))
end

hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + left", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.workspace.move({ monitor = "r" }))

local workspaceDrag = nil
local workspaceSwapId = 2147483647

local function swap_workspaces(first_id, second_id)
    hl.dispatch(hl.dsp.workspace.change_id({ workspace = first_id, id = workspaceSwapId }))
    hl.dispatch(hl.dsp.workspace.change_id({ workspace = second_id, id = first_id }))
    hl.dispatch(hl.dsp.workspace.change_id({ workspace = workspaceSwapId, id = second_id }))
end

local function drag_workspace(target_id)
    local current = hl.get_active_workspace()
    local current_monitor = current and current.monitor
    if not current or current.special or not current_monitor then
        return
    end

    if
        not workspaceDrag
        or current.id ~= workspaceDrag.target_id
        or current_monitor.id ~= workspaceDrag.monitor_id
    then
        workspaceDrag = { origin_id = current.id, target_id = current.id, monitor_id = current_monitor.id }
    end

    local target = hl.get_workspace(target_id)
    local target_monitor = target and target.monitor
    if
        not target
        or target.special
        or not target_monitor
        or target_monitor.id ~= workspaceDrag.monitor_id
        or target_id == workspaceDrag.target_id
    then
        return
    end

    local previous_target_id = workspaceDrag.target_id
    if previous_target_id ~= workspaceDrag.origin_id then
        swap_workspaces(workspaceDrag.origin_id, previous_target_id)
    end
    if target_id ~= workspaceDrag.origin_id then
        swap_workspaces(workspaceDrag.origin_id, target_id)
    end

    workspaceDrag.target_id = target_id
    local refresh_id = target_id ~= workspaceDrag.origin_id and workspaceDrag.origin_id or previous_target_id
    hl.dispatch(hl.dsp.focus({ workspace = refresh_id }))
    hl.dispatch(hl.dsp.focus({ workspace = target_id }))
end

local function monitor_workspace_ids(monitor)
    local workspace_ids = {}
    local first_workspace_id = workspace_id(monitor, 1)
    local last_workspace_id = workspace_id(monitor, workspacesPerMonitor)
    for _, workspace in ipairs(hl.get_workspaces()) do
        local workspace_monitor = workspace.monitor
        if
            not workspace.special
            and workspace.id >= first_workspace_id
            and workspace.id <= last_workspace_id
            and workspace_monitor
            and workspace_monitor.id == monitor.id
        then
            table.insert(workspace_ids, workspace.id)
        end
    end
    table.sort(workspace_ids)
    return workspace_ids
end

local function adjacent_workspace(offset)
    local current = hl.get_active_workspace()
    local current_monitor = current and current.monitor
    if not current or current.special or not current_monitor then
        return nil
    end

    local drag_is_active = workspaceDrag
        and current.id == workspaceDrag.target_id
        and current_monitor.id == workspaceDrag.monitor_id
    local current_id = drag_is_active and workspaceDrag.target_id or current.id
    local workspace_ids = monitor_workspace_ids(current_monitor)

    for index, workspace_id in ipairs(workspace_ids) do
        if workspace_id == current_id then
            return workspace_ids[(index - 1 + offset) % #workspace_ids + 1]
        end
    end

    return nil
end

local function focus_or_drag_workspace(target_id)
    return function()
        if hl.is_key_down("Tab") then
            drag_workspace(target_id)
            return
        end

        hl.dispatch(hl.dsp.focus({ workspace = target_id }))
    end
end

local function scroll_workspace(focus_target, drag_offset)
    return function()
        if hl.is_key_down("Tab") then
            local target_id = adjacent_workspace(drag_offset)
            if target_id then
                drag_workspace(target_id)
            end
            return
        end

        hl.dispatch(hl.dsp.focus({ workspace = focus_target }))
    end
end

hl.bind(mainMod .. " + Tab", hl.dsp.no_op())
hl.bind(mainMod .. " + Tab", function()
    workspaceDrag = nil
end, { release = true })

for workspace = 1, workspaceCount do
    local key = workspace % 10
    hl.bind(mainMod .. " + " .. key, focus_or_drag_workspace(workspace))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mainMod .. " + mouse_down", scroll_workspace("m-1", 1))
hl.bind(mainMod .. " + mouse_up", scroll_workspace("m+1", -1))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("Print", hl.dsp.exec_cmd("omasnap"))

hl.window_rule({
    name = "sone-scratchpad",
    match = { class = "^(sone)$" },
    workspace = "special:music",
    float = true,
    size = "monitor_w*0.75 monitor_h*0.75",
    center = true,
})

hl.window_rule({
    name = "heynote-scratchpad",
    match = { class = "^(heynote|Heynote)$" },
    workspace = "special:notes",
    float = true,
    size = "monitor_w*0.75 monitor_h*0.75",
    center = true,
})

hl.layer_rule({
    match = { namespace = "^omasnap$" },
    no_anim = true,
    animation = "none",
    no_screen_share = true,
})

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(dms .. "audio increment 5"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(dms .. "audio decrement 5"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(dms .. "audio mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("microphone-mute"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(dms .. "brightness increment 5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(dms .. "brightness decrement 5"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
pcall(require, "dms.layout")
