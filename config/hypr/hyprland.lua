hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.bind("SUPER + Return", hl.dsp.exec_cmd("uwsm app -- ghostty"))
