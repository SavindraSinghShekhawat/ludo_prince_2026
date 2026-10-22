#!/usr/bin/env python3
"""
Ludo Prince 2026 - Background Music Generator (High Roller Groove)
Synthesizes the pure 32-bar extended seamless looping High Roller Groove (88 BPM).

Usage:
    python3 scripts/generate_bgm.py

Output:
    assets/audio/bgm.wav (44.1kHz 16-bit stereo WAV, ~87.27 seconds)
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100


def midi_to_freq(midi):
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))


class SeamlessTrack:
    def __init__(self, loop_sec, tail_sec=4.0):
        self.loop_samples = int(loop_sec * SAMPLE_RATE)
        self.tail_samples = int(tail_sec * SAMPLE_RATE)
        self.total_samples = self.loop_samples + self.tail_samples
        self.left = [0.0] * self.total_samples
        self.right = [0.0] * self.total_samples

    def add_sound(self, start_sec, buf_l, buf_r):
        start_idx = int(start_sec * SAMPLE_RATE)
        for i in range(len(buf_l)):
            idx = start_idx + i
            if 0 <= idx < self.total_samples:
                self.left[idx] += buf_l[i]
                self.right[idx] += buf_r[i]

    def apply_delay(self, delay_time_sec=0.25, feedback=0.25, dry_wet=0.18):
        delay_samples = int(delay_time_sec * SAMPLE_RATE)
        dl_l = list(self.left)
        dl_r = list(self.right)
        for i in range(delay_samples, self.total_samples):
            echo_l = dl_r[i - delay_samples] * feedback
            echo_r = dl_l[i - delay_samples] * feedback
            dl_l[i] += echo_l
            dl_r[i] += echo_r
            self.left[i] = self.left[i] * (1.0 - dry_wet) + dl_l[i] * dry_wet
            self.right[i] = self.right[i] * (1.0 - dry_wet) + dl_r[i] * dry_wet

    def export_seamless_wav(self, filepath):
        # Fold the reverberant delay tail back into the beginning of the loop
        out_l = list(self.left[:self.loop_samples])
        out_r = list(self.right[:self.loop_samples])

        for i in range(self.tail_samples):
            src_idx = self.loop_samples + i
            if src_idx < self.total_samples and i < self.loop_samples:
                out_l[i] += self.left[src_idx]
                out_r[i] += self.right[src_idx]

        # Normalize to target peak (-1.1 dBFS)
        max_peak = max(
            max(abs(x) for x in out_l),
            max(abs(x) for x in out_r),
        )
        if max_peak < 1e-6:
            max_peak = 1.0
        gain = 0.88 / max_peak

        out_data = bytearray()
        for i in range(self.loop_samples):
            l_val = math.tanh(out_l[i] * gain)
            r_val = math.tanh(out_r[i] * gain)
            l_int = max(-32767, min(32767, int(l_val * 32767.0)))
            r_int = max(-32767, min(32767, int(r_val * 32767.0)))
            out_data.extend(struct.pack('<hh', l_int, r_int))

        with wave.open(filepath, 'wb') as wav_file:
            wav_file.setnchannels(2)
            wav_file.setsampwidth(2)
            wav_file.setframerate(SAMPLE_RATE)
            wav_file.writeframes(out_data)
        print(f"Exported BGM: {filepath} ({self.loop_samples / SAMPLE_RATE:.2f}s)")


# --- INSTRUMENT SYNTHESIZERS ---

def synth_rhodes(midi, duration, velocity=0.8, pan=0.0, tremolo_speed=6.0, tremolo_depth=0.15):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)

    for i in range(samples):
        t = i / SAMPLE_RATE
        env = math.exp(-3.2 * t)
        tine_env = math.exp(-14.0 * t)
        tremolo = 1.0 + tremolo_depth * math.sin(2.0 * math.pi * tremolo_speed * t)
        
        fundamental = math.sin(2.0 * math.pi * freq * t)
        harmonic2 = 0.42 * math.sin(2.0 * math.pi * freq * 2.0 * t) * env
        harmonic3 = 0.16 * math.sin(2.0 * math.pi * freq * 3.0 * t) * env
        tine = 0.32 * math.sin(2.0 * math.pi * freq * 7.0 * t) * tine_env
        
        sample = (fundamental + harmonic2 + harmonic3 + tine) * env * velocity * tremolo * 0.45
        buf_l[i] = sample * pan_l
        buf_r[i] = sample * pan_r
    return buf_l, buf_r


def synth_warm_bass(midi, duration, velocity=0.85, punch=True):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples

    for i in range(samples):
        t = i / SAMPLE_RATE
        att = min(1.0, t / (0.008 if punch else 0.02))
        rel = math.exp((-3.5 if punch else -2.2) * t)
        env = att * rel
        
        sub = math.sin(2.0 * math.pi * freq * t)
        harm2 = (0.5 if punch else 0.3) * math.sin(2.0 * math.pi * freq * 2.0 * t) * math.exp(-4.5 * t)
        harm3 = 0.2 * math.sin(2.0 * math.pi * freq * 3.0 * t) * math.exp(-7.0 * t)
        
        sample = (sub + harm2 + harm3) * env * velocity * 0.65
        buf_l[i] = sample
        buf_r[i] = sample
    return buf_l, buf_r


def synth_nylon_guitar(midi, duration, velocity=0.6, pan=0.3):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)

    for i in range(samples):
        t = i / SAMPLE_RATE
        env = math.exp(-5.0 * t)
        pluck = math.exp(-30.0 * t)
        s1 = math.sin(2.0 * math.pi * freq * t)
        s2 = 0.5 * math.sin(2.0 * math.pi * freq * 2.0 * t) * env
        s3 = 0.25 * math.sin(2.0 * math.pi * freq * 3.0 * t) * env
        body = 0.2 * math.sin(2.0 * math.pi * 140.0 * t) * pluck
        sample = (s1 + s2 + s3 + body) * env * velocity * 0.5
        buf_l[i] = sample * pan_l
        buf_r[i] = sample * pan_r
    return buf_l, buf_r


def synth_ambient_pad(midi, duration, velocity=0.25, pan=-0.2):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)

    for i in range(samples):
        t = i / SAMPLE_RATE
        att = min(1.0, t / 0.8)
        rel = min(1.0, (duration - t) / 0.8) if t > duration - 0.8 else 1.0
        env = att * rel
        osc1 = math.sin(2.0 * math.pi * (freq * 0.998) * t)
        osc2 = math.sin(2.0 * math.pi * freq * t)
        osc3 = math.sin(2.0 * math.pi * (freq * 1.002) * t)
        sub = 0.3 * math.sin(2.0 * math.pi * (freq * 0.5) * t)
        sample = (osc1 + osc2 + osc3 + sub) * 0.25 * env * velocity
        buf_l[i] = sample * pan_l
        buf_r[i] = sample * pan_r
    return buf_l, buf_r


def synth_kick(velocity=0.9):
    duration = 0.3
    samples = int(duration * SAMPLE_RATE)
    buf = [0.0] * samples
    for i in range(samples):
        t = i / SAMPLE_RATE
        pitch = 46.0 + 120.0 * math.exp(-42.0 * t)
        phase = 2.0 * math.pi * pitch * t
        env = math.exp(-13.0 * t)
        buf[i] = math.sin(phase) * env * velocity * 0.8
    return buf, buf


def synth_rimshot(velocity=0.8):
    duration = 0.12
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    rng = random.Random(1234 + samples)
    for i in range(samples):
        t = i / SAMPLE_RATE
        noise = (rng.random() * 2.0 - 1.0) * math.exp(-45.0 * t)
        body = math.sin(2.0 * math.pi * 330.0 * t) * math.exp(-28.0 * t)
        val = (noise * 0.6 + body * 0.4) * velocity * 0.5
        buf_l[i] = val * 0.9
        buf_r[i] = val * 1.1
    return buf_l, buf_r


def synth_hihat(velocity=0.5, closed=True, pan=-0.2):
    duration = 0.06 if closed else 0.22
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    decay_rate = 65.0 if closed else 20.0
    rng = random.Random(5678 + samples)
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)
    for i in range(samples):
        t = i / SAMPLE_RATE
        noise = (rng.random() * 2.0 - 1.0)
        metal = math.sin(2.0 * math.pi * 7800.0 * t) * 0.3 + math.sin(2.0 * math.pi * 9400.0 * t) * 0.2
        val = (noise * 0.7 + metal * 0.3) * math.exp(-decay_rate * t) * velocity * 0.35
        buf_l[i] = val * pan_l
        buf_r[i] = val * pan_r
    return buf_l, buf_r


def generate_high_roller_bgm(output_path):
    bpm = 88.0
    beat_sec = 60.0 / bpm
    bars_total = 32
    loop_duration = bars_total * 4 * beat_sec  # ~87.27 seconds
    tail_sec = 4.0

    track = SeamlessTrack(loop_duration, tail_sec)

    # Fm7 -> Dbmaj7 -> Bbm9 -> C7#9 (4 cycles of 8 bars)
    base_chords = [
        ([53, 56, 60, 63], 2 * 4 * beat_sec, 41),  # Fm7 / F2
        ([49, 53, 56, 60], 2 * 4 * beat_sec, 37),  # Dbmaj7 / Db2
        ([46, 53, 56, 60], 2 * 4 * beat_sec, 34),  # Bbm9 / Bb1
        ([48, 52, 55, 58, 63], 2 * 4 * beat_sec, 36),  # C7#9 / C2
    ]
    full_chords = base_chords * 4

    # 1. Chords, Bass, Pad
    t_cursor = 0.0
    for notes, chord_dur, bass_root in full_chords:
        stabs = [0.0, beat_sec * 1.75, beat_sec * 2.5, beat_sec * 3.5,
                 beat_sec * 4.0, beat_sec * 5.75, beat_sec * 6.5, beat_sec * 7.5]
        for off in stabs:
            for n in notes:
                bl, br = synth_rhodes(n, 0.9, velocity=0.62, pan=0.1, tremolo_speed=6.0, tremolo_depth=0.15)
                track.add_sound(t_cursor + off, bl, br)

        bass_funk = [
            (0.0, bass_root, 0.5),
            (beat_sec * 0.75, bass_root, 0.3),
            (beat_sec * 1.5, bass_root + 12, 0.4),  # octave pop
            (beat_sec * 2.25, bass_root + 10, 0.3),
            (beat_sec * 3.0, bass_root, 0.6),
            (beat_sec * 4.0, bass_root, 0.5),
            (beat_sec * 4.75, bass_root + 7, 0.3),
            (beat_sec * 5.5, bass_root + 12, 0.4),  # octave pop
            (beat_sec * 6.5, bass_root + 10, 0.3),
            (beat_sec * 7.0, bass_root + 1, 0.4),
        ]
        for off, bn, bdur in bass_funk:
            bl, br = synth_warm_bass(bn, bdur, velocity=0.85, punch=True)
            track.add_sound(t_cursor + off, bl, br)

        for n in notes:
            pl, pr = synth_ambient_pad(n, chord_dur * 0.95, velocity=0.25, pan=-0.2)
            track.add_sound(t_cursor, pl, pr)

        t_cursor += chord_dur

    # 2. Drums
    for bar in range(bars_total):
        b_start = bar * 4 * beat_sec
        kl, kr = synth_kick(velocity=0.9)
        track.add_sound(b_start, kl, kr)
        track.add_sound(b_start + beat_sec * 1.5, kl, kr)
        track.add_sound(b_start + beat_sec * 2.75, kl, kr)

        sl, sr = synth_rimshot(velocity=0.8)
        track.add_sound(b_start + beat_sec * 1.0, sl, sr)
        track.add_sound(b_start + beat_sec * 3.0, sl, sr)
        gl, gr = synth_rimshot(velocity=0.35)
        track.add_sound(b_start + beat_sec * 2.25, gl, gr)

        for step in range(16):
            isOpen = (step == 6 or step == 14)
            vel = 0.5 if step % 4 == 0 else (0.6 if isOpen else 0.32)
            hl, hr = synth_hihat(velocity=vel, closed=not isOpen)
            track.add_sound(b_start + step * 0.25 * beat_sec, hl, hr)

    # 3. Guitar Riff
    base_riff = [
        (beat_sec * 1.0, 68), (beat_sec * 1.5, 70), (beat_sec * 2.0, 72), (beat_sec * 3.0, 75),
        (beat_sec * 5.0, 72), (beat_sec * 6.0, 70), (beat_sec * 7.0, 68),
        (beat_sec * 9.0, 75), (beat_sec * 10.0, 77), (beat_sec * 11.0, 80),
        (beat_sec * 13.0, 77), (beat_sec * 14.5, 75), (beat_sec * 15.0, 72),
    ]
    for cycle in range(2):
        cycle_start = cycle * 16 * beat_sec
        for off, n in base_riff:
            t = cycle_start + off
            if t < loop_duration:
                gl, gr = synth_nylon_guitar(n, 1.0, velocity=0.6, pan=0.3)
                track.add_sound(t, gl, gr)

    # 4. Delay & Seamless Tail Wrapping
    track.apply_delay(delay_time_sec=beat_sec * 0.5, feedback=0.25, dry_wet=0.18)
    track.export_seamless_wav(output_path)


if __name__ == '__main__':
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    output_wav = os.path.join(root_dir, 'assets', 'audio', 'bgm.wav')
    print("Generating High Roller Groove BGM...")
    generate_high_roller_bgm(output_wav)
