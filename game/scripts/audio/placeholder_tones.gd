# ABOUTME: PlaceholderTones builds the section 21 sounds as plain WAV data.
# ABOUTME: The real recordings land with the audio pass; these tones carry the system.
class_name PlaceholderTones
extends RefCounted

const SAMPLE_RATE := 22050

# The clear voice of Puck near a pole: the one source every layer filters.
const ADDRESS_HZ := 620.0
const ADDRESS_VIBRATO_HZ := 5.5
# Morning birdsong: four chirps, each a short upward sweep with a rest.
const BIRDSONG_SECONDS := 3.0
const BIRD_CHIRP_HZ := 2600.0
const BIRD_SWEEP_HZ := 900.0
# The antagonist motif: two low notes that circle.
const ANTAGONIST_SECONDS := 4.0
const ANTAGONIST_HZ := 98.0
const ANTAGONIST_SECOND_HZ := 116.5
# The diegetic records ride one shared length.
const DIEGETIC_SECONDS := 6.0
# Dr. Morgen on the opening video, section 22: low, slow, tired. One word
# pattern stands in for the speech until T054 records the real voice.
const MORGEN_VOICE_HZ := 185.0
const MORGEN_VIBRATO_HZ := 4.2
const MORGEN_WORD_SECONDS := 0.26
const MORGEN_PAUSE_SECONDS := 0.09
const MORGEN_VOICE_LEVEL := 0.16

# The video track is the same every time it plays, so the wave is built once.
static var _morgen_voice_cache: Dictionary = {}


static func address_loop(loop_seconds: float) -> AudioStreamWAV:
	# One recording of the address: the clear, annoying voice. The distance
	# layers filter this one source; they never re-record it.
	return _looping_wave(_voice_samples(loop_seconds))


static func birdsong() -> AudioStreamWAV:
	return _wave(_birdsong_samples())


static func morgen_voice_track(seconds: float) -> AudioStreamWAV:
	# The placeholder voice of the opening video: one quiet, tired speech
	# pattern that runs the full video length under the subtitles.
	if _morgen_voice_cache.has(seconds):
		return _morgen_voice_cache[seconds]
	var stream := _wave(_morgen_voice_samples(seconds))
	_morgen_voice_cache[seconds] = stream
	return stream


static func antagonist_loop() -> AudioStreamWAV:
	return _looping_wave(_motif_samples())


static func diegetic_loop(venue: DiegeticMusic.Venue) -> AudioStreamWAV:
	match venue:
		DiegeticMusic.Venue.CAFE:
			return _looping_wave(
				_note_pattern_samples([146.8, 220.0, 261.6, 220.0, 293.7, 174.6], 0.5, 0.32)
			)
		DiegeticMusic.Venue.BAND_STAGE:
			return _looping_wave(
				_note_pattern_samples([82.4, 82.4, 103.8, 82.4, 82.4, 123.5], 0.4, 0.36)
			)
		DiegeticMusic.Venue.SLEEPVANA_CONCERT:
			return _looping_wave(
				_note_pattern_samples([110.0, 110.0, 146.8, 164.8, 110.0, 98.0], 0.35, 0.4)
			)
		_:
			return _looping_wave(_silence_samples(DIEGETIC_SECONDS))


static func _voice_samples(seconds: float) -> PackedFloat32Array:
	# A voice-like tone with vibrato and harmonics, annoying by design.
	var count := int(seconds * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t := float(i) / SAMPLE_RATE
		var voice := sin(TAU * ADDRESS_HZ * t + sin(TAU * ADDRESS_VIBRATO_HZ * t) * 8.0)
		voice += sin(TAU * ADDRESS_HZ * 2.0 * t) * 0.35
		voice += sin(TAU * ADDRESS_HZ * 3.0 * t) * 0.18
		samples[i] = voice * 0.22
	return samples


static func _morgen_voice_samples(seconds: float) -> PackedFloat32Array:
	# A word pattern with soft edges: voiced bursts with short pauses, like
	# tired speech, quieter and lower than the address it argues with.
	var count := int(seconds * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var word_cycle := MORGEN_WORD_SECONDS + MORGEN_PAUSE_SECONDS
	for i: int in count:
		var t := float(i) / SAMPLE_RATE
		var word_t := fmod(t, word_cycle)
		if word_t >= MORGEN_WORD_SECONDS:
			continue
		var voice := sin(TAU * MORGEN_VOICE_HZ * t + sin(TAU * MORGEN_VIBRATO_HZ * t) * 5.0)
		voice += sin(TAU * MORGEN_VOICE_HZ * 2.0 * t) * 0.3
		var attack := minf(word_t / 0.04, 1.0)
		var release := minf((MORGEN_WORD_SECONDS - word_t) / 0.04, 1.0)
		samples[i] = voice * MORGEN_VOICE_LEVEL * minf(attack, release)
	return samples


static func _birdsong_samples() -> PackedFloat32Array:
	var count := int(BIRDSONG_SECONDS * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t := float(i) / SAMPLE_RATE
		var beat := fmod(t, 0.7)
		if beat < 0.18:
			var sweep := BIRD_CHIRP_HZ - BIRD_SWEEP_HZ * 0.5 + BIRD_SWEEP_HZ * (beat / 0.18)
			samples[i] = sin(TAU * sweep * beat) * (1.0 - beat * 2.0) * 0.3
	return samples


static func _motif_samples() -> PackedFloat32Array:
	var count := int(ANTAGONIST_SECONDS * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t := float(i) / SAMPLE_RATE
		var hz := ANTAGONIST_HZ if fmod(t, 1.0) < 0.5 else ANTAGONIST_SECOND_HZ
		samples[i] = sin(TAU * hz * t) * 0.26
	return samples


static func _note_pattern_samples(
	notes: Array[float], slot_seconds: float, level: float
) -> PackedFloat32Array:
	# One held note per slot with a soft decay: a fixed, deterministic
	# pattern per venue, so no venue sounds like another.
	var count := int(DIEGETIC_SECONDS * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var slot_count := notes.size()
	for i: int in count:
		var t := float(i) / SAMPLE_RATE
		var slot := int(t / slot_seconds) % slot_count
		var beat := fmod(t, slot_seconds)
		var decay := maxf(0.0, 1.0 - beat * 1.6)
		samples[i] = sin(TAU * notes[slot] * t) * decay * level
	return samples


static func _silence_samples(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * SAMPLE_RATE))
	return samples


static func _looping_wave(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := _wave(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	return stream


static func _wave(samples: PackedFloat32Array) -> AudioStreamWAV:
	# A plain 16-bit mono PCM WAV built by hand: RIFF header, format chunk,
	# then the data chunk.
	var data_bytes := PackedByteArray()
	data_bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		var value := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data_bytes.encode_s16(i * 2, value)
	var bytes := PackedByteArray()
	bytes.append_array("RIFF".to_ascii_buffer())
	bytes.append_array(_u32(36 + data_bytes.size()))
	bytes.append_array("WAVE".to_ascii_buffer())
	bytes.append_array("fmt ".to_ascii_buffer())
	bytes.append_array(_u32(16))
	bytes.append_array(_u16(1))
	bytes.append_array(_u16(1))
	bytes.append_array(_u32(SAMPLE_RATE))
	bytes.append_array(_u32(SAMPLE_RATE * 2))
	bytes.append_array(_u16(2))
	bytes.append_array(_u16(16))
	bytes.append_array("data".to_ascii_buffer())
	bytes.append_array(_u32(data_bytes.size()))
	bytes.append_array(data_bytes)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


static func _u32(value: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, value)
	return out


static func _u16(value: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(2)
	out.encode_u16(0, value)
	return out
