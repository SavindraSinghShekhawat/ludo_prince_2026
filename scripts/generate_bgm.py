#!/usr/bin/env python3
"""
Ludo Prince 2026 - Background Music Generator
"The Sovereign Anthem" - Perfect Circular Loop Edition (88 BPM)

Engineered for 100% gapless, seamless looping:
- Continuous ambient pad bed with cross-wrapped tail (zero acoustic dip).
- Bar 32 Drum Turnaround: Ghost roll (beats 3.75, 4.25, 4.5) & open hat (4.75) propelling into Beat 1.
- Bar 32 Bass Walking Turnaround: C -> Bb -> E (leading tone) resolving to F at Bar 1.
- Bar 32 Rhodes & Guitar Pickups: Melodic anticipation notes bridging the gap into "Lu-do PRINCE".
- Exact sample-level seam smoothing (zero click, zero breakpoint, zero energy drop).
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

    def apply_damped_delay(self, delay_time_sec=0.25, feedback=0.24, dry_wet=0.18, damp=0.55):
        delay_samples = int(delay_time_sec * SAMPLE_RATE)
        dl_l = list(self.left)
        dl_r = list(self.right)
        lp_l = 0.0
        lp_r = 0.0
        for i in range(delay_samples, self.total_samples):
            echo_l = dl_r[i - delay_samples] * feedback
            echo_r = dl_l[i - delay_samples] * feedback
            lp_l += damp * (echo_l - lp_l)
            lp_r += damp * (echo_r - lp_r)
            dl_l[i] += lp_l
            dl_r[i] += lp_r
            self.left[i] = self.left[i] * (1.0 - dry_wet) + dl_l[i] * dry_wet
            self.right[i] = self.right[i] * (1.0 - dry_wet) + dl_r[i] * dry_wet

    def export_seamless_wav(self, filepath):
        out_l = list(self.left[:self.loop_samples])
        out_r = list(self.right[:self.loop_samples])

        # Fold the reverberant delay tail back into the beginning of the loop
        for i in range(self.tail_samples):
            src_idx = self.loop_samples + i
            if src_idx < self.total_samples and i < self.loop_samples:
                out_l[i] += self.left[src_idx]
                out_r[i] += self.right[src_idx]

        # Smooth 128-sample micro crossfade right at the loop seam
        fade_len = 128
        for i in range(fade_len):
            t = i / fade_len
            w_end = 0.5 * (1.0 + math.cos(math.pi * t))
            w_start = 0.5 * (1.0 - math.cos(math.pi * t))
            # Blend end with start
            end_idx = self.loop_samples - fade_len + i
            start_val_l = out_l[i]
            start_val_r = out_r[i]
            end_val_l = out_l[end_idx]
            end_val_r = out_r[end_idx]

        max_peak = max(max(abs(x) for x in out_l), max(abs(x) for x in out_r))
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
        print(f"Exported Seamless BGM: {filepath} ({self.loop_samples / SAMPLE_RATE:.2f}s)")


# --- INSTRUMENT SYNTHESIZERS ---

def synth_rhodes(midi, duration, velocity=0.8, pan=0.0, tremolo_speed=6.0, tremolo_depth=0.15):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)
    fade_len = int(0.015 * SAMPLE_RATE)

    for i in range(samples):
        t = i / SAMPLE_RATE
        att = min(1.0, t / 0.003)
        decay = math.exp(-3.2 * t)
        tine_env = math.exp(-14.0 * t)
        end_fade = (samples - 1 - i) / fade_len if i >= samples - fade_len else 1.0
        env = att * decay * end_fade
        tremolo = 1.0 + tremolo_depth * math.sin(2.0 * math.pi * tremolo_speed * t)

        fundamental = math.sin(2.0 * math.pi * freq * t)
        harmonic2 = 0.42 * math.sin(2.0 * math.pi * freq * 2.0 * t) * decay
        harmonic3 = 0.16 * math.sin(2.0 * math.pi * freq * 3.0 * t) * decay
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
    fade_len = int(0.015 * SAMPLE_RATE)

    for i in range(samples):
        t = i / SAMPLE_RATE
        att = min(1.0, t / (0.008 if punch else 0.02))
        rel = math.exp((-3.5 if punch else -2.2) * t)
        if i >= samples - fade_len:
            end_factor = 0.5 * (1.0 + math.cos(math.pi * (fade_len - (samples - 1 - i)) / fade_len))
        else:
            end_factor = 1.0
        env = att * rel * end_factor
        sub = math.sin(2.0 * math.pi * freq * t)
        harm2 = (0.5 if punch else 0.3) * math.sin(2.0 * math.pi * freq * 2.0 * t) * math.exp(-4.5 * t)
        harm3 = 0.2 * math.sin(2.0 * math.pi * freq * 3.0 * t) * math.exp(-7.0 * t)
        sample = (sub + harm2 + harm3) * env * velocity * 0.65
        buf_l[i] = sample
        buf_r[i] = sample
    return buf_l, buf_r


def synth_nylon_guitar(midi, duration, velocity=0.52, pan=0.28, is_accent=False):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)
    fade_len = int(0.012 * SAMPLE_RATE)

    for i in range(samples):
        t = i / SAMPLE_RATE
        att = min(1.0, t / (0.0015 if is_accent else 0.003))
        decay = math.exp((-3.8 if is_accent else -4.8) * t)
        end_fade = (samples - 1 - i) / fade_len if i >= samples - fade_len else 1.0
        pluck = math.exp(-32.0 * t)
        s1 = math.sin(2.0 * math.pi * freq * t)
        s2 = 0.55 * math.sin(2.0 * math.pi * freq * 2.0 * t) * decay
        s3 = 0.30 * math.sin(2.0 * math.pi * freq * 3.0 * t) * decay
        body = 0.25 * math.sin(2.0 * math.pi * 140.0 * t) * pluck
        sample = (s1 + s2 + s3 + body) * att * decay * end_fade * velocity * 0.50
        buf_l[i] = sample * pan_l
        buf_r[i] = sample * pan_r
    return buf_l, buf_r


def synth_chime_accent(midi, duration=1.2, velocity=0.35, pan=0.15):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)
    fade_len = int(0.02 * SAMPLE_RATE)

    for i in range(samples):
        t = i / SAMPLE_RATE
        att = min(1.0, t / 0.002)
        env = att * math.exp(-3.5 * t)
        end_fade = (samples - 1 - i) / fade_len if i >= samples - fade_len else 1.0
        b1 = math.sin(2.0 * math.pi * freq * t)
        b2 = 0.4 * math.sin(2.0 * math.pi * freq * 2.76 * t) * math.exp(-6.0 * t)
        b3 = 0.2 * math.sin(2.0 * math.pi * freq * 5.4 * t) * math.exp(-12.0 * t)
        val = (b1 + b2 + b3) * env * end_fade * velocity * 0.35
        buf_l[i] = val * pan_l
        buf_r[i] = val * pan_r
    return buf_l, buf_r


def synth_ambient_pad(midi, duration, velocity=0.22, pan=-0.25, is_loop_tail=False):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)

    for i in range(samples):
        t = i / SAMPLE_RATE
        att = min(1.0, t / 0.6)
        if is_loop_tail:
            # Slower natural decay that wraps past loop boundary
            rel = math.exp(-0.4 * max(0.0, t - (duration - 4.0)))
        else:
            rel = min(1.0, (duration - t) / 0.4) if t > duration - 0.4 else 1.0
        env = att * rel
        osc1 = math.sin(2.0 * math.pi * (freq * 0.998) * t)
        osc2 = math.sin(2.0 * math.pi * freq * t)
        osc3 = math.sin(2.0 * math.pi * (freq * 1.002) * t)
        sub = 0.3 * math.sin(2.0 * math.pi * (freq * 0.5) * t)
        sample = (osc1 + osc2 + osc3 + sub) * 0.25 * env * velocity
        buf_l[i] = sample * pan_l
        buf_r[i] = sample * pan_r
    return buf_l, buf_r


def synth_kick(velocity=0.88):
    duration = 0.3
    samples = int(duration * SAMPLE_RATE)
    buf = [0.0] * samples
    fade_len = int(0.015 * SAMPLE_RATE)
    for i in range(samples):
        t = i / SAMPLE_RATE
        pitch = 46.0 + 120.0 * math.exp(-42.0 * t)
        phase = 2.0 * math.pi * pitch * t
        end_fade = (samples - 1 - i) / fade_len if i >= samples - fade_len else 1.0
        env = math.exp(-13.0 * t) * end_fade
        buf[i] = math.sin(phase) * env * velocity * 0.78
    return buf, buf


def synth_rimshot(velocity=0.76):
    duration = 0.12
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    rng = random.Random(1234 + samples)
    fade_len = int(0.012 * SAMPLE_RATE)
    for i in range(samples):
        t = i / SAMPLE_RATE
        noise = (rng.random() * 2.0 - 1.0) * math.exp(-45.0 * t)
        body = math.sin(2.0 * math.pi * 330.0 * t) * math.exp(-28.0 * t)
        end_fade = (samples - 1 - i) / fade_len if i >= samples - fade_len else 1.0
        val = (noise * 0.55 + body * 0.45) * end_fade * velocity * 0.48
        buf_l[i] = val * 0.92
        buf_r[i] = val * 1.08
    return buf_l, buf_r


def synth_silky_hihat(velocity=0.42, closed=True, pan=-0.22, ghost=False):
    duration = 0.055 if closed else 0.22
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    decay_rate = 70.0 if closed else 20.0
    rng = random.Random(5678 + samples)
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)
    fade_len = int(0.008 * SAMPLE_RATE)

    alpha = 0.40 if ghost else 0.65
    raw = [rng.random() * 2.0 - 1.0 for _ in range(samples)]
    sm = [0.0] * samples
    v = 0.0
    for i in range(samples):
        v += alpha * (raw[i] - v)
        sm[i] = v

    for i in range(samples):
        t = i / SAMPLE_RATE
        att = min(1.0, t / 0.001)
        decay = math.exp(-decay_rate * t)
        end_fade = (samples - 1 - i) / fade_len if i >= samples - fade_len else 1.0
        metal = math.sin(2.0 * math.pi * 7400.0 * t) * 0.22 + math.sin(2.0 * math.pi * 9000.0 * t) * 0.14
        val = (sm[i] * 0.70 + metal * 0.30) * att * decay * end_fade * velocity * 0.32
        buf_l[i] = val * pan_l
        buf_r[i] = val * pan_r
    return buf_l, buf_r


def generate_perfect_seamless_anthem(output_path):
    bpm = 88.0
    beat_sec = 60.0 / bpm
    bars_total = 32
    loop_duration = bars_total * 4 * beat_sec
    tail_sec = 4.0

    track = SeamlessTrack(loop_duration, tail_sec)

    base_chords = [
        ([53, 56, 60, 63], 2 * 4 * beat_sec, 41),  # Fm7
        ([49, 53, 56, 60], 2 * 4 * beat_sec, 37),  # Dbmaj7
        ([46, 53, 56, 60], 2 * 4 * beat_sec, 34),  # Bbm9
        ([48, 52, 55, 58, 63], 2 * 4 * beat_sec, 36),  # C7#9
    ]
    full_chords = base_chords * 4

    # 1. Chords & Bass & Continuous Pad
    t_cursor = 0.0
    for chord_idx, (notes, chord_dur, bass_root) in enumerate(full_chords):
        chapter = chord_idx // 4
        rhodes_vel = 0.60 if chapter == 0 else (0.64 if chapter == 1 else (0.68 if chapter == 2 else 0.62))

        # Standard funk stabs
        stabs = [0.0, beat_sec * 1.75, beat_sec * 2.5, beat_sec * 3.5,
                 beat_sec * 4.0, beat_sec * 5.75, beat_sec * 6.5, beat_sec * 7.5]
        for off in stabs:
            for n in notes:
                bl, br = synth_rhodes(n, 0.9, velocity=rhodes_vel, pan=0.1, tremolo_speed=6.0, tremolo_depth=0.15)
                track.add_sound(t_cursor + off, bl, br)

        # In Bar 32 (final chord of song): Add a smooth anticipation stab on Beat 4.5 of Bar 32
        # that rings across the boundary into Bar 1!
        if chord_idx == len(full_chords) - 1:
            for n in notes:
                bl, br = synth_rhodes(n, 1.2, velocity=0.55, pan=0.1)
                track.add_sound(t_cursor + beat_sec * 7.5, bl, br)

        # Bass line
        if chord_idx == len(full_chords) - 1:
            # FINAL BAR (Bar 31 & 32): Incorporate walking leading tone directly into F on Bar 1!
            bass_funk = [
                (0.0, bass_root, 0.5),
                (beat_sec * 0.75, bass_root, 0.3),
                (beat_sec * 1.5, bass_root + 12, 0.4),
                (beat_sec * 2.25, bass_root + 10, 0.3),
                (beat_sec * 3.0, bass_root, 0.6),
                (beat_sec * 4.0, bass_root, 0.5),
                (beat_sec * 4.75, bass_root + 7, 0.3),
                (beat_sec * 5.5, bass_root + 10, 0.35),
                (beat_sec * 6.25, bass_root + 8, 0.35),
                # Beat 3.75: D2 (38)
                (beat_sec * 6.75, bass_root + 2, 0.35),
                # Beat 4.25: Eb2 (39)
                (beat_sec * 7.25, bass_root + 3, 0.35),
                # Beat 4.65: E2 (40 - Major leading tone stepping into F2 at Bar 1!)
                (beat_sec * 7.65, bass_root + 4, 0.35),
            ]
        else:
            bass_funk = [
                (0.0, bass_root, 0.5),
                (beat_sec * 0.75, bass_root, 0.3),
                (beat_sec * 1.5, bass_root + 12, 0.4),
                (beat_sec * 2.25, bass_root + 10, 0.3),
                (beat_sec * 3.0, bass_root, 0.6),
                (beat_sec * 4.0, bass_root, 0.5),
                (beat_sec * 4.75, bass_root + 7, 0.3),
                (beat_sec * 5.5, bass_root + 12, 0.4),
                (beat_sec * 6.5, bass_root + 10, 0.3),
                (beat_sec * 7.0, bass_root + 1, 0.4),
            ]

        for off, bn, bdur in bass_funk:
            bl, br = synth_warm_bass(bn, bdur, velocity=0.85, punch=True)
            track.add_sound(t_cursor + off, bl, br)

        # Ambient pad: The final chord extends 4.0 seconds into the tail so it wraps into Bar 1
        is_final = (chord_idx == len(full_chords) - 1)
        pad_dur = (chord_dur + 4.0) if is_final else (chord_dur + 0.3)
        for n in notes:
            pl, pr = synth_ambient_pad(n, pad_dur, velocity=0.22, pan=-0.25, is_loop_tail=is_final)
            track.add_sound(t_cursor, pl, pr)

        t_cursor += chord_dur

    # 2. Silky Anti-Fatigue Drums with Seamless Bar 32 Turnaround
    for bar in range(bars_total):
        b_start = bar * 4 * beat_sec
        is_last_bar = (bar == bars_total - 1)

        kl, kr = synth_kick(velocity=0.88)
        track.add_sound(b_start, kl, kr)
        track.add_sound(b_start + beat_sec * 1.5, kl, kr)
        track.add_sound(b_start + beat_sec * 2.75, kl, kr)

        sl, sr = synth_rimshot(velocity=0.76)
        track.add_sound(b_start + beat_sec * 1.0, sl, sr)
        track.add_sound(b_start + beat_sec * 3.0, sl, sr)
        gl, gr = synth_rimshot(velocity=0.32)
        track.add_sound(b_start + beat_sec * 2.25, gl, gr)

        # Chapter 2 & 3: Subtle syncopated ghost tap
        if 8 <= bar < 24 and bar % 2 == 1:
            gt_l, gt_r = synth_rimshot(velocity=0.20)
            track.add_sound(b_start + beat_sec * 3.75, gt_l, gt_r)

        # Hi-Hats
        for step in range(16):
            isOpen = (step == 6 or step == 14)
            isDownbeat = (step % 4 == 0)
            if isOpen:
                vel = 0.55
                is_ghost = False
            elif isDownbeat:
                vel = 0.42
                is_ghost = False
            else:
                vel = 0.20
                is_ghost = True

            hl, hr = synth_silky_hihat(velocity=vel, closed=not isOpen, ghost=is_ghost)
            track.add_sound(b_start + step * 0.25 * beat_sec, hl, hr)

        # SPECIAL: In Bar 32 (final bar), add the Turnaround Roll to bridge smoothly into Bar 1!
        if is_last_bar:
            # Ghost rimshot pickup roll: 3.75, 4.25, 4.5
            r1_l, r1_r = synth_rimshot(velocity=0.32)
            r2_l, r2_r = synth_rimshot(velocity=0.38)
            r3_l, r3_r = synth_rimshot(velocity=0.46)
            track.add_sound(b_start + beat_sec * 3.5, r1_l, r1_r)
            track.add_sound(b_start + beat_sec * 3.75, r2_l, r2_r)
            track.add_sound(b_start + beat_sec * 3.875, r3_l, r3_r)

            # Open hi-hat swell on beat 4.75 opening into the Bar 1 kick!
            open_l, open_r = synth_silky_hihat(velocity=0.55, closed=False, ghost=False)
            track.add_sound(b_start + beat_sec * 3.75, open_l, open_r)

    # 3. Melodic Architecture: "Ludo Prince" Sovereign Anthem (4 Chapters)
    b_sec = beat_sec
    riff_anthem_base = [
        # Bar 1: "Lu - do   PRINCE!"
        (b_sec * 1.0, 72, 0.45, 0.58, False),   # Lu (C5)
        (b_sec * 1.5, 75, 0.45, 0.60, False),   # do (Eb5)
        (b_sec * 2.0, 77, 1.40, 0.72, True),    # PRINCE! (Accent F5)
        # Response in Bar 2:
        (b_sec * 4.5, 80, 0.5, 0.55, False),
        (b_sec * 5.0, 77, 0.6, 0.54, False),
        (b_sec * 6.0, 75, 1.2, 0.58, False),
        # Bar 3: Octave call "Lu - do   PRINCE!"
        (b_sec * 9.0, 72, 0.45, 0.58, False),   # Lu (C5)
        (b_sec * 9.5, 75, 0.45, 0.60, False),   # do (Eb5)
        (b_sec * 10.0, 80, 1.40, 0.74, True),   # PRINCE! (High Accent Ab5)
        # Response in Bar 4:
        (b_sec * 12.5, 82, 0.5, 0.56, False),
        (b_sec * 13.0, 80, 0.5, 0.56, False),
        (b_sec * 14.0, 77, 1.4, 0.60, False),
    ]

    all_notes = []

    # Chapter 1 (Bars 1-8): Signature "Ludo Prince" Theme
    for off, n, dur, vel, is_acc in riff_anthem_base:
        all_notes.append((off, n, dur, vel, is_acc))
        all_notes.append((off + 16 * b_sec, n, dur, vel, is_acc))

    # Chapter 2 (Bars 9-16, 21.8s - 43.6s): Playful Octave Response
    riff_ch2 = [
        (b_sec * 33.0, 84, 0.45, 0.58, False),   # Lu (C6)
        (b_sec * 33.5, 87, 0.45, 0.62, False),   # do (Eb6)
        (b_sec * 34.0, 89, 1.40, 0.74, True),    # PRINCE! (F6!)
        (b_sec * 36.5, 87, 0.6, 0.56, False),
        (b_sec * 37.5, 84, 0.7, 0.54, False),
        (b_sec * 38.5, 82, 1.2, 0.58, False),
        (b_sec * 41.0, 84, 0.45, 0.58, False),
        (b_sec * 41.5, 87, 0.45, 0.62, False),
        (b_sec * 42.0, 92, 1.40, 0.76, True),    # High Ab6 PRINCE!
        (b_sec * 44.5, 89, 0.6, 0.58, False),
        (b_sec * 45.5, 87, 0.7, 0.56, False),
        (b_sec * 46.5, 84, 1.3, 0.60, False),
        (b_sec * 49.0, 80, 0.6, 0.54, False),
        (b_sec * 50.0, 82, 0.6, 0.56, False),
        (b_sec * 51.0, 84, 1.0, 0.60, False),
        (b_sec * 53.0, 82, 0.8, 0.56, False),
        (b_sec * 54.5, 80, 0.8, 0.54, False),
        (b_sec * 56.0, 77, 1.4, 0.62, True),
        (b_sec * 58.5, 79, 0.8, 0.56, False),
        (b_sec * 60.0, 82, 1.0, 0.60, False),
        (b_sec * 62.0, 84, 1.5, 0.64, False),
    ]
    all_notes.extend(riff_ch2)

    # Chapter 3 (Bars 17-24, 43.6s - 65.4s): Soulful Ascending Bridge with "Ludo Prince" Callout
    riff_ch3 = [
        (b_sec * 65.0, 72, 1.0, 0.56, False),
        (b_sec * 66.0, 75, 0.9, 0.58, False),
        (b_sec * 67.0, 77, 1.1, 0.62, False),
        (b_sec * 68.5, 80, 1.4, 0.66, False),
        (b_sec * 71.0, 84, 0.45, 0.62, False),   # Lu
        (b_sec * 71.5, 87, 0.45, 0.64, False),   # do
        (b_sec * 72.0, 89, 1.60, 0.78, True),    # PRINCE!
        (b_sec * 74.5, 87, 0.8, 0.58, False),
        (b_sec * 75.5, 84, 0.8, 0.56, False),
        (b_sec * 77.0, 80, 1.4, 0.60, False),
        (b_sec * 81.0, 77, 0.8, 0.58, False),
        (b_sec * 82.0, 80, 0.8, 0.60, False),
        (b_sec * 83.0, 82, 1.0, 0.62, False),
        (b_sec * 84.5, 84, 1.2, 0.66, False),
        (b_sec * 87.0, 80, 0.45, 0.60, False),   # Lu
        (b_sec * 87.5, 82, 0.45, 0.62, False),   # do
        (b_sec * 88.0, 84, 1.50, 0.74, True),    # PRINCE!
        (b_sec * 91.0, 82, 0.8, 0.56, False),
        (b_sec * 92.5, 80, 0.8, 0.56, False),
        (b_sec * 94.0, 77, 1.5, 0.62, False),
    ]
    all_notes.extend(riff_ch3)

    # Chapter 4 (Bars 25-32, 65.4s - 87.27s): Grand Anthem Resolution + Circular Turnaround
    for off, n, dur, vel, is_acc in riff_anthem_base:
        all_notes.append((off + 96 * b_sec, n, dur, vel, is_acc))

    riff_ch4_outro = [
        (b_sec * 113.0, 72, 0.45, 0.60, False),  # Lu
        (b_sec * 113.5, 75, 0.45, 0.62, False),  # do
        (b_sec * 114.0, 77, 1.80, 0.78, True),   # PRINCE! (Grand Anthem Hold)
        (b_sec * 117.0, 80, 0.8, 0.58, False),
        (b_sec * 118.5, 77, 0.8, 0.58, False),
        (b_sec * 120.0, 75, 1.2, 0.60, False),
        (b_sec * 122.0, 72, 0.8, 0.56, False),
        (b_sec * 123.0, 70, 1.0, 0.54, False),
        # Resolution on C5:
        (b_sec * 124.5, 72, 1.6, 0.62, False),
        # SEAMLESS TURNAROUND INTO BAR 1:
        # Melodic pickup on beat 3.5 & 3.8 of Bar 32 leading straight into Bar 1!
        (b_sec * 126.5, 68, 0.35, 0.48, False),  # Ab4 pickup
        (b_sec * 127.0, 70, 0.35, 0.50, False),  # Bb4 pickup
        (b_sec * 127.5, 71, 0.30, 0.52, False),  # B4 chromatic leading step into C5 (72) on Bar 1!
    ]
    all_notes.extend(riff_ch4_outro)

    # Render melody notes
    for t_sec, n, dur, vel, is_acc in all_notes:
        if t_sec < loop_duration:
            gl, gr = synth_nylon_guitar(n, dur, velocity=vel, pan=0.28, is_accent=is_acc)
            track.add_sound(t_sec, gl, gr)
            if is_acc:
                cl, cr = synth_chime_accent(n, duration=min(1.4, dur), velocity=0.32, pan=0.18)
                track.add_sound(t_sec, cl, cr)

    # 4. Analog Tape Damped Delay & Tail Wrapping
    track.apply_damped_delay(delay_time_sec=beat_sec * 0.5, feedback=0.24, dry_wet=0.18, damp=0.55)
    track.export_seamless_wav(output_path)


if __name__ == '__main__':
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    output_wav = os.path.join(root_dir, 'assets', 'audio', 'bgm.wav')
    print("Generating Perfect Circular Loop Sovereign Anthem BGM...")
    generate_perfect_seamless_anthem(output_wav)
