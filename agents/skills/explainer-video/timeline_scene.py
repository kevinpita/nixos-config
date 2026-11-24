import os
from fractions import Fraction
from pathlib import Path

from manim import AnimationGroup, Scene, config

from media import FPS, HEIGHT, WIDTH, read_json, require


class TimelineScene(Scene):
    def prepare_scene(self):
        pass

    def construct(self):
        scene = next(s for s in read_json(Path(os.environ['EXPLAINER_MANIFEST']))['scenes']
                     if s['class'] == type(self).__name__)
        require((config.pixel_width, config.pixel_height, config.frame_rate) == (WIDTH, HEIGHT, FPS),
                'use the fixed render dimensions and frame rate')
        start = self.renderer.time
        self.prepare_scene()
        require(self.renderer.time == start, f'{scene["id"]}: setup emitted frames outside a beat')
        origin = scene['beats'][0]['start_frame']
        for beat in scene['beats']:
            name = f'{scene["id"]}/{beat["id"]}'
            start = self.renderer.time
            frames = beat['frames']
            if beat['kind'] == 'speech':
                animation = getattr(self, beat['action'])()
                require(self.renderer.time == start, f'{name}: action emitted frames; return the animation instead')
                if animation is not None:
                    portion = Fraction(str(beat.get('motion', 1)))
                    motion = max(1, round(frames * portion))
                    # Cairo's animation loop uses ceil; its static hold uses floor.
                    self.play(AnimationGroup(animation, run_time=(motion - 0.25) / FPS))
                    frames -= motion
            if frames:
                self.wait((frames + 0.25) / FPS, frozen_frame=True)
            end = beat['start_frame'] - origin + beat['frames']
            require(abs(self.renderer.time * FPS - end) < 0.01, f'{name}: renderer did not end on frame {end}')
