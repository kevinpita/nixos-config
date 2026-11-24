#!/usr/bin/env python3
import argparse
import hashlib
import os
import re
import shutil
import sys
import tempfile
import unicodedata
import wave
from array import array
from fractions import Fraction
from pathlib import Path

from media import (FPS, HEIGHT, RATE, SAMPLES_PER_FRAME, WIDTH, assemble_pcm, encode_aac, ffmpeg,
                   mux, new_wav, probe, read_json, require, run, sha256, timeline_from_manifest,
                   verify_master, verify_quiet, write_json)

HERE = Path(__file__).resolve().parent
VOICES = {'es-es': ('es-ES', 'EXPLAINER_VOICE_ES_ES'), 'en-us': ('en-US', 'EXPLAINER_VOICE_EN_US')}
ALIASES = {'en': 'en-us', 'english': 'en-us', 'es': 'es-es', 'spanish': 'es-es',
           'español': 'es-es', 'castellano': 'es-es', 'spanish from spain': 'es-es'}


def resolve_voice(language):
    key = language.strip().casefold()
    key = ALIASES.get(key, key)
    require(key in VOICES, f'no pinned voice for {language!r}; available: es-ES, en-US')
    locale, variable = VOICES[key]
    path = os.environ.get(variable)
    require(path and Path(path).is_file(), 'pinned voice unavailable; run this driver with explainer-video-env')
    return locale, path


def slugify(topic):
    name = re.sub(r'[^\w]+', '-', unicodedata.normalize('NFKC', topic).casefold()).strip('-_')
    require(bool(name), 'topic must contain a letter or number')
    return name[:60]


def trim_voice(raw):
    data = ffmpeg('-i', str(raw), '-map', '0:a:0', '-ac', '1', '-ar', str(RATE), '-c:a', 'pcm_s16le',
                  '-f', 's16le', 'pipe:1', capture_output=True).stdout
    samples = array('h')
    samples.frombytes(data)
    if sys.byteorder != 'little':
        samples.byteswap()
    audible = 130  # about -48 dBFS; retain 40 ms around the audible region
    head = next((i for i, value in enumerate(samples) if abs(value) >= audible), None)
    require(head is not None, 'synthesis produced no audible signal')
    tail = next(i for i, value in enumerate(reversed(samples)) if abs(value) >= audible)
    pad = RATE * 40 // 1000
    start, end = max(0, head - pad), len(samples) - max(0, tail - pad)
    return data[start * 2:end * 2]


def synthesize(voice, text, folder, output):
    require(type(text) is str and any(c.isalnum() for c in text), 'speech beat needs narration text')
    lines = [' '.join(line.split()) for line in text.splitlines() if line.strip()]
    require(all(any(c.isalnum() for c in line) for line in lines), 'empty speech line')
    run('piper', '-m', voice, '-d', str(folder), '--sentence-silence', '0',
        input=('\n'.join(lines) + '\n').encode('utf-8'))
    files = sorted(folder.glob('*.wav'), key=lambda path: int(path.stem))
    require(len(files) == len(lines), f'Piper returned {len(files)} WAVs for {len(lines)} speech lines')
    pcm = bytes(RATE * 2 // 10).join(trim_voice(path) for path in files)
    count = len(pcm) // 2
    frames = (count + SAMPLES_PER_FRAME - 1) // SAMPLES_PER_FRAME
    pcm += bytes((frames * SAMPLES_PER_FRAME - count) * 2)
    with new_wav(output) as wav:
        wav.writeframes(pcm)
    return frames, hashlib.sha256(pcm).hexdigest()


def prepare(storyboard, job, voice):
    require(type(storyboard) is dict and type(storyboard.get('scenes')) is list, 'storyboard needs scenes')
    frame = 0
    actions, classes = set(), set()
    result = []
    clips = job / 'voice'
    clips.mkdir()
    with tempfile.TemporaryDirectory(dir=job) as scratch:
        scratch = Path(scratch)
        for scene_index, scene in enumerate(storyboard['scenes']):
            name, cls = scene['id'], scene['class']
            require(type(cls) is str and cls.isidentifier() and cls not in classes, f'{name}: Manim class must be unique')
            classes.add(cls)
            beats = []
            for beat_index, beat in enumerate(scene['beats']):
                item = {**beat, 'start_frame': frame}
                label = f'{name}/{beat["id"]}'
                if beat['kind'] == 'speech':
                    action = beat['action']
                    require(type(action) is str and action.startswith('draw_') and action.isidentifier(), f'{label}: use a draw_* method')
                    require((cls, action) not in actions, f'{label}: use a distinct draw method for each beat')
                    require(0 < Fraction(str(beat.get('motion', 1))) <= 1, f'{label}: motion must be in (0, 1]')
                    actions.add((cls, action))
                    path = clips / f'{scene_index}-{beat_index}.wav'
                    try:
                        frames, digest = synthesize(voice, beat['text'], scratch / path.stem, path)
                    except (ValueError, OSError) as error:
                        raise ValueError(f'{label}: {error}') from error
                    item.update(frames=frames, clip=str(path.relative_to(job)), pcm_sha256=digest)
                elif beat['kind'] == 'pause':
                    frames = beat['frames']
                else:
                    raise ValueError(f'{label}: unknown beat kind {beat["kind"]!r}')
                require(type(frames) is int and frames > 0, f'{label}: frames must be a positive integer')
                frame += frames
                beats.append(item)
            result.append({'id': name, 'class': cls, 'beats': beats})
    manifest = job / 'manifest.json'
    write_json(manifest, {'fps': FPS, 'scenes': result})
    return manifest


def render_visuals(job, manifest):
    env = {**os.environ, 'EXPLAINER_MANIFEST': str(manifest), 'PYTHONPATH': str(HERE), 'PYTHONDONTWRITEBYTECODE': '1'}
    inputs = []
    for index, scene in enumerate(read_json(manifest)['scenes']):
        output = f'scene-{index}.mp4'
        print(f'Rendering {scene["id"]}', flush=True)
        run('manim', 'render', '--renderer', 'cairo', '--disable_caching', '--progress_bar', 'none',
            '--resolution', f'{WIDTH},{HEIGHT}', '--fps', str(FPS), '--media_dir', str(job / 'media'),
            '--output_file', output, 'scenes.py', scene['class'], env=env, cwd=job)
        files = list((job / 'media').glob(f'videos/**/{output}'))
        require(len(files) == 1, f'{scene["id"]}: expected one rendered movie')
        streams = probe(files[0], '-show_streams')['streams']
        frames = sum(beat['frames'] for beat in scene['beats'])
        require(len(streams) == 1 and streams[0]['codec_type'] == 'video'
                and int(streams[0]['nb_frames']) == frames, f'{scene["id"]}: expected {frames} video-only frames')
        inputs.append(files[0])
    movie = job / 'visuals.mp4'
    args = [arg for path in inputs for arg in ('-i', str(path))]
    if len(inputs) == 1:
        filters = '[0:v]'
    else:
        filters = ''.join(f'[{i}:v]' for i in range(len(inputs))) + f'concat=n={len(inputs)}:v=1:a=0,'
    filters += f'setpts=N/({FPS}*TB)[v]'
    ffmpeg('-y', *args, '-filter_complex', filters, '-map', '[v]', '-r', str(FPS), '-c:v', 'libx264',
           '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', '-video_track_timescale', str(RATE), str(movie))
    return movie


def publish(candidate, output):
    target = output
    number = 1
    while True:
        try:
            os.link(candidate, target)
        except FileExistsError:
            number += 1
            target = output.with_name(f'{output.stem}-{number}{output.suffix}')
        else:
            candidate.unlink()
            return target


def render(topic, language, storyboard, scenes):
    locale, voice = resolve_voice(language)
    slug = slugify(topic)
    output = Path.cwd() / 'videos' / f'{slug}.{locale}.mp4'
    root = Path(os.environ.get('XDG_CACHE_HOME') or Path.home() / '.cache') / 'omp/explainer-video/jobs'
    root.mkdir(parents=True, exist_ok=True)
    job = Path(tempfile.mkdtemp(prefix=f'{slug}-', dir=root)).resolve()
    print(f'Job: {job}', flush=True)
    shutil.copyfile(storyboard, job / 'storyboard.json')
    shutil.copyfile(scenes, job / 'scenes.py')
    manifest = prepare(read_json(job / 'storyboard.json'), job, voice)
    timeline = timeline_from_manifest(manifest)
    master, reference = job / 'narration.wav', job / 'reference.m4a'
    assemble_pcm(timeline, master)
    verify_master(timeline, master)
    verify_quiet(timeline, master)
    encode_aac(master, reference)
    write_json(job / 'encode.json', {'master_sha256': sha256(master), 'reference_sha256': sha256(reference)})
    visuals = render_visuals(job, manifest)
    output.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent, prefix='.explainer-') as scratch:
        candidate = Path(scratch) / output.name
        mux(visuals, reference, candidate)
        run(sys.executable, '-B', str(HERE / 'check-video.py'), str(candidate), str(manifest))
        output = publish(candidate, output)
    print(f'Video: {output}')
    print(f'Manifest: {manifest}')


def main():
    parser = argparse.ArgumentParser(description='Render a narrated Manim storyboard and verify the final MP4.')
    parser.add_argument('--topic', required=True)
    parser.add_argument('--language', required=True)
    parser.add_argument('storyboard', type=Path)
    parser.add_argument('scenes', type=Path)
    args = parser.parse_args()
    try:
        render(args.topic, args.language, args.storyboard, args.scenes)
    except (OSError, ValueError, KeyError, TypeError, ZeroDivisionError, wave.Error) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
