#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

from media import (FPS, HEIGHT, PAUSE_WARNING_FRAMES, WIDTH, read_json, require, sha256,
                   timeline_from_manifest, verify_aac_clock, verify_decoded, verify_master,
                   verify_quiet, verify_video)


def check(video, manifest):
    timeline = timeline_from_manifest(manifest)
    job = manifest.resolve().parent
    master = job / 'narration.wav'
    reference = job / 'reference.m4a'
    identity = read_json(job / 'encode.json')
    verify_master(timeline, master)
    require(sha256(master) == identity['master_sha256'], 'narration master changed after reference encode')
    require(sha256(reference) == identity['reference_sha256'], 'AAC reference changed after encode')
    verify_video(video, timeline)
    verify_aac_clock(reference, timeline, 'reference')
    verify_aac_clock(video, timeline, 'final MP4')
    verify_decoded(timeline, reference, video)
    verify_quiet(timeline, master)
    verify_quiet(timeline, video)
    for beat in timeline.beats:
        if not beat.clip and beat.frames > PAUSE_WARNING_FRAMES:
            print(f'WARN: {beat.name}: declared pause {beat.frames / FPS:.3f}s', file=sys.stderr)
    count = sum(beat.clip is not None for beat in timeline.beats)
    print(f'PASS: {WIDTH}x{HEIGHT}, AAC, no subtitle stream, {timeline.frames / FPS:.3f}s, {count} verified voice beats')


def main():
    parser = argparse.ArgumentParser(description='Verify a final MP4 against the reference files in its manifest directory.')
    parser.add_argument('video', type=Path)
    parser.add_argument('manifest', type=Path)
    args = parser.parse_args()
    try:
        check(args.video, args.manifest)
    except (OSError, ValueError, KeyError, TypeError, ZeroDivisionError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
