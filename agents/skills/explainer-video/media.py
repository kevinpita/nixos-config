import contextlib
import hashlib
import json
import re
import struct
import subprocess
import tempfile
import wave
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path

FPS = 30
WIDTH, HEIGHT = 1920, 1080
RATE = 48_000
SAMPLES_PER_FRAME = RATE // FPS
SAMPLE_BYTES = 2
AAC_FRAME = 1024
PAUSE_WARNING_FRAMES = 19
MAX_QUIET = 0.500
MIN_ACTIVE_FRAMES = 3
SILENCE_FILTER = 'silencedetect=n=-42dB:d=0.050'
IO_FRAMES = 30


@dataclass(frozen=True)
class Beat:
    name: str
    start: int
    frames: int
    clip: Path | None
    digest: str | None

    @property
    def end(self):
        return self.start + self.frames


@dataclass(frozen=True)
class Timeline:
    beats: tuple[Beat, ...]

    @property
    def frames(self):
        return self.beats[-1].end

    @property
    def samples(self):
        return self.frames * SAMPLES_PER_FRAME


def require(ok, message):
    if not ok:
        raise ValueError(message)


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def timeline_from_manifest(path):
    data = read_json(path)
    require(type(data) is dict and data.get('fps') == FPS, f'manifest fps must be {FPS}')
    scenes = data.get('scenes')
    require(type(scenes) is list and scenes, 'manifest needs at least one scene')
    frame = 0
    result, scene_ids = [], set()
    folder = path.resolve().parent
    for scene in scenes:
        name = scene['id']
        require(type(name) is str and name.strip() and name not in scene_ids, 'scene IDs must be unique and nonempty')
        scene_ids.add(name)
        beats = scene['beats']
        require(type(beats) is list and beats, f'{name}: missing beats')
        beat_ids = set()
        previous = None
        for i, beat in enumerate(beats):
            ident = beat['id']
            require(type(ident) is str and ident.strip() and ident not in beat_ids, f'{name}: beat IDs must be unique and nonempty')
            beat_ids.add(ident)
            label = f'{name}/{ident}'
            start, frames, kind = beat['start_frame'], beat['frames'], beat['kind']
            require(type(start) is int and start == frame, f'{label}: expected start frame {frame}, got {start!r}')
            require(type(frames) is int and frames > 0, f'{label}: frames must be a positive integer')
            clip, digest = None, None
            if kind == 'speech':
                text = beat['text']
                require(type(text) is str and any(c.isalnum() for c in text), f'{label}: missing narration text')
                require(frames >= MIN_ACTIVE_FRAMES, f'{label}: speech slot too short')
                source, digest = beat['clip'], beat['pcm_sha256']
                require(type(source) is str and source and not Path(source).is_absolute(), f'{label}: expected a relative WAV path')
                require(type(digest) is str and re.fullmatch('[0-9a-f]{64}', digest), f'{label}: missing PCM SHA-256')
                clip = (folder / source).resolve()
                require(clip.is_relative_to(folder), f'{label}: WAV path leaves the job directory')
            elif kind == 'pause':
                require(previous == 'speech' and i < len(beats) - 1, f'{label}: pause must be between speech beats')
                reason = beat['reason']
                require(type(reason) is str and reason.strip(), f'{label}: pause needs a reason')
            else:
                raise ValueError(f'{label}: unknown beat kind {kind!r}')
            result.append(Beat(label, start, frames, clip, digest))
            frame += frames
            previous = kind
    return Timeline(tuple(result))


def run(*args, **kwargs):
    result = subprocess.run(args, **kwargs)
    require(result.returncode == 0, f'{args[0]} exited {result.returncode}')
    return result


def ffmpeg(*args, **kwargs):
    return run('ffmpeg', '-nostdin', '-hide_banner', '-v', 'error', '-xerror', *args, **kwargs)


def probe(path, *args):
    return json.loads(run('ffprobe', '-v', 'error', *args, '-of', 'json', str(path.resolve()), stdout=subprocess.PIPE).stdout)


@contextlib.contextmanager
def read_pcm(path, label, samples):
    try:
        with wave.open(str(path), 'rb') as source:
            shape = source.getnchannels(), source.getsampwidth(), source.getframerate(), source.getnframes()
            require(shape == (1, SAMPLE_BYTES, RATE, samples), f'{label}: WAV format or duration mismatch: {shape}')
            yield source
    except (OSError, EOFError, wave.Error) as error:
        raise ValueError(f'{label}: cannot read WAV {path}: {error}') from error


def new_wav(path):
    wav = wave.open(str(path), 'wb')
    wav.setparams((1, SAMPLE_BYTES, RATE, 0, 'NONE', 'not compressed'))
    return wav


def beat_pcm(beat):
    samples = beat.frames * SAMPLES_PER_FRAME
    if beat.clip:
        with read_pcm(beat.clip, beat.name, samples) as wav:
            pcm = wav.readframes(samples)
        require(len(pcm) == samples * SAMPLE_BYTES, f'{beat.name}: truncated WAV')
        require(hashlib.sha256(pcm).hexdigest() == beat.digest, f'{beat.name}: source clip hash changed')
        yield pcm
    else:
        block = bytes(IO_FRAMES * SAMPLES_PER_FRAME * SAMPLE_BYTES)
        while samples:
            n = min(samples, IO_FRAMES * SAMPLES_PER_FRAME)
            yield block[:n * SAMPLE_BYTES]
            samples -= n


def assemble_pcm(timeline, master):
    with new_wav(master) as wav:
        for beat in timeline.beats:
            for chunk in beat_pcm(beat):
                wav.writeframesraw(chunk)


def verify_master(timeline, master):
    with read_pcm(master, 'narration master', timeline.samples) as wav:
        for beat in timeline.beats:
            for chunk in beat_pcm(beat):
                require(wav.readframes(len(chunk) // SAMPLE_BYTES) == chunk,
                        f'{beat.name}: PCM master differs at frame {beat.start}')


def encode_aac(master, reference):
    ffmpeg('-y', '-i', str(master), '-map', '0:a:0', '-c:a', 'aac', '-b:a', '128k',
           '-use_editlist', '1', '-movie_timescale', str(RATE), str(reference))


def mux(visuals, reference, output):
    ffmpeg('-y', '-i', str(visuals), '-i', str(reference), '-map', '0:v:0', '-map', '1:a:0',
           '-c', 'copy', '-map_metadata', '-1', '-map_chapters', '-1', '-use_editlist', '1',
           '-movie_timescale', str(RATE), '-movflags', '+faststart', str(output))


def verify_video(video, timeline):
    data = probe(video, '-show_streams', '-show_format')
    streams = data['streams']
    require(not any(s['codec_type'] == 'subtitle' for s in streams), 'unexpected subtitle stream')
    visuals = [s for s in streams if s['codec_type'] == 'video']
    require(len(visuals) == 1, f'expected one video stream, got {len(visuals)}')
    visual = visuals[0]
    width, height = visual['width'], visual['height']
    require((width, height) == (WIDTH, HEIGHT), f'expected {WIDTH}x{HEIGHT}, got {width}x{height}')
    require(visual.get('sample_aspect_ratio') in (None, 'N/A', '1:1'), 'video is not square pixel')
    for item in visual.get('side_data_list', []):
        require(float(item.get('rotation', 0)) % 360 == 0, 'video has rotation metadata')
    base = Fraction(visual['time_base'])
    expected = Fraction(timeline.frames, FPS)
    require(int(visual['start_pts']) == 0 and int(visual['duration_ts']) * base == expected,
            f'video duration or start differs from manifest ({float(expected):.6f}s at zero)')
    packets = probe(video, '-select_streams', 'v:0', '-show_packets', '-show_entries', 'packet=pts,duration')['packets']
    require(len(packets) == timeline.frames, f'expected {timeline.frames} video frames, got {len(packets)}')
    for frame, packet in enumerate(sorted(packets, key=lambda p: int(p['pts']))):
        require(int(packet['pts']) * base == Fraction(frame, FPS)
                and int(packet['duration']) * base == Fraction(1, FPS),
                f'video timestamp mismatch at frame {frame}')
    duration = Fraction(data['format']['duration'])
    require(Fraction(data['format']['start_time']) == 0 and abs(duration - expected) <= Fraction(1, 1_000_000),
            f'container duration or start differs from manifest ({float(expected):.6f}s at zero)')


def verify_aac_clock(path, timeline, label):
    data = probe(path, '-select_streams', 'a', '-show_streams', '-show_packets',
                 '-show_entries', 'stream=codec_name,channels,sample_rate,time_base,start_pts,duration_ts:packet=pts,duration:packet_side_data=skip_samples,discard_padding')
    streams = data['streams']
    require(len(streams) == 1, f'{label}: expected one narration audio stream, got {len(streams)}')
    audio = streams[0]
    require(audio.get('codec_name') == 'aac' and audio.get('channels') == 1 and audio.get('sample_rate') == str(RATE),
            f'{label}: expected AAC, mono, 48000 Hz')
    require(Fraction(audio['time_base']) == Fraction(1, RATE) and int(audio['start_pts']) == 0
            and int(audio['duration_ts']) == timeline.samples,
            f'{label}: AAC presentation must start at zero and end at sample {timeline.samples}')
    packets = data.get('packets', [])
    require(len(packets) >= 2, f'{label}: missing AAC packets')
    sample = -AAC_FRAME
    for i, packet in enumerate(packets):
        duration = int(packet['duration'])
        skip = sum(int(side.get('skip_samples', 0)) for side in packet.get('side_data_list', []))
        padding = sum(int(side.get('discard_padding', 0)) for side in packet.get('side_data_list', []))
        last = i == len(packets) - 1
        require(int(packet['pts']) == sample and 0 < duration <= AAC_FRAME and (last or duration == AAC_FRAME),
                f'{label}: noncontiguous AAC packets at sample {sample}')
        require(skip == (AAC_FRAME if i == 0 else 0) and padding == (AAC_FRAME - duration if last else 0),
                f'{label}: unexpected AAC priming or padding at sample {sample}: skip {skip}, pad {padding}')
        sample += duration
    require(sample == timeline.samples, f'{label}: AAC packets end at sample {sample}, expected {timeline.samples}')


@contextlib.contextmanager
def decoded_aac(path):
    cmd = ('ffmpeg', '-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-ignore_editlist', '0',
           '-i', str(path), '-map', '0:a:0', '-c:a', 'pcm_f32le', '-f', 'f32le', 'pipe:1')
    with tempfile.TemporaryFile() as log, subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=log) as process:
        try:
            yield process.stdout
            if process.wait():
                log.seek(0)
                message = log.read().decode(errors='replace').strip()
                raise ValueError(f'{path}: FFmpeg decode failed: {message}')
        finally:
            if process.poll() is None:
                process.kill()


def verify_decoded(timeline, reference, video):
    differences = []
    with decoded_aac(reference) as expected, decoded_aac(video) as actual:
        for beat in timeline.beats:
            frames = beat.frames
            energy = 0.0
            changed = False
            while frames:
                n = min(frames, IO_FRAMES)
                size = n * SAMPLES_PER_FRAME * 4
                ref, got = expected.read(size), actual.read(size)
                require(len(ref) == len(got) == size, f'{beat.name}: truncated AAC decode')
                if ref != got:
                    changed = True
                    energy += sum((a - b) ** 2 for (a,), (b,) in zip(struct.iter_unpack('<f', ref), struct.iter_unpack('<f', got)))
                frames -= n
            if changed:
                differences.append((energy, beat))
        require(not expected.read(1) and not actual.read(1), 'decoded AAC extends past the manifest')
    if differences:
        differences.sort(key=lambda item: item[0], reverse=True)
        names = ', '.join(beat.name for _, beat in differences)
        raise ValueError(f'decoded AAC differs from reference; strongest mismatch: {differences[0][1].name}; affected beats: {names}')


def overlap(a, b, c, d):
    return max(0.0, min(b, d) - max(a, c))


def verify_quiet(timeline, path):
    result = run('ffmpeg', '-nostdin', '-hide_banner', '-v', 'info', '-xerror', '-nostats',
                 '-i', str(path), '-map', '0:a:0', '-af', SILENCE_FILTER, '-f', 'null', '-',
                 stderr=subprocess.PIPE, text=True)
    end = timeline.frames / FPS
    quiet = []
    start = None
    for event, value in re.findall(r'\bsilence_(start|end):\s*(-?[\d.]+)', result.stderr):
        time = max(0.0, min(end, float(value)))
        if event == 'start':
            require(start is None, 'FFmpeg reported overlapping quiet intervals')
            start = time
        else:
            require(start is not None and time >= start, 'FFmpeg reported invalid quiet interval')
            quiet.append((start, time))
            start = None
    if start is not None:
        quiet.append((start, end))
    speech = [b for b in timeline.beats if b.clip]
    pauses = [b for b in timeline.beats if not b.clip]
    for a, b in quiet:
        extra = b - a - sum(overlap(a, b, p.start / FPS, p.end / FPS) for p in pauses)
        if extra > MAX_QUIET + 1e-6:
            names = ', '.join(s.name for s in speech if overlap(a, b, s.start / FPS, s.end / FPS))
            raise ValueError(f'{names}: unplanned quiet {extra:.3f}s in {a:.3f}–{b:.3f}s')
    for s in speech:
        start, end = s.start / FPS, s.end / FPS
        active = end - start - sum(overlap(start, end, a, b) for a, b in quiet)
        require(active + 1e-6 >= MIN_ACTIVE_FRAMES / FPS, f'{s.name}: less than 0.100s outside detected quiet')


def sha256(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()
