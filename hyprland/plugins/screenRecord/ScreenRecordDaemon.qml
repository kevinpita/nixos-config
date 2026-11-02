import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string slurp: "@slurp@"
    readonly property string wfRecorder: "@wfRecorder@"
    readonly property string ffmpeg: "@ffmpeg@"
    readonly property string ffprobe: "@ffprobe@"
    readonly property string stat: "@stat@"
    readonly property string wlCopy: "@wlCopy@"
    readonly property string notifySend: "@notifySend@"
    readonly property string xdgUserDir: "@xdgUserDir@"
    readonly property string toggleKey: "@toggleKey@"

    property string workDir: ""
    readonly property string sourceFile: workDir + "/source.mp4"

    // Each quality caps the height; smaller regions keep their size.
    readonly property var qualities: [
        { label: "Tiny", height: 480, crf: 32 },
        { label: "Small", height: 720, crf: 30 },
        { label: "Medium", height: 1080, crf: 27 },
        { label: "High", height: 1440, crf: 23 },
        { label: "Original", height: 0, crf: 20 }
    ]
    readonly property int defaultQuality: 2
    readonly property int minimumClipMs: 500
    // wf-recorder writes the raw monitor buffer, so undo the Hyprland transform (wl_output order).
    readonly property var unrotate: ["", "transpose=cclock,", "hflip,vflip,", "transpose=clock,"]

    // idle -> selecting -> recording -> review -> idle
    property string phase: "idle"
    property int monitorTransform: 0
    // Steps from 30 fps up to the refresh rate of the recorded monitor.
    property var frameRates: [30]
    property int qualityIndex: defaultQuality
    property int frameRateIndex: 0
    property int sourceMs: 0
    property int trimStartMs: 0
    property int trimEndMs: 0
    property string videosDir: ""
    property int generation: 0
    property var encodeJob: null
    property string previewFile: ""
    property string previewSettings: ""
    // Source time of the first preview frame, to place the playhead on the full timeline.
    property int previewStartMs: 0
    property real previewBytes: 0
    property bool saveRequested: false
    property string saveError: ""

    readonly property bool encoding: encodeJob !== null
    readonly property bool saving: saveProcess.running

    function notify(summary, body) {
        Quickshell.execDetached([notifySend, "-a", "Screen Record", "-i", "media-record", summary, body]);
    }

    function toggle() {
        switch (phase) {
        case "idle":
            phase = "selecting";
            selectProcess.running = true;
            return "selecting";
        case "recording":
            recorder.signal(2);
            return "stopping";
        default:
            return phase;
        }
    }

    function startRecording(selection) {
        const match = selection.match(/^(\S+) (\S+ \S+)$/);
        if (!match) {
            phase = "idle";
            return;
        }
        const monitor = Hyprland.monitors.values.find(m => m.name === match[1])?.lastIpcObject;
        monitorTransform = monitor?.transform ?? 0;
        const refresh = Math.round(monitor?.refreshRate ?? 60);
        frameRates = [30, 60, 90, 120, 144, 165, 240].filter(rate => rate < refresh).concat([Math.max(refresh, 30)]);
        generation += 1;
        workDir = Quickshell.env("XDG_RUNTIME_DIR") + "/screen-record-" + Date.now() + "-" + generation;
        // No -r: wf-recorder keeps every compositor frame, up to the refresh rate.
        recorder.command = ["sh", "-c", 'rm -rf -- "$1" && mkdir -p -- "$1" && exec "$2" -g "$3" -c libx264 -p preset=ultrafast -p crf=16 -f "$4"', "sh", workDir, wfRecorder, match[2], sourceFile];
        recorder.running = true;
        phase = "recording";
        notify("Recording", "Press " + toggleKey + " to stop.");
    }

    function filter() {
        const quality = qualities[qualityIndex];
        const orientation = unrotate[monitorTransform % 4] + (monitorTransform >= 4 ? "hflip," : "");
        const scale = quality.height > 0 ? "scale=-2:'2*trunc(min(ih," + quality.height + ")/2)':flags=lanczos" : "scale='2*trunc(iw/2)':'2*trunc(ih/2)'";
        return "fps=" + frameRates[frameRateIndex] + "," + orientation + scale + ":out_range=tv";
    }

    function setTrim(startMs, endMs) {
        trimStartMs = Math.max(0, Math.min(startMs, sourceMs - minimumClipMs));
        trimEndMs = Math.min(sourceMs, Math.max(endMs, trimStartMs + minimumClipMs));
    }

    function encodeSettings() {
        return [trimStartMs, trimEndMs, qualityIndex, frameRateIndex].join(":");
    }

    function encode() {
        if (phase !== "review" || saving)
            return;
        const previousJob = encodeJob;
        generation += 1;
        encodeJob = null;
        if (previousJob)
            previousJob.running = false;
        const output = workDir + "/preview-" + generation + ".mp4";
        encodeJob = encodeComponent.createObject(root, {
            generation: generation,
            startMs: trimStartMs,
            settings: encodeSettings(),
            output: output,
            command: [ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-ss", String(trimStartMs / 1000), "-to", String(trimEndMs / 1000), "-i", sourceFile, "-vf", filter(), "-c:v", "libx264", "-preset", "slow", "-crf", String(qualities[qualityIndex].crf), "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", output]
        });
        encodeJob.running = true;
    }

    function encodeFinished(job, exitCode, errorText) {
        if (job.generation !== generation || phase !== "review") {
            job.destroy();
            return;
        }
        encodeJob = null;
        job.destroy();
        if (exitCode !== 0) {
            saveRequested = false;
            notify("Encoding failed", errorText || ("ffmpeg exited with code " + exitCode));
            return;
        }
        if (previewFile)
            Quickshell.execDetached(["rm", "-f", "--", previewFile]);
        previewFile = job.output;
        previewSettings = job.settings;
        previewStartMs = job.startMs;
        sizeProcess.command = [stat, "-c", "%s", job.output];
        sizeProcess.running = true;
        if (saveRequested)
            save(review.fileName);
    }

    function save(name) {
        if (phase !== "review" || saving)
            return;
        saveError = "";
        if (encoding || previewSettings !== encodeSettings() || !previewFile) {
            if (!encodeJob || encodeJob.settings !== encodeSettings())
                encode();
            saveRequested = true;
            return;
        }
        saveRequested = false;
        if (!previewFile)
            return;
        let fileName = (name.trim() || review.defaultName).replace(/\//g, "-");
        if (!fileName.toLowerCase().endsWith(".mp4"))
            fileName += ".mp4";
        const target = videosDir + "/" + fileName;
        saveProcess.target = target;
        saveProcess.generation = generation;
        saveProcess.command = ["sh", "-c", '[ ! -e "$2" ] || exit 3; mkdir -p -- "${2%/*}" && cp -- "$1" "$2" && "$3" --type text/uri-list "$4" </dev/null >/dev/null 2>&1', "sh", previewFile, target, wlCopy, "file://" + target.split("/").map(part => encodeURIComponent(part)).join("/")];
        saveProcess.running = true;
    }

    function finish() {
        const previousJob = encodeJob;
        generation += 1;
        encodeJob = null;
        if (previousJob)
            previousJob.running = false;
        review.visible = false;
        previewFile = "";
        previewSettings = "";
        previewBytes = 0;
        saveRequested = false;
        saveError = "";
        Quickshell.execDetached(["rm", "-rf", "--", workDir]);
        phase = "idle";
    }

    function formatBytes(bytes) {
        if (bytes >= 1024 * 1024)
            return (bytes / 1024 / 1024).toFixed(1) + " MB";
        return Math.max(1, Math.round(bytes / 1024)) + " KB";
    }

    Process {
        id: selectProcess

        // slurp reads region suggestions from non-terminal stdin before showing its overlay.
        command: ["sh", "-c", 'exec "$1" -f "%o %x,%y %wx%h" </dev/null', "sh", root.slurp]
        stdout: StdioCollector {
            onStreamFinished: root.startRecording(text.trim())
        }
    }

    Process {
        id: recorder

        stderr: StdioCollector {
            id: recorderErrors
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.finish();
                root.notify("Recording failed", recorderErrors.text.trim() || ("wf-recorder exited with code " + exitCode));
                return;
            }
            prepareProcess.running = true;
        }
    }

    // Reads the clip length and the XDG videos directory before the review opens.
    Process {
        id: prepareProcess

        command: ["sh", "-c", '"$1" -v error -show_entries format=duration -of csv=p=0 "$2" && "$3" VIDEOS', "sh", root.ffprobe, root.sourceFile, root.xdgUserDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const durationMs = Math.round(Number(lines[0]) * 1000);
                if (!(durationMs > 0) || !lines[1]) {
                    root.notify("Recording failed", "Could not read the recorded clip.");
                    root.finish();
                    return;
                }
                root.sourceMs = durationMs;
                root.trimStartMs = 0;
                root.trimEndMs = durationMs;
                root.videosDir = lines[1];
                root.qualityIndex = root.defaultQuality;
                root.frameRateIndex = 0;
                root.phase = "review";
                review.open();
                root.encode();
            }
        }
    }

    Component {
        id: encodeComponent

        Process {
            id: job

            property int generation
            property int startMs
            property string settings
            property string output

            stderr: StdioCollector {
                id: encodeErrors
            }
            onExited: exitCode => root.encodeFinished(job, exitCode, encodeErrors.text.trim())
        }
    }

    Process {
        id: sizeProcess

        stdout: StdioCollector {
            onStreamFinished: root.previewBytes = Number(text.trim()) || 0
        }
    }

    Process {
        id: saveProcess

        property string target
        property int generation

        onExited: exitCode => {
            if (generation !== root.generation || root.phase !== "review")
                return;
            if (exitCode === 3) {
                root.saveError = "A file with this name already exists";
                return;
            }
            if (exitCode !== 0) {
                root.saveError = "Could not save the file";
                return;
            }
            root.notify("Recording saved", target.split("/").pop() + " (" + root.formatBytes(root.previewBytes) + ") is on the clipboard.");
            root.finish();
        }
    }

    ReviewWindow {
        id: review

        daemon: root
    }

    IpcHandler {
        target: "screenRecord"

        function toggle(): string {
            return root.toggle();
        }
    }

    Component.onDestruction: {
        if (recorder.running)
            recorder.signal(2);
    }
}
