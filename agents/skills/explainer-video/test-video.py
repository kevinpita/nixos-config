#!/usr/bin/env python3
import argparse
import hashlib
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

from media import (FPS, RATE, SAMPLE_BYTES, SAMPLES_PER_FRAME, assemble_pcm, encode_aac, ffmpeg, mux,
                   new_wav, sha256, timeline_from_manifest, verify_master, write_json)

CHECK = Path(__file__).with_name('check-video.py')


def identity(job):
    write_json(job / 'encode.json', {'master_sha256': sha256(job / 'narration.wav'),
                                    'reference_sha256': sha256(job / 'reference.m4a')})


def checker(video, manifest):
    return subprocess.run([sys.executable, '-B', str(CHECK), str(video), str(manifest)],
                          text=True, capture_output=True)


def expect(case, video, manifest, status, *messages):
    result = checker(video, manifest)
    text = (result.stderr + result.stdout).strip().replace('\n', ' | ')
    print(f'{case}: exit {result.returncode}: {text}', flush=True)
    return result.returncode == status and all(message in text for message in messages)


def pcm(path, source, frames):
    ffmpeg('-y', '-f', 'lavfi', '-i', source, '-af', f'atrim=end_sample={frames * SAMPLES_PER_FRAME}',
           '-ac', '1', '-ar', str(RATE), '-c:a', 'pcm_s16le', str(path))


def chirp(path, frames, base):
    pcm(path, f'aevalsrc=0.2*(0.6+0.4*sin(38*t))*sin(2*PI*({base}*t+390*t*t)):s={RATE}', frames)


def synthetic_video(path, frames, size):
    ffmpeg('-y', '-f', 'lavfi', '-i', f'color=c=0x17394a:s={size}:r={FPS}', '-frames:v', str(frames),
           '-c:v', 'libx264', '-threads:v', '2', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p',
           '-video_track_timescale', str(RATE), str(path))


def speech(path, start):
    with wave.open(str(path), 'rb') as wav:
        samples = wav.getnframes()
        assert samples % SAMPLES_PER_FRAME == 0
        digest = hashlib.sha256(wav.readframes(samples)).hexdigest()
    return {'id': path.stem, 'kind': 'speech', 'clip': path.name, 'start_frame': start,
            'frames': samples // SAMPLES_PER_FRAME, 'text': path.stem, 'pcm_sha256': digest}


def setup(job, beats):
    manifest = job / 'manifest.json'
    write_json(manifest, {'fps': FPS, 'scenes': [{'id': 'example', 'beats': beats}]})
    timeline = timeline_from_manifest(manifest)
    master, reference = job / 'narration.wav', job / 'reference.m4a'
    assemble_pcm(timeline, master)
    verify_master(timeline, master)
    encode_aac(master, reference)
    identity(job)
    visual = job / 'visuals.mp4'
    synthetic_video(visual, timeline.frames, '1920x1080')
    return manifest, master, reference, visual


def replace_window(master, output, beat, replacement):
    before = beat.start * SAMPLES_PER_FRAME
    count = beat.frames * SAMPLES_PER_FRAME
    assert len(replacement) == count * SAMPLE_BYTES
    with wave.open(str(master), 'rb') as src, new_wav(output) as dst:
        dst.writeframesraw(src.readframes(before))
        dst.writeframesraw(replacement)
        src.setpos(before + count)
        for block in iter(lambda: src.readframes(RATE), b''):
            dst.writeframesraw(block)


def tampered(master, beat, replacement, visuals, work, output):
    work.mkdir()
    altered = work / 'altered.wav'
    reference = work / 'altered.m4a'
    replace_window(master, altered, beat, replacement)
    encode_aac(altered, reference)
    mux(visuals, reference, output)


def wav_data(path):
    with wave.open(str(path), 'rb') as wav:
        return wav.readframes(wav.getnframes())


def swap_real(video, manifest, output):
    beats = [beat for beat in timeline_from_manifest(manifest).beats if beat.clip]
    beat = beats[len(beats) // 2]
    source = wav_data(beats[0].clip)
    size = beat.frames * SAMPLES_PER_FRAME * SAMPLE_BYTES
    replacement = (source * ((size + len(source) - 1) // len(source)))[:size]
    with tempfile.TemporaryDirectory() as scratch:
        tampered(manifest.parent / 'narration.wav', beat, replacement, video,
                 Path(scratch) / 'mutation', output)
    return expect('real swapped middle beat', output, manifest, 1, 'decoded AAC differs',
                  f'strongest mismatch: {beat.name};')


def basic_cases(job):
    first, middle, last = (job / name for name in ('first.wav', 'middle.wav', 'last.wav'))
    for path, frames, base in ((first, 18, 270), (middle, 9, 370), (last, 18, 620)):
        chirp(path, frames, base)
    manifest, master, reference, visual = setup(job, [speech(first, 0), speech(middle, 18), speech(last, 27)])
    valid = job / 'valid.mp4'
    mux(visual, reference, valid)
    yield expect('valid', valid, manifest, 0, '3 verified voice beats')

    beat = timeline_from_manifest(manifest).beats[1]
    wrong, tone = job / 'wrong.wav', job / 'tone.wav'
    chirp(wrong, 9, 520)
    pcm(tone, 'sine=f=1000:r=48000', 9)
    cases = {'missing middle clip': bytes(9 * SAMPLES_PER_FRAME * SAMPLE_BYTES),
             'same-length swapped middle clip': wav_data(wrong), 'tone replacing middle clip': wav_data(tone)}
    for i, (case, replacement) in enumerate(cases.items()):
        output = job / f'mutation-{i}.mp4'
        tampered(master, beat, replacement, visual, job / f'tamper-{i}', output)
        yield expect(case, output, manifest, 1, 'decoded AAC differs', 'strongest mismatch: example/middle;')

    small, small_mux = job / 'small.mp4', job / 'small-aac.mp4'
    synthetic_video(small, 45, '1280x720')
    mux(small, reference, small_mux)
    yield expect('720p', small_mux, manifest, 1, 'expected 1920x1080, got 1280x720')
    captions, subtitled = job / 'captions.srt', job / 'subtitled.mp4'
    captions.write_text('1\n00:00:00,000 --> 00:00:00,800\nA caption\n')
    ffmpeg('-y', '-i', str(valid), '-i', str(captions), '-map', '0:v:0', '-map', '0:a:0', '-map', '1:s:0',
           '-c', 'copy', '-c:s', 'mov_text', '-movie_timescale', str(RATE), str(subtitled))
    yield expect('subtitle stream', subtitled, manifest, 1, 'unexpected subtitle stream')
    yield expect('no audio', visual, manifest, 1, 'expected one narration audio stream, got 0')
    wrong_codec = job / 'alac.mp4'
    ffmpeg('-y', '-i', str(visual), '-i', str(master), '-map', '0:v:0', '-map', '1:a:0',
           '-c:v', 'copy', '-c:a', 'alac', '-movie_timescale', str(RATE), str(wrong_codec))
    yield expect('wrong audio codec', wrong_codec, manifest, 1, 'expected AAC, mono, 48000 Hz')
    no_edit = job / 'missing-edit-list.mp4'
    ffmpeg('-y', '-i', str(visual), '-i', str(reference), '-map', '0:v:0', '-map', '1:a:0',
           '-c', 'copy', '-use_editlist', '0', '-movie_timescale', str(RATE), str(no_edit))
    yield expect('AAC edit list removed', no_edit, manifest, 1, 'differs from manifest')


def pause_case(job, declared):
    job.mkdir()
    first, last = job / 'first.wav', job / 'last.wav'
    chirp(first, 18, 270)
    chirp(last, 18, 520)
    if declared:
        beats = [speech(first, 0), {'id': 'hold', 'kind': 'pause', 'start_frame': 18, 'frames': 45,
                                    'reason': 'Hold the finished picture.'}, speech(last, 63)]
    else:
        held = job / 'held.wav'
        with new_wav(held) as wav:
            wav.writeframes(wav_data(first) + bytes(45 * SAMPLES_PER_FRAME * SAMPLE_BYTES))
        beats = [speech(held, 0), speech(last, 63)]
    manifest, _, reference, visual = setup(job, beats)
    output = job / 'pause.mp4'
    mux(visual, reference, output)
    if declared:
        return expect('declared 1.5s pause', output, manifest, 0, 'WARN: example/hold: declared pause 1.500s')
    return expect('undeclared 1.5s gap', output, manifest, 1, 'example/held', 'unplanned quiet 1.500s')


def main():
    parser = argparse.ArgumentParser(description='Exercise the explainer checker through the real AAC encode and mux.')
    parser.add_argument('--swap', nargs=3, metavar=('VIDEO', 'MANIFEST', 'OUTPUT'), type=Path)
    args = parser.parse_args()
    if args.swap:
        return 0 if swap_real(*args.swap) else 1
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        results = list(basic_cases(root))
        results += [pause_case(root / 'declared', True), pause_case(root / 'undeclared', False)]
    return 0 if all(results) else 1


if __name__ == '__main__':
    sys.exit(main())
