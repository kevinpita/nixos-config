---
name: explainer-video
description: Render a narrated Manim explainer in the language you specify.
disable-model-invocation: true
---

# Explainer video

Render the final video at 1920×1080. Use the topic to set the length. Render without a preview. Narrate every visual beat in the requested language. Use labels and equations in the picture. Keep subtitles out of the picture and the MP4.

1. **Set the language.** Use `es-ES` for Spanish from Spain and `en-US` for English unless the user names another accent. If no language is given, ask for it. If a requested language or accent has no pinned voice, stop and name it. Use the provisioned runtime. If it is missing, read the Explainer video section in `~/nixos-config/omp/README.md` and give the build command. Use no network for synthesis, rendering, or checks.
1. **Write the storyboard.** Use Manim for a 3Blue1Brown-style explanation. Start with a concrete example. Use one scene for one idea. Keep the same color and shape for the same thing. Show each change while the voice explains it. Write a narration line for every beat, including titles, transitions, and the ending. Put separate sentences on separate lines within the same beat. Write symbols and acronyms as the voice should say them.
1. **Write the scene classes.** Use the storyboard format and timing helper below. Put any intended silence in a `pause` entry with a reason. Hold the picture still during a pause. Undeclared quiet over 0.5 seconds fails. A pause over 0.63 seconds gets a warning.
1. **Run the driver.** Run it from the session's requested working directory. Pass the topic, the language, and the two source files. The driver derives the animation times from the voice clips. It publishes the H.264/AAC MP4 in `videos/` only when `check-video.py` passes.
   The name includes the topic and locale, for example `videos/areas.es-ES.mp4`. If the name is taken, the driver adds `-2`, `-3`, and so on. Earlier videos stay unchanged.
1. **Check the pictures.** View frames from every scene of the final video. Check that all labels fit and there are no burned-in captions. Fix the scene source and run the driver again if a picture fails. Report the checked video path, language, duration, and job path. Keep the sources until the user accepts the video.

## Storyboard and scenes

Save the storyboard and the Manim source in a temporary directory. Use one class per scene. Use a `draw_*` method for each spoken beat. Return a Manim animation, an `AnimationGroup` for parallel changes, or a `Succession` for changes in order. If a beat holds a still diagram, return `None`. Use `prepare_scene` to set the initial picture. Use `motion` to give the animation part of the speech beat, then hold the final picture for the rest. Let `TimelineScene` call `play` and `wait`. If a visual change needs its own cue, split the beat.

```json
{
  "scenes": [{
    "id": "areas",
    "class": "Areas",
    "beats": [
      {"id": "square", "kind": "speech", "action": "draw_square", "motion": 0.7, "text": "Start with a square.\nIts side has length one."},
      {"id": "hold", "kind": "pause", "frames": 12, "reason": "Hold the square for inspection."},
      {"id": "circle", "kind": "speech", "action": "draw_circle", "text": "Fit a circle inside the square."}
    ]
  }]
}
```

```python
from manim import Circle, Create, Square
from timeline_scene import TimelineScene


class Areas(TimelineScene):
    def draw_square(self):
        return Create(Square())

    def draw_circle(self):
        return Create(Circle())
```

## Render and verify

Use the directory that contains this skill for `SKILL_DIR`. Use the output of the driver to locate the job.

```sh
runtime="$HOME/.cache/omp/explainer-video/runtime/bin/explainer-video-env"
"$runtime" python3 -B "$SKILL_DIR/render-video.py" --topic "$TOPIC" --language "$LOCALE" "$STORYBOARD" "$SCENES"
"$runtime" python3 -B "$SKILL_DIR/check-video.py" "$VIDEO" "$JOB/manifest.json"
```

The job stays in `${XDG_CACHE_HOME:-$HOME/.cache}/omp/explainer-video/jobs/`. It contains the storyboard, the scene source, the frozen voice clips, the manifest, and the AAC reference. `check-video.py` verifies the PCM master against each clip. It verifies the exact decoded AAC at each beat time and checks the resolution, duration, and stream types. It does not judge pronunciation, picture content, or burned-in text.
