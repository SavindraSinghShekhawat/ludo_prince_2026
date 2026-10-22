#!/usr/bin/env python3
"""
Ludo Prince 2026 - High Roller Groove Evolutions & Alternatives
Synthesizes 4 elevated alternatives based on the "High Roller Groove" direction:
1. Diamond Cut (Polished Master Evolution - A/B Progression, MPC Pocket Swing, 88 BPM)
2. Casino Royale (Brass & Smoke - Cinematic Retro Funk, Muted Stabs & Swagger, 90 BPM)
3. Tokyo Nights (Future Neo-Soul - Moog Synth Bass, Chorus Rhodes & Kaytranada Bounce, 86 BPM)
4. Gentleman's Wager (Acoustic Nu-Jazz Trio - Upright Double Bass, Brushes & Grand Piano, 89 BPM)
"""

import math
import struct
import wave
import os
import random

SAMPLE_RATE = 44100

def midi_to_freq(midi):
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))

class StereoTrack:
    def __init__(self, duration_sec):
        self.num_samples = int(duration_sec * SAMPLE_RATE)
        self.left = [0.0] * self.num_samples
        self.right = [0.0] * self.num_samples

    def add_sound(self, start_sec, buffer_l, buffer_r):
        start_idx = int(start_sec * SAMPLE_RATE)
        for i in range(len(buffer_l)):
            idx = start_idx + i
            if 0 <= idx < self.num_samples:
                self.left[idx] += buffer_l[i]
                self.right[idx] += buffer_r[i]

    def apply_pingpong_delay(self, delay_time_sec=0.25, feedback=0.28, dry_wet=0.20):
        delay_samples = int(delay_time_sec * SAMPLE_RATE)
        dl_l = list(self.left)
        dl_r = list(self.right)
        for i in range(delay_samples, self.num_samples):
            echo_l = dl_r[i - delay_samples] * feedback
            echo_r = dl_l[i - delay_samples] * feedback
            dl_l[i] += echo_l
            dl_r[i] += echo_r
            self.left[i] = self.left[i] * (1.0 - dry_wet) + dl_l[i] * dry_wet
            self.right[i] = self.right[i] * (1.0 - dry_wet) + dl_r[i] * dry_wet

    def add_tape_saturation(self, drive=1.2):
        for i in range(self.num_samples):
            self.left[i] = math.tanh(self.left[i] * drive) / drive
            self.right[i] = math.tanh(self.right[i] * drive) / drive

    def export_wav(self, filepath):
        max_peak = max(
            max(abs(x) for x in self.left),
            max(abs(x) for x in self.right)
        )
        if max_peak < 1e-6:
            max_peak = 1.0
        
        target_peak = 0.88
        gain = target_peak / max_peak

        out_data = bytearray()
        for i in range(self.num_samples):
            l_val = math.tanh(self.left[i] * gain)
            r_val = math.tanh(self.right[i] * gain)
            l_int = int(l_val * 32767.0)
            r_int = int(r_val * 32767.0)
            l_int = max(-32767, min(32767, l_int))
            r_int = max(-32767, min(32767, r_int))
            out_data.extend(struct.pack('<hh', l_int, r_int))

        with wave.open(filepath, 'wb') as wav_file:
            wav_file.setnchannels(2)
            wav_file.setsampwidth(2)
            wav_file.setframerate(SAMPLE_RATE)
            wav_file.writeframes(out_data)
        print(f"Exported: {filepath} ({self.num_samples / SAMPLE_RATE:.1f}s)")

# --- ADVANCED INSTRUMENT SOUND ENGINES ---

def synth_rhodes(midi, duration, velocity=0.8, pan=0.0, tremolo_speed=5.2, tremolo_depth=0.22, chorus=True):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)

    for i in range(samples):
        t = i / SAMPLE_RATE
        env = math.exp(-3.2 * t)
        tine_env = math.exp(-15.0 * t)
        tremolo = 1.0 + tremolo_depth * math.sin(2.0 * math.pi * tremolo_speed * t)
        
        # Fundamental + tine harmonics + subtle chorus detune
        detune = 1.0015 if chorus else 1.0
        s1 = math.sin(2.0 * math.pi * freq * t)
        s1_c = math.sin(2.0 * math.pi * (freq * detune) * t) if chorus else s1
        h2 = 0.42 * math.sin(2.0 * math.pi * freq * 2.0 * t) * env
        h3 = 0.18 * math.sin(2.0 * math.pi * freq * 3.0 * t) * env
        tine = 0.35 * math.sin(2.0 * math.pi * freq * 7.0 * t) * tine_env
        
        sample_l = ((s1 * 0.7 + s1_c * 0.3) + h2 + h3 + tine) * env * velocity * tremolo * 0.45 * pan_l
        sample_r = ((s1 * 0.3 + s1_c * 0.7) + h2 + h3 + tine) * env * velocity * tremolo * 0.45 * pan_r
        buf_l[i] = sample_l
        buf_r[i] = sample_r
    return buf_l, buf_r

def synth_moog_bass(midi, duration, velocity=0.9, glide_from=None):
    freq_target = midi_to_freq(midi)
    freq_start = midi_to_freq(glide_from) if glide_from else freq_target
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples

    phase = 0.0
    for i in range(samples):
        t = i / SAMPLE_RATE
        # Portamento glide
        glide_prog = min(1.0, t / 0.04) if glide_from else 1.0
        cur_freq = freq_start + (freq_target - freq_start) * glide_prog

        att = min(1.0, t / 0.006) # punchy attack
        rel = math.exp(-3.0 * t)
        env = att * rel

        phase += 2.0 * math.pi * cur_freq / SAMPLE_RATE
        
        # Moog 24dB ladder filter emulation (Sub + Saw + resonance punch)
        sub = math.sin(phase)
        saw = (phase % (2.0 * math.pi)) / math.pi - 1.0
        # low pass filtering
        cutoff_env = math.exp(-6.0 * t)
        harm = saw * (0.35 + 0.35 * cutoff_env)
        
        val = (sub * 0.75 + harm * 0.45) * env * velocity * 0.7
        buf_l[i] = val
        buf_r[i] = val
    return buf_l, buf_r

def synth_upright_bass(midi, duration, velocity=0.85):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples

    for i in range(samples):
        t = i / SAMPLE_RATE
        att = min(1.0, t / 0.015)
        rel = math.exp(-2.2 * t)
        env = att * rel

        # Finger pluck acoustic body resonance (wood body thud at ~110Hz)
        body = math.sin(2.0 * math.pi * 110.0 * t) * math.exp(-25.0 * t) * 0.3
        s1 = math.sin(2.0 * math.pi * freq * t)
        s2 = 0.45 * math.sin(2.0 * math.pi * freq * 2.0 * t) * math.exp(-3.5 * t)
        s3 = 0.18 * math.sin(2.0 * math.pi * freq * 3.0 * t) * math.exp(-6.0 * t)
        
        val = (s1 + s2 + s3 + body) * env * velocity * 0.65
        buf_l[i] = val
        buf_r[i] = val
    return buf_l, buf_r

def synth_brass_stab(midi, duration=0.35, velocity=0.75, pan=0.2):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)

    for i in range(samples):
        t = i / SAMPLE_RATE
        # Brass envelope: quick attack swell, crisp decay
        att = min(1.0, t / 0.02)
        dec = math.exp(-7.0 * t)
        env = att * dec

        # Harmonically rich saw wave with lip-buzz filter sweep
        phase = 2.0 * math.pi * freq * t
        s1 = math.sin(phase)
        s2 = 0.5 * math.sin(phase * 2.0)
        s3 = 0.35 * math.sin(phase * 3.0)
        s4 = 0.25 * math.sin(phase * 4.0)
        s5 = 0.15 * math.sin(phase * 5.0)

        # Muted trumpet / horn formant filter
        formant = 1.0 + 0.4 * math.sin(2.0 * math.pi * 1800.0 * t) * math.exp(-15.0 * t)
        val = (s1 + s2 + s3 + s4 + s5) * 0.3 * env * velocity * formant
        buf_l[i] = val * pan_l
        buf_r[i] = val * pan_r
    return buf_l, buf_r

def synth_funk_guitar(midi, duration=0.45, velocity=0.7, pan=-0.3, wah=True):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)

    for i in range(samples):
        t = i / SAMPLE_RATE
        env = math.exp(-12.0 * t)
        # Wah envelope: filter sweeps down from 2.5kHz to 600Hz
        wah_freq = 600.0 + 1900.0 * math.exp(-22.0 * t) if wah else 1200.0
        wah_mod = math.sin(2.0 * math.pi * wah_freq * t) * 0.35

        s1 = math.sin(2.0 * math.pi * freq * t)
        s2 = 0.55 * math.sin(2.0 * math.pi * freq * 2.0 * t)
        s3 = 0.3 * math.sin(2.0 * math.pi * freq * 3.0 * t)
        pluck = math.exp(-40.0 * t)

        val = ((s1 + s2 + s3) * 0.5 + wah_mod + pluck * 0.2) * env * velocity * 0.5
        buf_l[i] = val * pan_l
        buf_r[i] = val * pan_r
    return buf_l, buf_r

def synth_vibraphone(midi, duration, velocity=0.6, pan=0.0):
    freq = midi_to_freq(midi)
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)

    for i in range(samples):
        t = i / SAMPLE_RATE
        env = math.exp(-2.5 * t)
        motor = 1.0 + 0.22 * math.sin(2.0 * math.pi * 5.5 * t)
        s1 = math.sin(2.0 * math.pi * freq * t)
        s4 = 0.38 * math.sin(2.0 * math.pi * freq * 4.0 * t) * math.exp(-8.0 * t)
        val = (s1 + s4) * env * velocity * motor * 0.45
        buf_l[i] = val * pan_l
        buf_r[i] = val * pan_r
    return buf_l, buf_r

# Advanced drum components with humanized pocket
def synth_tape_kick(velocity=0.85):
    duration = 0.32
    samples = int(duration * SAMPLE_RATE)
    buf = [0.0] * samples
    for i in range(samples):
        t = i / SAMPLE_RATE
        # Round sub-thump pitch drop from 145Hz to 48Hz
        pitch = 48.0 + 97.0 * math.exp(-38.0 * t)
        phase = 2.0 * math.pi * pitch * t
        env = math.exp(-11.0 * t)
        # Tape saturation compression
        raw = math.sin(phase) * env * velocity
        buf[i] = math.tanh(raw * 1.3) * 0.72
    return buf, buf

def synth_snare_and_ghost(velocity=0.75, ghost=False, pan=0.05):
    duration = 0.16 if not ghost else 0.08
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    rng = random.Random(333 + samples)
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)
    for i in range(samples):
        t = i / SAMPLE_RATE
        decay = 40.0 if not ghost else 65.0
        noise = (rng.random() * 2.0 - 1.0) * math.exp(-decay * t)
        body = math.sin(2.0 * math.pi * (240.0 if not ghost else 280.0) * t) * math.exp(-30.0 * t)
        val = (noise * 0.65 + body * 0.35) * velocity * (0.55 if not ghost else 0.3)
        buf_l[i] = val * pan_l
        buf_r[i] = val * pan_r
    return buf_l, buf_r

def synth_jazz_brush(velocity=0.5, pan=-0.1):
    duration = 0.22
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    rng = random.Random(444 + samples)
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)
    for i in range(samples):
        t = i / SAMPLE_RATE
        # Swish envelope (rise then soft fall)
        swish = math.sin(math.pi * min(1.0, t / 0.18)) * math.exp(-8.0 * t)
        noise = (rng.random() * 2.0 - 1.0) * swish * velocity * 0.35
        buf_l[i] = noise * pan_l
        buf_r[i] = noise * pan_r
    return buf_l, buf_r

def synth_pocket_hat(velocity=0.45, closed=True, pan=-0.22):
    duration = 0.06 if closed else 0.22
    samples = int(duration * SAMPLE_RATE)
    buf_l = [0.0] * samples
    buf_r = [0.0] * samples
    decay_rate = 70.0 if closed else 18.0
    rng = random.Random(777 + samples)
    pan_l = math.cos((pan + 1.0) * math.pi / 4.0)
    pan_r = math.sin((pan + 1.0) * math.pi / 4.0)
    for i in range(samples):
        t = i / SAMPLE_RATE
        noise = (rng.random() * 2.0 - 1.0)
        metal = math.sin(2.0 * math.pi * 8200.0 * t) * 0.3 + math.sin(2.0 * math.pi * 10500.0 * t) * 0.2
        val = (noise * 0.7 + metal * 0.3) * math.exp(-decay_rate * t) * velocity * 0.38
        buf_l[i] = val * pan_l
        buf_r[i] = val * pan_r
    return buf_l, buf_r


# =====================================================================
# ALTERNATIVE 1: "DIAMOND CUT" (Polished Master Evolution of High Roller)
# 88 BPM • A/B Section progression (16 bars), silkier neo-soul voicings, MPC swing pocket
# =====================================================================
def generate_alt1_diamond_cut(output_path):
    bpm = 88.0
    beat_sec = 60.0 / bpm
    bars = 16
    duration = bars * 4 * beat_sec  # ~43.6s
    track = StereoTrack(duration)

    # Progression Section A (Bars 1-8): Fm9 -> Dbmaj9 -> Bbm11 -> C7alt
    # Progression Section B (Bars 9-16): Abmaj9 -> Gm7b5 -> C7b9 -> Fm9 -> Eb13
    chords_A = [
        ([53, 56, 60, 63, 67], 2 * 4 * beat_sec, 41), # Fm9 / F2
        ([49, 53, 56, 60, 63], 2 * 4 * beat_sec, 37), # Dbmaj9 / Db2
        ([46, 53, 56, 60, 65], 2 * 4 * beat_sec, 34), # Bbm11 / Bb1
        ([48, 52, 55, 58, 63, 66], 2 * 4 * beat_sec, 36), # C7alt / C2
    ]
    chords_B = [
        ([51, 55, 58, 62, 65], 2 * 4 * beat_sec, 39), # Abmaj9 / Ab2
        ([46, 49, 52, 56, 60], 2 * 4 * beat_sec, 34), # Gm7b5 / G2
        ([48, 52, 55, 58, 61], 2 * 4 * beat_sec, 36), # C7b9 / C2
        ([53, 56, 60, 63, 67], 2 * 4 * beat_sec, 41), # Fm9 / F2
    ]

    all_chords = chords_A + chords_B

    t_cursor = 0.0
    for c_idx, (notes, chord_dur, bass_root) in enumerate(all_chords):
        # Syncopated Rhodes chops with micro-timing swing (MPC pocket)
        stabs = [0.0, beat_sec * 1.75 + 0.02, beat_sec * 2.5, beat_sec * 3.5 + 0.02,
                 beat_sec * 4.0, beat_sec * 5.75 + 0.02, beat_sec * 6.5, beat_sec * 7.5 + 0.02]
        for off in stabs:
            for idx, n in enumerate(notes):
                pan = ((idx % 3) - 1) * 0.2
                bl, br = synth_rhodes(n, 1.1, velocity=0.62, pan=pan, tremolo_speed=5.2)
                track.add_sound(t_cursor + off, bl, br)

        # Octave funky bassline with slides
        bass_funk = [
            (0.0, bass_root, 0.5, None),
            (beat_sec * 0.75, bass_root, 0.3, None),
            (beat_sec * 1.5, bass_root + 12, 0.45, bass_root), # slide pop
            (beat_sec * 2.25, bass_root + 10, 0.3, None),
            (beat_sec * 3.0, bass_root, 0.6, None),
            (beat_sec * 4.0, bass_root, 0.5, None),
            (beat_sec * 4.75, bass_root + 7, 0.3, None),
            (beat_sec * 5.5, bass_root + 12, 0.45, bass_root + 7),
            (beat_sec * 6.5, bass_root + 10, 0.3, None),
            (beat_sec * 7.0, bass_root + 1, 0.4, None),
        ]
        for off, bn, bdur, g_from in bass_funk:
            bl, br = synth_moog_bass(bn, bdur, velocity=0.82, glide_from=g_from)
            track.add_sound(t_cursor + off, bl, br)

        t_cursor += chord_dur

    # Drums: 16 bars with subtle dynamic evolution
    for bar in range(bars):
        b_start = bar * 4 * beat_sec
        # Kick
        kl, kr = synth_tape_kick(velocity=0.85)
        track.add_sound(b_start, kl, kr)
        track.add_sound(b_start + beat_sec * 1.5, kl, kr)
        track.add_sound(b_start + beat_sec * 2.75, kl, kr)

        # Snare on 2 and 4 + ghost note on 3.5
        sl, sr = synth_snare_and_ghost(velocity=0.8, ghost=False)
        track.add_sound(b_start + beat_sec * 1.0, sl, sr)
        track.add_sound(b_start + beat_sec * 3.0, sl, sr)
        gl, gr = synth_snare_and_ghost(velocity=0.35, ghost=True)
        track.add_sound(b_start + beat_sec * 2.25, gl, gr)

        # 16th hats with swung pocket (60% Dilla swing)
        for s in range(16):
            is_offbeat = (s % 2 == 1)
            swing_offset = 0.022 if is_offbeat else 0.0
            isOpen = (s == 6 or s == 14) and (bar % 2 == 1)
            vel = 0.52 if s % 4 == 0 else (0.6 if isOpen else 0.34)
            hl, hr = synth_pocket_hat(velocity=vel, closed=not isOpen)
            track.add_sound(b_start + s * 0.25 * beat_sec + swing_offset, hl, hr)

    # Lead Vibraphone & Muted Guitar dialogue (Sections A and B)
    lead_notes = [
        (beat_sec * 1.0, 72), (beat_sec * 1.5, 75), (beat_sec * 2.5, 77), (beat_sec * 3.5, 80),
        (beat_sec * 5.0, 77), (beat_sec * 6.0, 75), (beat_sec * 7.0, 72),
        (beat_sec * 9.0, 75), (beat_sec * 9.5, 77), (beat_sec * 10.5, 80), (beat_sec * 11.5, 84),
        (beat_sec * 13.0, 80), (beat_sec * 14.0, 77), (beat_sec * 15.0, 75),
        # Section B higher flourish
        (beat_sec * 17.0, 80), (beat_sec * 18.0, 84), (beat_sec * 19.0, 87), (beat_sec * 20.0, 84),
        (beat_sec * 22.0, 80), (beat_sec * 24.0, 77), (beat_sec * 25.5, 75), (beat_sec * 27.0, 72),
        (beat_sec * 29.0, 75), (beat_sec * 30.5, 77), (beat_sec * 31.0, 80),
    ]
    for off, n in lead_notes:
        if off < duration - 1.0:
            vl, vr = synth_vibraphone(n, 2.2, velocity=0.55, pan=0.35)
            track.add_sound(off, vl, vr)

    track.apply_pingpong_delay(delay_time_sec=beat_sec * 0.5, feedback=0.22, dry_wet=0.18)
    track.add_tape_saturation(drive=1.15)
    track.export_wav(output_path)


# =====================================================================
# ALTERNATIVE 2: "CASINO ROYALE" (Brass & Smoke - Cinematic Retro Funk)
# 90 BPM • Sultry muted trumpet/horn stabs, wah guitar stabs, spy/heist swagger
# =====================================================================
def generate_alt2_casino_royale(output_path):
    bpm = 90.0
    beat_sec = 60.0 / bpm
    bars = 16
    duration = bars * 4 * beat_sec  # ~42.7s
    track = StereoTrack(duration)

    # D Minor / F Major spy progression: Dm9 -> Gm9 -> Bb13 -> A7#9
    chord_seq = [
        ([50, 53, 57, 60, 64], 2 * 4 * beat_sec, 38), # Dm9 / D2
        ([46, 50, 53, 57, 62], 2 * 4 * beat_sec, 34), # Gm9 / G1
        ([46, 50, 53, 56, 60, 64], 2 * 4 * beat_sec, 34), # Bb13 / Bb1
        ([45, 49, 52, 55, 60], 2 * 4 * beat_sec, 33), # A7#9 / A1
    ] * 2

    t_cursor = 0.0
    for notes, chord_dur, bass_root in chord_seq:
        # Wah-wah rhythm guitar on offbeats
        wah_stabs = [beat_sec * 0.5, beat_sec * 1.5, beat_sec * 2.5, beat_sec * 3.5,
                     beat_sec * 4.5, beat_sec * 5.5, beat_sec * 6.5, beat_sec * 7.5]
        for off in wah_stabs:
            for idx, n in enumerate(notes[:3]):
                gl, gr = synth_funk_guitar(n, 0.35, velocity=0.6, pan=-0.35, wah=True)
                track.add_sound(t_cursor + off, gl, gr)

        # Muted Brass Stabs on "1" and "and of 3"
        brass_hits = [0.0, beat_sec * 2.5, beat_sec * 4.0, beat_sec * 6.5]
        for off in brass_hits:
            for n in [notes[0] + 12, notes[2] + 12]:
                br_l, br_r = synth_brass_stab(n, 0.45, velocity=0.72, pan=0.25)
                track.add_sound(t_cursor + off, br_l, br_r)

        # Walking detective bassline
        w_bass = [
            (0.0, bass_root),
            (beat_sec * 1.0, bass_root + 3),
            (beat_sec * 2.0, bass_root + 5),
            (beat_sec * 3.0, bass_root + 6),
            (beat_sec * 4.0, bass_root + 7),
            (beat_sec * 5.0, bass_root + 5),
            (beat_sec * 6.0, bass_root + 3),
            (beat_sec * 7.0, bass_root + 1),
        ]
        for off, bn in w_bass:
            bl, br = synth_upright_bass(bn, 0.9 * beat_sec, velocity=0.82)
            track.add_sound(t_cursor + off, bl, br)

        t_cursor += chord_dur

    # Drums: Crisp 70s caper groove
    for bar in range(bars):
        b_start = bar * 4 * beat_sec
        # Kick on 1 and 3
        kl, kr = synth_tape_kick(velocity=0.88)
        track.add_sound(b_start, kl, kr)
        track.add_sound(b_start + beat_sec * 2.0, kl, kr)

        # Rimshot on 2 and 4
        sl, sr = synth_snare_and_ghost(velocity=0.82, ghost=False)
        track.add_sound(b_start + beat_sec * 1.0, sl, sr)
        track.add_sound(b_start + beat_sec * 3.0, sl, sr)

        # Steady swung ride / hi-hat
        for step in range(8):
            swing = 0.035 if step % 2 == 1 else 0.0
            hl, hr = synth_pocket_hat(velocity=0.48 if step % 2 == 0 else 0.35, closed=True)
            track.add_sound(b_start + step * 0.5 * beat_sec + swing, hl, hr)

    track.apply_pingpong_delay(delay_time_sec=beat_sec * 0.5, feedback=0.25, dry_wet=0.20)
    track.add_tape_saturation(drive=1.2)
    track.export_wav(output_path)


# =====================================================================
# ALTERNATIVE 3: "TOKYO NIGHTS" (Future Neo-Soul & Electronic Bounce)
# 86 BPM • Analog Moog synth bass, chorus Rhodes, sidechained kick, modern chillhop
# =====================================================================
def generate_alt3_tokyo_nights(output_path):
    bpm = 86.0
    beat_sec = 60.0 / bpm
    bars = 16
    duration = bars * 4 * beat_sec  # ~44.6s
    track = StereoTrack(duration)

    # Chords in Bb Minor / Db Major: Bbm9 -> Gbmaj9 -> Ebm9 -> F7alt
    chords = [
        ([46, 53, 56, 60, 65], 2 * 4 * beat_sec, 34), # Bbm9 / Bb1
        ([42, 49, 53, 56, 61], 2 * 4 * beat_sec, 30), # Gbmaj9 / Gb1
        ([39, 46, 50, 53, 58], 2 * 4 * beat_sec, 27), # Ebm9 / Eb1
        ([41, 45, 48, 52, 57], 2 * 4 * beat_sec, 29), # F7alt / F1
    ] * 2

    t_cursor = 0.0
    for notes, chord_dur, bass_root in chords:
        # Lush wide stereo Chorus Rhodes (sustained with tremolo)
        for off in [0.0, beat_sec * 3.5, beat_sec * 4.0, beat_sec * 7.5]:
            for idx, n in enumerate(notes):
                pan = -0.4 + idx * 0.2
                bl, br = synth_rhodes(n, 3.2, velocity=0.55, pan=pan, chorus=True)
                track.add_sound(t_cursor + off, bl, br)

        # Deep Moog Sub-Bass bounce (Kaytranada / FKJ style syncopation)
        bass_seq = [
            (0.0, bass_root, 0.4, None),
            (beat_sec * 1.5, bass_root + 12, 0.35, bass_root), # octave jump
            (beat_sec * 2.5, bass_root + 7, 0.4, None),
            (beat_sec * 3.75, bass_root, 0.3, None),
            (beat_sec * 4.0, bass_root, 0.5, None),
            (beat_sec * 5.5, bass_root + 10, 0.4, None),
            (beat_sec * 6.5, bass_root + 12, 0.35, bass_root + 10),
            (beat_sec * 7.25, bass_root + 5, 0.35, None),
        ]
        for off, bn, bdur, g_from in bass_seq:
            bl, br = synth_moog_bass(bn, bdur, velocity=0.88, glide_from=g_from)
            track.add_sound(t_cursor + off, bl, br)

        t_cursor += chord_dur

    # Drums: Sidechained deep punch & future claps
    for bar in range(bars):
        b_start = bar * 4 * beat_sec
        # Deep kick on 1, 2.5, and 3.5
        kl, kr = synth_tape_kick(velocity=0.92)
        track.add_sound(b_start, kl, kr)
        track.add_sound(b_start + beat_sec * 1.5, kl, kr)
        track.add_sound(b_start + beat_sec * 2.75, kl, kr)

        # Snappy clap on 2 and 4
        sl, sr = synth_snare_and_ghost(velocity=0.85, ghost=False)
        track.add_sound(b_start + beat_sec * 1.0, sl, sr)
        track.add_sound(b_start + beat_sec * 3.0, sl, sr)

        # 16th hats with dynamic trap/lo-fi rolls
        for s in range(16):
            is_roll = (s >= 12 and bar % 2 == 1)
            vel = 0.35 if not is_roll else 0.55
            hl, hr = synth_pocket_hat(velocity=vel, closed=True)
            track.add_sound(b_start + s * 0.25 * beat_sec, hl, hr)

    # Crystal bell synth top line
    lead_arps = [
        (beat_sec * 1.5, 77), (beat_sec * 2.0, 80), (beat_sec * 3.0, 85),
        (beat_sec * 5.5, 84), (beat_sec * 6.0, 80), (beat_sec * 7.0, 77),
        (beat_sec * 9.5, 80), (beat_sec * 10.0, 82), (beat_sec * 11.0, 85),
        (beat_sec * 13.5, 89), (beat_sec * 14.0, 85), (beat_sec * 15.0, 82),
    ] * 2
    for off, n in lead_arps:
        if off < duration - 1.0:
            vl, vr = synth_vibraphone(n, 1.8, velocity=0.52, pan=0.3)
            track.add_sound(off, vl, vr)

    track.apply_pingpong_delay(delay_time_sec=beat_sec * 0.75, feedback=0.32, dry_wet=0.24)
    track.add_tape_saturation(drive=1.1)
    track.export_wav(output_path)


# =====================================================================
# ALTERNATIVE 4: "GENTLEMAN'S WAGER" (Acoustic Nu-Jazz Trio)
# 89 BPM • Upright double-bass pizzicato, jazz brush snare swish, live club feel
# =====================================================================
def generate_alt4_gentlemans_wager(output_path):
    bpm = 89.0
    beat_sec = 60.0 / bpm
    bars = 16
    duration = bars * 4 * beat_sec  # ~43.1s
    track = StereoTrack(duration)

    # G Minor / Bb Major Acoustic Trio Progression:
    # Gm7 -> C7 -> Cm7 -> F7 -> Bbmaj7 -> Ebmaj7 -> Am7b5 -> D7alt
    chords = [
        ([50, 53, 58, 62], 2 * 4 * beat_sec, 43), # Gm7 / G2
        ([48, 52, 55, 58, 62], 2 * 4 * beat_sec, 36), # C7 / C2
        ([48, 51, 55, 58], 2 * 4 * beat_sec, 36), # Cm7 / C2
        ([41, 45, 48, 52, 57], 2 * 4 * beat_sec, 41), # F7 / F2
        ([46, 50, 53, 57, 62], 2 * 4 * beat_sec, 34), # Bbmaj7 / Bb1
        ([43, 46, 50, 53, 58], 2 * 4 * beat_sec, 39), # Ebmaj7 / Eb2
        ([45, 48, 51, 55, 60], 2 * 4 * beat_sec, 33), # Am7b5 / A1
        ([45, 48, 50, 54, 58], 2 * 4 * beat_sec, 38), # D7alt / D2
    ]

    t_cursor = 0.0
    for notes, chord_dur, bass_root in chords:
        # Acoustic Grand / Rhodes comping in classic swung Charleston rhythm
        charleston_hits = [0.0, beat_sec * 1.5, beat_sec * 4.0, beat_sec * 5.5]
        for off in charleston_hits:
            for idx, n in enumerate(notes):
                pan = -0.3 + idx * 0.15
                bl, br = synth_rhodes(n, 1.8, velocity=0.58, pan=pan, tremolo_speed=4.0)
                track.add_sound(t_cursor + off, bl, br)

        # Walking Upright Double-Bass (4 beats to the bar, active pizzicato)
        walk_notes = [
            (0.0, bass_root),
            (beat_sec * 1.0, bass_root + 4),
            (beat_sec * 2.0, bass_root + 7),
            (beat_sec * 3.0, bass_root + 6),
            (beat_sec * 4.0, bass_root + 5),
            (beat_sec * 5.0, bass_root + 7),
            (beat_sec * 6.0, bass_root + 10),
            (beat_sec * 7.0, bass_root + 2),
        ]
        for off, bn in walk_notes:
            bl, br = synth_upright_bass(bn, 0.85 * beat_sec, velocity=0.85)
            track.add_sound(t_cursor + off, bl, br)

        t_cursor += chord_dur

    # Drums: Acoustic Jazz Brushes & Soft Foot Kick
    for bar in range(bars):
        b_start = bar * 4 * beat_sec
        # Soft felt kick on 1 and 3
        kl, kr = synth_tape_kick(velocity=0.65)
        track.add_sound(b_start, kl, kr)
        track.add_sound(b_start + beat_sec * 2.0, kl, kr)

        # Snare brush swish on 2 and 4 with accent
        br_l, br_r = synth_jazz_brush(velocity=0.55, pan=0.1)
        track.add_sound(b_start + beat_sec * 1.0, br_l, br_r)
        track.add_sound(b_start + beat_sec * 3.0, br_l, br_r)

        # Swung ride cymbal pattern: 1, 2-and, 3, 4-and
        ride_steps = [0.0, beat_sec * 1.0, beat_sec * 1.66, beat_sec * 2.0, beat_sec * 3.0, beat_sec * 3.66]
        for r_off in ride_steps:
            hl, hr = synth_pocket_hat(velocity=0.42, closed=True, pan=-0.3)
            track.add_sound(b_start + r_off, hl, hr)

    # Warm Vibraphone solo lines floating over the trio
    vib_lines = [
        (beat_sec * 1.0, 70), (beat_sec * 1.66, 74), (beat_sec * 2.5, 77), (beat_sec * 3.5, 79),
        (beat_sec * 5.0, 77), (beat_sec * 6.0, 74), (beat_sec * 7.0, 70),
        (beat_sec * 9.0, 74), (beat_sec * 10.0, 77), (beat_sec * 11.0, 81), (beat_sec * 12.0, 82),
        (beat_sec * 13.5, 81), (beat_sec * 14.5, 77), (beat_sec * 15.0, 74),
        # Second half embellishments
        (beat_sec * 17.0, 77), (beat_sec * 18.0, 81), (beat_sec * 19.5, 84), (beat_sec * 20.5, 82),
        (beat_sec * 22.0, 77), (beat_sec * 23.5, 74), (beat_sec * 25.0, 70),
        (beat_sec * 27.0, 74), (beat_sec * 28.5, 77), (beat_sec * 30.0, 82),
    ]
    for off, n in vib_lines:
        if off < duration - 1.0:
            vl, vr = synth_vibraphone(n, 2.4, velocity=0.55, pan=0.3)
            track.add_sound(off, vl, vr)

    track.apply_pingpong_delay(delay_time_sec=beat_sec * 0.66, feedback=0.22, dry_wet=0.16)
    track.add_tape_saturation(drive=1.1)
    track.export_wav(output_path)


def main():
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'previews')
    os.makedirs(out_dir, exist_ok=True)
    
    print("Generating High Roller Groove Evolutions & Alternatives...")
    generate_alt1_diamond_cut(os.path.join(out_dir, 'high_roller_alt1_diamond_cut.wav'))
    generate_alt2_casino_royale(os.path.join(out_dir, 'high_roller_alt2_casino_royale.wav'))
    generate_alt3_tokyo_nights(os.path.join(out_dir, 'high_roller_alt3_tokyo_nights.wav'))
    generate_alt4_gentlemans_wager(os.path.join(out_dir, 'high_roller_alt4_gentlemans_wager.wav'))
    print("All 4 High Roller Groove alternatives generated successfully!")

if __name__ == '__main__':
    main()
