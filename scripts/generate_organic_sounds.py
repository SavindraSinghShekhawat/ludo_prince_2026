import wave
import math
import struct
import random
import sys
import os

def write_wav(filename, samples, sample_rate=44100):
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        # Convert float samples (-1.0 to 1.0) to 16-bit PCM
        for s in samples:
            val = max(-1.0, min(1.0, s))
            wav_file.writeframesraw(struct.pack('<h', int(val * 32767.0)))

def generate_move_swoosh(steps, sample_rate=44100):
    # A soft, breathy "swoosh" or "wave" sound for moving
    # 150ms per step
    duration = max(0.2, steps * 0.15)
    samples = []
    num_samples = int(sample_rate * duration)
    for i in range(num_samples):
        t = i / sample_rate
        # Envelope: gradual attack, smooth decay (like a wave)
        env = math.sin(math.pi * (t / duration)) ** 2
        # Use white noise to simulate a "ssshhh" whisper
        noise = random.uniform(-1, 1)
        # High frequency sweep (3000Hz down to 2000Hz) to sound airy, not farty
        freq = 3000 - (1000 * (t / duration))
        resonance = math.sin(2 * math.pi * freq * t) * 0.3
        val = (noise * 0.8 + resonance) * env
        # Lower baseline volume
        samples.append(val * 0.3)
    return samples

def generate_dice_roll(sample_rate=44100):
    # Realistic clattering of double dice inside a plastic/wood cup
    duration = 0.45
    samples = []
    num_samples = int(sample_rate * duration)
    # More chaotic hits for two dice tumbling
    hits = [0.0, 0.05, 0.12, 0.16, 0.21, 0.28, 0.35, 0.38, 0.42]
    for i in range(num_samples):
        t = i / sample_rate
        val = 0
        for idx, hit in enumerate(hits):
            if t >= hit:
                local_t = t - hit
                # Each hit gets a sharp pluck envelope
                env = math.exp(-local_t * (100 + random.uniform(-20, 20)))
                # Frequency varies slightly per hit (simulating different angles)
                freq1 = 800 + (idx * 50 % 200)
                freq2 = 1200 - (idx * 70 % 300)
                
                res = math.sin(2 * math.pi * freq1 * local_t) * math.exp(-local_t * 60)
                res2 = math.sin(2 * math.pi * freq2 * local_t) * math.exp(-local_t * 80)
                noise = random.uniform(-1, 1) * 0.3 * math.exp(-local_t * 150)
                
                val += (res * 0.5 + res2 * 0.3 + noise) * env
        # lowered dice roll volume somewhat
        samples.append(val * 0.25)
    return samples

def generate_bell(freq, duration, sample_rate=44100):
    samples = []
    num_samples = int(sample_rate * duration)
    for i in range(num_samples):
        t = i / sample_rate
        env = math.exp(-t * 5)
        
        # Simple FM synthesis for bell
        mod = math.sin(2 * math.pi * (freq * 1.4) * t)
        val = math.sin(2 * math.pi * freq * t + mod * 2.0)
        samples.append(val * env * 0.3)
    return samples

def generate_six_chime(sample_rate=44100):
    # Bright, short 2-note bell (e.g. C5 -> E5)
    bell1 = generate_bell(523.25, 0.3, sample_rate) # C5
    bell2 = generate_bell(659.25, 0.6, sample_rate) # E5
    
    # Mix them, offsetting the second bell by 0.1 seconds
    offset_samples = int(sample_rate * 0.1)
    total_len = max(len(bell1), len(bell2) + offset_samples)
    samples = [0] * total_len
    
    for i in range(len(bell1)):
        samples[i] += bell1[i]
        
    for i in range(len(bell2)):
        samples[i + offset_samples] += bell2[i]
        
    return samples

def generate_home_chime(sample_rate=44100):
    # Major chord resolving (C4, E4, G4, C5)
    notes = [
        (261.63, 0.0), # C4
        (329.63, 0.1), # E4
        (392.00, 0.2), # G4
        (523.25, 0.4)  # C5 long
    ]
    total_len = int(sample_rate * 2.0)
    samples = [0] * total_len
    
    for freq, delay in notes:
        bell = generate_bell(freq, 1.5, sample_rate)
        delay_samps = int(sample_rate * delay)
        for i in range(len(bell)):
            if i + delay_samps < total_len:
                samples[i + delay_samps] += bell[i]
                
    return samples

def generate_safe_ding(sample_rate=44100):
    # Soft, warm FM ding
    samples = []
    duration = 0.5
    num_samples = int(sample_rate * duration)
    freq = 880.0 # A5
    for i in range(num_samples):
        t = i / sample_rate
        env = math.exp(-t * 8)
        mod = math.sin(2 * math.pi * (freq * 2.0) * t) * math.exp(-t * 15)
        val = math.sin(2 * math.pi * freq * t + mod * 1.5)
        samples.append(val * env * 0.2)
    return samples

def generate_start_jingle(sample_rate=44100):
    # Upbeat fast sequence
    notes = [
        (440.00, 0.0),   # A4
        (554.37, 0.15),  # C#5
        (659.25, 0.3),   # E5
        (880.00, 0.45)   # A5
    ]
    total_len = int(sample_rate * 1.5)
    samples = [0] * total_len
    
    for freq, delay in notes:
        # slightly shorter bells
        bell = generate_bell(freq, 0.8, sample_rate) 
        delay_samps = int(sample_rate * delay)
        for i in range(len(bell)):
            if i + delay_samps < total_len:
                samples[i + delay_samps] += bell[i]
                
    return samples

def generate_die_thud(sample_rate=44100):
    # Descending synth pitch + noise puff
    duration = 0.4
    samples = []
    num_samples = int(sample_rate * duration)
    for i in range(num_samples):
        t = i / sample_rate
        env = math.exp(-t * 10)
        # pitch envelope from 300hz down to 50hz
        freq = max(50, 300 - (t * 800))
        osc = math.sin(2 * math.pi * freq * t)
        noise = random.uniform(-1, 1) * math.exp(-t * 30)
        
        # slightly distorted
        val = (osc * 0.6 + noise * 0.4) * env
        samples.append(val * 0.4)
    return samples

def karplus_strong(freq, duration, sample_rate=44100):
    # Physical modeling of a plucked string (like a guitar or ukulele)
    if freq <= 0: return [0]
    N = int(sample_rate / freq)
    if N == 0: return [0]
    
    # Initialize delay line with bursts of noise
    delay_line = [random.uniform(-1, 1) for _ in range(N)]
    samples = []
    num_samples = int(duration * sample_rate)
    
    prev_val = 0
    decay_factor = 0.994 # Determines how long the string rings
    for i in range(num_samples):
        val = delay_line[i % N]
        # Low pass filter and decay
        new_val = (val + prev_val) * 0.5 * decay_factor
        delay_line[i % N] = new_val
        prev_val = new_val
        samples.append(new_val)
    return samples

def generate_drum_kick(duration=0.4, sample_rate=44100):
    # Punchy kick drum
    samples = []
    num_samples = int(sample_rate * duration)
    for i in range(num_samples):
        t = i / sample_rate
        # Rapid pitch drop from 150hz to 40hz
        freq = 40 + 110 * math.exp(-t * 20)
        val = math.sin(2 * math.pi * freq * t)
        env = math.exp(-t * 8)
        samples.append(val * env * 0.8) # Keep punchy
    return samples

def generate_shaker(duration=0.15, sample_rate=44100):
    # Rhythmic shaker/hi-hat
    samples = []
    num_samples = int(sample_rate * duration)
    for i in range(num_samples):
        t = i / sample_rate
        noise = random.uniform(-1, 1)
        env = math.exp(-t * 25)
        samples.append(noise * env * 0.3)
    return samples

def generate_bgm_loop(sample_rate=44100):
    # A lively, energetic, acoustic-style loop (64 seconds total to hide Flutter's looping gap)
    num_repeats = 10
    duration = 6.4 * num_repeats
    samples = [0] * int(sample_rate * duration)
    
    def mix_in(track_samples, start_time, vol=1.0):
        start_idx = int(start_time * sample_rate)
        for i, val in enumerate(track_samples):
            # Wrap the tail audio tightly back to the beginning of the loop
            wrap_idx = (start_idx + i) % len(samples)
            samples[wrap_idx] += val * vol

    kick = generate_drum_kick()
    shaker = generate_shaker()
    
    # 1-minute Song Structure:
    # Rep 0: Intro (No kick)
    # Rep 1: Verse (Full beat, no melody)
    # Rep 2, 3: Chorus 1 (Full beat + Melody)
    # Rep 4: Breakdown (No kick, sparse chords)
    # Rep 5, 6, 7: Chorus 2 (Full beat + Melody)
    # Rep 8: Verse 2 (Full beat, no melody)
    # Rep 9: Outro (No kick, ending)
    
    for rep in range(num_repeats):
        rep_offset = rep * 6.4

        # 16 beats total (BPM = 150 -> 0.4 seconds per beat)
        for b in range(16):
            beat_time = rep_offset + b * 0.4
            
            # Kick on Beats 1 and 3 of every bar, plus some syncopation
            if rep not in [0, 4, 9]: # Drop kick for intro, breakdown, and outro
                if b % 4 == 0 or b % 4 == 2 or b == 15:
                    mix_in(kick, beat_time, 0.5)
                
            # Shaker on every off-beat (the "and")
            vol_shaker = 0.2 if rep in [0, 4, 9] else 0.4
            mix_in(shaker, beat_time + 0.2, vol_shaker)
            # Subtle shaker driving the downbeat
            mix_in(shaker, beat_time, 0.1)

        # Bouncy Island-style Chord Progression: Cmaj -> Fmaj -> Gmaj -> Cmaj
        chords = [
            (261.63, 0.0), # Bar 1: C4 
            (349.23, 1.6), # Bar 2: F4
            (392.00, 3.2), # Bar 3: G4
            (261.63, 4.8), # Bar 4: C4
        ]
        
        for base_freq, bar_time in chords:
            # Calypso/Reggae rhythm pluck pattern
            
            # Beat 1: Bass note
            mix_in(karplus_strong(base_freq * 0.5, 1.2), rep_offset + bar_time + 0.0, 0.5) 
            mix_in(karplus_strong(base_freq, 0.8), rep_offset + bar_time + 0.0, 0.3)
            
            if rep not in [4]: # In breakdown, skip the upbeat chords to make it sparse
                # Beat 2-And: Upbeat chord strike (Third + Fifth)
                mix_in(karplus_strong(base_freq * 1.25, 0.8), rep_offset + bar_time + 0.6, 0.3) # Major 3rd
                mix_in(karplus_strong(base_freq * 1.5, 0.8), rep_offset + bar_time + 0.6, 0.3)  # Perfect 5th
            
            # Beat 3: Bass note returns
            mix_in(karplus_strong(base_freq * 0.5, 0.8), rep_offset + bar_time + 1.2, 0.4)
            
            if rep not in [4]:
                # Beat 4-And: Quick high twinkle octave
                mix_in(karplus_strong(base_freq * 2.0, 0.4), rep_offset + bar_time + 1.4, 0.2) 
        
        # Add a high-pitched plucky Melody during the Chorus sections
        if rep in [2, 3, 5, 6, 7]:
            vol_mel = 0.35
            # Cmaj
            mix_in(karplus_strong(523.25, 0.8), rep_offset + 0.0, vol_mel) # C5
            mix_in(karplus_strong(659.25, 0.8), rep_offset + 0.8, vol_mel) # E5
            mix_in(karplus_strong(783.99, 0.8), rep_offset + 1.2, vol_mel) # G5
            # Fmaj
            mix_in(karplus_strong(698.46, 0.8), rep_offset + 1.6 + 0.0, vol_mel) # F5
            mix_in(karplus_strong(880.00, 0.8), rep_offset + 1.6 + 0.8, vol_mel) # A5
            # Gmaj
            mix_in(karplus_strong(783.99, 0.8), rep_offset + 3.2 + 0.0, vol_mel) # G5
            mix_in(karplus_strong(587.33, 0.8), rep_offset + 3.2 + 0.8, vol_mel) # D5
            # Cmaj returning
            mix_in(karplus_strong(523.25, 1.2), rep_offset + 4.8 + 0.0, vol_mel) # C5
            mix_in(karplus_strong(523.25, 0.8), rep_offset + 4.8 + 0.8, vol_mel) # C5
        
    return samples


out_dir = sys.argv[1]
os.makedirs(out_dir, exist_ok=True)

for i in range(1, 7):
    write_wav(os.path.join(out_dir, f'move_{i}.wav'), generate_move_swoosh(i))

write_wav(os.path.join(out_dir, 'roll.wav'), generate_dice_roll())
write_wav(os.path.join(out_dir, 'six.wav'), generate_six_chime())
write_wav(os.path.join(out_dir, 'home.wav'), generate_home_chime())
write_wav(os.path.join(out_dir, 'safe.wav'), generate_safe_ding())
write_wav(os.path.join(out_dir, 'start.wav'), generate_start_jingle())
write_wav(os.path.join(out_dir, 'die.wav'), generate_die_thud())
write_wav(os.path.join(out_dir, 'bgm.wav'), generate_bgm_loop())
