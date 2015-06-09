package minisynthi.modules.poly ;

import com.ludamix.icl.ICL;
import com.ludamix.typelet.Typelet;
import haxe.ds.Vector;
import haxe.Serializer;
import haxe.Unserializer;
import luminary.PatchEdit.RangeMapping;
import minimidi.tools.Conversions;
import minimidi.tools.MathTools;
import minimidi.tools.WaveformParser;
import minisynthi.dsp.MystranSVF;
import minisynthi.dsp.Waveshaper;
import minisynthi.modules.poly.PolyX.PolyXPatch;
import minisynthi.modules.poly.PolyX.SequenceProfile;
import minisynthi.modules.poly.shared.*;
import minimidi.MIDIBytes;
import minimidi.MIDITuning;
import minimidi.MIDIEvent;
import minimidi.tools.Envelope;
import minimidi.tools.LFO;
import minimidi.tools.Envelope.ADSRConfig;

enum PolyXOscillator
{
	Sine;
	Square;
	Pulse25;
	Pulse12;
	Triangle;
	Sawtooth;
	Noise;
	TonalNoise;
}

enum PolyXFilter
{
	Off;
	LP;
	HP;
	BP;
}

class PolyX implements IPolyphonicModule
{
	
	public static inline var MIN_POWER = 0.00000000001;
	
	public static inline function osc(o : PolyXOscillator) { return Type.enumIndex(o); }
	public static inline function oscAvailable() { return Type.getEnumConstructs(PolyXOscillator); }
	public static inline function filterType(o : PolyXFilter) { return Type.enumIndex(o); }
	public static inline function filterTypeAvailable() { return Type.getEnumConstructs(PolyXFilter); }
	
	public var parent : MIDIPolyphonic;
	public var amplitude : Float;
	public var amplitude_target : Float;
	public var frequency : Float;
	
	public var filter : MystranSVF;
	public var waveshaper : Waveshaper;
	
	public var noise_pos : Float;
	
	public var amp_envelope : Envelope;
	public var amp_lfo : LFO;
	
	public var pitch_lfo : LFO;	
	public var pitch_envelope : Envelope;
	
	public var vibrato_lfo : LFO;	
	
	public var cutoff_lfo : LFO;	
	public var cutoff_envelope : Envelope;
	
	public var resonance_lfo : LFO;
	public var resonance_envelope : Envelope;
	
	public var waveshaper_lfo : LFO;
	public var waveshaper_envelope : Envelope;
	
	public var tonoise_lfo : LFO;
	public var tonoise_envelope : Envelope;
	
	public var tuning : MIDITuning;
	
	public var on : Float;
	public var samples_played : Float;
	
	public var output_amplitude : Float;
	
	public var bend_semitones : Int;
	public var modulation : Int;
	
	public var patch : PolyXPatch;
	
	public var uid : Int;
	
	public function processEvents(n : MIDIEvent)
	{
		var event_type = n.bytes.type();
		
		if (!TriggerRuleParser.allow(n.bytes, patch.trigger_rules))
			return;
		
		if (event_type == MIDIBytes.NOTE_OFF || (event_type == MIDIBytes.NOTE_ON && n.bytes.velocity() == 0))
		{
			noteOff();
		}
		else if (event_type == MIDIBytes.NOTE_ON)
		{
			this.on = 1.0;
			
			reset(tuning.midiNoteToFrequency(n.bytes.note()));
			
			if (patch.oscillator == osc(TonalNoise))
			{
				for (n in 0...tonalnoiseblock.length)
				{
					tonalnoiseblock[n] = Math.random() * 2 - 1;
				}
				tonalnoiseblock[tonalnoiseblock.length - 1] = tonalnoiseblock[0];
				filtonalNoise();
			}
			
		}
	}
	
	public function renderBuffer(buffer : Vector<Float>, note_event : AllocatedVoice)
	{
		if (note_event == null || note_event.shadow_channel == -1) return false;
		
		var channel = parent.channels[note_event.shadow_channel];
		bend_semitones = channel.bend_semitones;
		modulation = channel.cc[MIDIBytes.CC_MODULATION];
		
		var amplitude_modifier = (channel.volume() / 127) * (channel.expression() / 127) * (note_event.velocity / 127);
		
		frequency = tuning.midiNoteBentToFrequency(note_event.note, channel.pitch_bend - 0x2000, bend_semitones);
		
		var env_advance = parent.mixer.samplesToSeconds(parent.mixer.monoSize());
		
		var env_amplitude = amp_envelope.update(env_advance);
		
		amplitude_target = patch.amp.base * env_amplitude * Math.pow(amplitude_modifier, patch.amp_expression_curve);
		
		var frequency_target = this.frequency;
		if (frequency_target < 1) frequency_target = 1;
		
		return renderWavetable(buffer, channel, amplitude_modifier, amplitude_target, env_advance, 
			frequency_target);
		
	}
	
	public var tonoise_iterations : Int;
	public var tonoise_idx : Int;
	
	private function reset(frequency = 440.)
	{
		last_frequency = -1.;
		noise_pos = 0.;
		tuning = EvenTemperament.cache;
		amplitude = 0.;
		amplitude_target = 0.;
		this.frequency = frequency;
		this.samples_played = 0.;
		tonoise_iterations = 0;
		tonoise_idx = 0;
		bend_semitones = 2;
		modulation = 0;
		
		PolyXMacro.initEnvelope(patch.amp, amp_envelope);
		PolyXMacro.initLFO(patch.amp, amp_lfo);
		
		PolyXMacro.initEnvelope(patch.pitch, pitch_envelope);
		PolyXMacro.initLFO(patch.pitch, pitch_lfo);
		PolyXMacro.initLFO(patch.vibrato, vibrato_lfo);
		
		PolyXMacro.initEnvelope(patch.resonance, resonance_envelope);
		PolyXMacro.initLFO(patch.resonance, resonance_lfo);
		
		PolyXMacro.initEnvelope(patch.cutoff, cutoff_envelope);
		PolyXMacro.initLFO(patch.cutoff, cutoff_lfo);
		
		PolyXMacro.initEnvelope(patch.waveshape, waveshaper_envelope);
		PolyXMacro.initLFO(patch.waveshape, waveshaper_lfo);
		
		PolyXMacro.initEnvelope(patch.tonoise, tonoise_envelope);
		PolyXMacro.initLFO(patch.tonoise, tonoise_lfo);

		last_frequency = -1.;
		last_position = 0.;
		noiseSeed = Std.int(Math.random() * SIZE_INT);
		
		var cutoff_target = patch.cutoff.base;
		if (patch.cutoff_keytrack) cutoff_target += frequency;
		if (filter == null)
		{
			filter = new MystranSVF(cutoff_target, patch.resonance.base, 44100 * 2);
			//filter = new MoogSVF(cutoff_target, patch.resonance.base, 44100 * 2);
		}
		else
		{
			oversampleXtra = 0.;
			filter.cutoff = cutoff_target;
			filter.Q = patch.resonance.base;
			filter.calcCoefficents(true);
		}
		
		waveshaper = new Waveshaper();
		waveshaper.tf1 = patch.waveshaper_cache.tf1; 
		waveshaper.tf2 = patch.waveshaper_cache.tf2; 
		waveshaper.tf2_delta = patch.waveshaper_cache.tf2_delta;
	}
	
	public function new(uid)
	{
		this.uid = uid;
		this.on = 0.;
		output_amplitude = 0.1;
		patch = new PolyXPatch();
		
		if (wtCache == null)
		{
			wtCache = new Array();
			for (n in 0...oscAvailable().length)
			{
				wtCache.push(new Map()); // this actually gives us more than necessary...oh well
			}
		}
		
		if (sintab == null)
		{
			sintab = new Vector<Float>(2049);
			for (n in 0...sintab.length)
				sintab[n] = Math.sin(n / sintab.length * Math.PI * 2);
		}
		
	 	if (noiseblock == null)
		{
			noiseblock = new Vector<Float>(16385);
			for (n in 0...noiseblock.length)
				noiseblock[n] = Math.random() * 2 - 1;			
		}
		
		tonalnoiseblock = new Vector<Float>(33);
		filtonalnoiseblock = new Vector<Float>(65);
		
		reset();
		amp_envelope.setOff();
		
	}
	
	public function noteOff()
	{
		if (amp_envelope != null)
			amp_envelope.setRelease();
		else
		{
			amplitude = 0.;
			amplitude_target = 0.;
		}
		this.on = 0.;
		
		if (pitch_envelope != null)
			pitch_envelope.setRelease();
		if (cutoff_envelope != null)
			cutoff_envelope.setRelease();
		if (resonance_envelope != null)
			resonance_envelope.setRelease();
		if (tonoise_envelope != null)
			tonoise_envelope.setRelease();
		if (pitch_lfo != null)
			pitch_lfo.envelope.setRelease();
		if (vibrato_lfo != null)
			vibrato_lfo.envelope.setRelease();
		if (cutoff_lfo != null)
			cutoff_lfo.envelope.setRelease();
		if (resonance_lfo != null)
			resonance_lfo.envelope.setRelease();
		if (tonoise_lfo != null)
			tonoise_lfo.envelope.setRelease();
		last_frequency = -1.;
	}
	
	// White Noise from 32-bit LCG.
	// Taken from musicdsp.org
	// References : Hal Chamberlain, "Musical Applications of Microprocessors" (Posted by Phil Burk)
	// Works great! (but Math.random() is still higher quality for audio rate)

	public static inline var SIZE_INT = 2147483647;
	public static inline var NOISE_NORM = 1. / SIZE_INT;
	
	public var noiseSeed : Int;
	
	public inline function whiteNoise()
	{
		noiseSeed = (noiseSeed * 196314165) + 907633515;
		return noiseSeed * NOISE_NORM - 0.5;
	}
	
	// ensure that our oscillator output is above denormaling levels:
	public function forceToMin(amplitude : Float) { return (amplitude < MIN_POWER) ? MIN_POWER : amplitude; }
	
	public var tonalnoiseblock : Vector<Float>;
	public var filtonalnoiseblock : Vector<Float>;
	public var waveblock : Vector<Float>;
	public var last_frequency : Float;
	public var last_position : Float;
	
	public static var noiseblock : Vector<Float>;
	public static var sintab : Vector<Float>;
	public static var wtCache : Array<Map<Int, Vector<Float>>>;
	
	public function calcWaveblock(oscillator : Int, frequency : Float)
	{
		if (oscillator == osc(Noise)) 
			return noiseblock;
		else if (oscillator == osc(TonalNoise))
			return filtonalnoiseblock;
		else if (oscillator == osc(Sine))
			return sintab;
		
		/*
		 * dB balancing
		 * 
		 * Although we could just tune for RMS, perceptually this wouldn't be correct.
		 * Measurements taken at sustain 0.5, C-4, no filter or shaping.
		 * 
		 * sine: -55.0
		 * pulse1: -62.1
		 * pulse2: -64.6
		 * pulse3: -66.1
		 * tri: -57.9
		 * saw: -64.2
		 * noise: -57
		 * tonoise: -58
		 * 
		 * */
		
		// we cache every midi note to quarter-step accuracy. (This biases towards even temperament...oh well)
		var cacheidx = Std.int((12 * (Math.log(frequency / 440.) / Math.log(2))) * 4);
		frequency = (Math.pow(2, (cacheidx / 4) / 12) * 440); // snap computed freq
		var snap = wtCache[oscillator].get(cacheidx);
		if (snap != null) return snap;
		
		// create an additive signal!
		
		var CUTOFF = 1 / 2; // points needed to render a sine
		var octaves = 1;
		while (frequency*octaves < parent.mixer.samplerate()) { octaves++; }
		octaves = octaves >> 1;
		if (octaves < 1) octaves = 1;
		var output = new Vector<Float>(2049);
		var wt_length = output.length - 1;
		
		var hw = wt_length >> 1;
		
		var sintab_length = sintab.length - 1;
		
		var base_scale = 2 / Math.PI * 0.45;
		
		if (oscillator == osc(Sawtooth))
		{
			var scale = base_scale * 0.95;
			for (pos in 0...hw)
			{
				var result = 0.;
				var sign = -1;
				var ofreq = 1 / wt_length;
				var i = Math.round(pos / wt_length * sintab_length);
				
				var oo = 1;
				while (oo < octaves) 
				{
					result = result + sintab[i * oo & (sintab_length - 1)] * sign / oo;
					sign = -sign;
					oo++;
					if (oo * ofreq > CUTOFF) break; // cut off octaves too high to render accurately
				}
				
				output[pos] = result * scale;
			}
		}
		else if (oscillator == osc(Square) || oscillator == osc(Pulse25) || oscillator == osc(Pulse12))
		{
			var scale = base_scale;
			var wt_length = wt_length;
			var pw = 0.5;
			if (oscillator == osc(Pulse25)) { pw = 0.25; scale *= 1.2; }
			else if (oscillator == osc(Pulse12)) { pw = 0.125; scale *= 1.37; }
			else scale *= 1.4;
			var hpi = sintab_length >> 1;
			for (pos in 0...hw)
			{
				var result = 0.;
				var ofreq = 1 / wt_length;
				var i = Math.round(pos / wt_length * sintab_length);
				
				var oo = 1;
				while (oo < octaves) 
				{
					// general additive rectangular function (cos * sin)
					result = result + 
						sintab[Std.int((i + hpi) * oo) & (sintab_length - 1)] *
						sintab[Std.int(oo * pw * hpi) & (sintab_length - 1)]
						/ oo;
					oo+=1;
					if (oo * ofreq > CUTOFF) break; // cut off octaves too high to render accurately
				}
				
				output[pos] = result * scale;
			}			
		}
		else if (oscillator == osc(Triangle))
		{
			var scale = base_scale * 2.5;
			for (pos in 0...hw)
			{
				var result = 0.;
				var sign = -1;
				var ofreq = 1 / wt_length;
				var i = Math.round(pos / wt_length * sintab_length);
				
				var oo = 1;
				while (oo < octaves) 
				{
					result = result + sintab[i * oo & (sintab_length - 1)] * sign / (oo*oo);
					sign = -sign;
					oo+=2;
					if (oo * ofreq > CUTOFF) break; // cut off octaves too high to render accurately
				}
				
				output[pos] = result * scale;
			}
		}
		
		// we only compute half, and mirror the waveform at the halfway point.
		
		{
			for (pos in 0...hw)
			{
				output[pos + hw] = -output[hw - pos];
			}
		}
		
		// we pad by one because it's possible for the reader to jump over by one with FP error.
		output[output.length - 1] = output[0];
		
		wtCache[oscillator].set(cacheidx, output);
		
		return output;
	}

	/* precomputed blackman-harris convolution at 0%, 25%, 50% of the impulse */
	/* a0 = 0.35875; a1 = 0.48829; a2 = 0.14128; a3 = 0.01168; */
	/* function bharris(n0, s0) { var Z = Math.PI * n0 / (s0 - 1); return a0 - a1 * Math.cos(2 * Z) + a2 * Math.cos(4 * Z) - a3 * Math.cos(6 * Z);} */
	private static inline var BHARRISCOMP = 1.5;
	private static inline var BHARRIS0 = 0.00006 * BHARRISCOMP;
	private static inline var BHARRIS25 = 0.21747 * BHARRISCOMP;
	private static inline var BHARRIS50 = 1.0 * BHARRISCOMP;
	
	/* precomputed blackman convolution (alpha = 0.16) at 0%, 25%, 50% of the impulse */
	/* a0 = (1 - alpha) / 2; a1 = 1 / 2; a2 = alpha / 2; */
	/* function blackman(n0, s0) { var Z = Math.PI * n0 / (s0 - 1); return a0 - a1 * Math.cos(2 * Z) + a2 * Math.cos(4 * Z); } */
	private static inline var BLACKMANCOMP = 1.5;
	private static inline var BLACKMAN0 = 0.;
	private static inline var BLACKMAN25 = 0.3399999999999999 * BLACKMANCOMP;
	private static inline var BLACKMAN50 = 1.0 * BLACKMANCOMP;
	
	public inline function filtonalNoise()
	{
		for (i in 0...filtonalnoiseblock.length)
			filtonalnoiseblock[i] = 0.;
		for (i in 0...(tonalnoiseblock.length))
		{
			var s0 = tonalnoiseblock[i];
			filtonalnoiseblock[((i << 1) + 0) % (filtonalnoiseblock.length - 1)] += s0 * BLACKMAN25;
			filtonalnoiseblock[((i << 1) + 1) % (filtonalnoiseblock.length - 1)] += s0 * BLACKMAN50;
			filtonalnoiseblock[((i << 1) + 2) % (filtonalnoiseblock.length - 1)] += s0 * BLACKMAN25;
		}
	}
	
	public function renderWavetable(buffer : Vector<Float>, 
		channel : MIDIChannelState, amplitude_modifier : Float, amplitude_target : Float, env_advance : Float, 
		frequency_target : Float)
	{
		var tolerance = 0;
		
		var wt_frequency = frequency_target;
		
		if (Math.abs(wt_frequency - last_frequency)>tolerance || waveblock == null)
		{
			waveblock = calcWaveblock(patch.oscillator, wt_frequency);
			last_frequency = wt_frequency;
		}
		var wt_length = waveblock.length - 1;
		
		if (patch.oscillator == osc(Noise))
			last_position = (Math.random() * (waveblock.length-1));
			
		// we cache a "waveblock" when parameters change, and then just spam it over and over
		// until it's been invalidated. This reduces our biggest costs to "per-note" and "per-cycle"
		// considerations. High pitches may be somewhat more expensive since they write more cycles.
		
		var band_advance : Float = parent.mixer.sampleAdvanceRate(frequency) * wt_length;
		var band_advance_target : Float = parent.mixer.sampleAdvanceRate(frequency_target) * wt_length;
		
		if (amplitude_target > MIN_POWER || amplitude > MIN_POWER)
		{
			amplitude = forceToMin(amplitude); amplitude_target = forceToMin(amplitude_target);
			var advance_seconds : Float = parent.mixer.samplesToSeconds(buffer.length);
			if (amp_lfo.gain != 0.)
				amp_lfo.update(advance_seconds, whiteNoise() * patch.amp.lfo.random_frequency);
			
			var interp_amp = Math.min(1., Math.max(0., amplitude + amp_lfo.amplitude));
			var interp_target = Math.min(1., Math.max(0., amplitude_target + amp_lfo.amplitude));
			
			// lerp into the amplitude target
			var amp_advance = (interp_target - interp_amp) / buffer.length;
			// lerp into the frequency target
			var band_advance2 = (band_advance_target - band_advance) / buffer.length;
			
			var prevwrite_idx = 0;
			var write_idx = 0;
			while (write_idx < buffer.length)
			{
				// We compute the frequency of each cycle in advance, recomputing it as we cross into the next one.
				// This allows us to change wavetables and other parameters at the zero-crossing.
				
				var read_idx : Float = Std.int(last_position) & (wt_length - 1);
				
				// we compute and apply advance_seconds twice, once in the loop and once after.
				// otherwise pitch modulation doesn't update correctly!
				var advance_seconds : Float = parent.mixer.samplesToSeconds(write_idx - prevwrite_idx);
				pitch_lfo.update(advance_seconds, whiteNoise() * patch.pitch.lfo.random_frequency);
				pitch_envelope.update(advance_seconds);
				vibrato_lfo.update(advance_seconds, whiteNoise() * patch.vibrato.lfo.random_frequency);
				
				var pitch_depth = tuning.midiNoteToFrequency(
					tuning.frequencyToMidiNote(frequency) + pitch_lfo.amplitude + pitch_envelope.amplitude +
					(vibrato_lfo.amplitude + patch.vibrato.base) * (modulation/127)
					+ patch.pitch.base) - frequency;
				
				prevwrite_idx = write_idx;
				
				if (patch.oscillator == osc(TonalNoise))
				{
					tonoise_lfo.update(advance_seconds, whiteNoise() * patch.tonoise.lfo.random_frequency);
					tonoise_envelope.update(advance_seconds);
					if (read_idx == 0.)
					{
						var tonoise_mod_rate = Math.max(0., patch.tonoise.base + tonoise_lfo.amplitude + tonoise_envelope.amplitude);
						noise_pos += tonoise_mod_rate;
						var tonoise_interpolation = patch.tonoise_interpolation;
						var tonoise_volatility = patch.tonoise_volatility;
						// zero crossing - presently only used to advance the tonal noise
						while (noise_pos > 1.0)
						{
							tonoise_iterations--;
							if (tonoise_iterations <= 0)
							{
								tonoise_idx = Std.int(Math.random() * (tonalnoiseblock.length - 1));
								tonoise_iterations = tonoise_interpolation;
							}
							// noise modulations: we change a single sample in the block at random.
							tonalnoiseblock[tonoise_idx] += (Math.random() * 2 - 1)*tonoise_volatility;
							tonalnoiseblock[tonoise_idx] = Math.min(1., Math.max( -1., tonalnoiseblock[tonoise_idx]));
							tonoise_idx = (tonoise_idx + 1) % tonalnoiseblock.length;
							// then write a naive pulse wave after the part we touched. this forces in tonality and power.
							tonalnoiseblock[tonoise_idx] = tonoise_idx > (tonalnoiseblock.length >> 1) ? 1.0 : -1.0;
							noise_pos -= 1;
						}
						tonalnoiseblock[tonalnoiseblock.length - 1] = tonalnoiseblock[0];
						filtonalNoise();
					}
				}
				
				var pct : Float = write_idx / buffer.length;
				var read_advance : Float = Math.min(wt_length-1,
					Math.max(0.000001, band_advance + band_advance2 * pct + 
					parent.mixer.sampleAdvanceRate(pitch_depth) * 
						wt_length));
				
				// set the advancement quantity to fit the wavetable's resampled length
				var write_length = Std.int((wt_length - read_idx) / read_advance);
				var write_target = write_idx + write_length;
				
				// trim the advancement quantity to fit the needed buffer length
				if (write_target >= buffer.length)
				{
					write_length = (buffer.length - 1) - write_idx;
					write_target = buffer.length - 1;
				}
				
				// set up the waveshaper (we inlined it rather than put it after the oscillator + amp stage)
				var wamp = patch.waveshape.base + waveshaper_lfo.amplitude + waveshaper_envelope.amplitude;
				waveshaper_lfo.update(advance_seconds, whiteNoise() * patch.waveshape.lfo.random_frequency);
				waveshaper_envelope.update(advance_seconds);
				var wamp_target = patch.waveshape.base + waveshaper_lfo.amplitude + waveshaper_envelope.amplitude;
				var wet_i = (wamp_target - wamp) / (write_length);
				var scale = (waveshaper.tf1.length >> 1) - 1;
				var tf1 = waveshaper.tf1;
				var tf2_delta = waveshaper.tf2_delta;
				
				/*if (patch.oscillator == osc(TonalNoise)) // we (used to) render this a little better because it's such a tiny sample
				{
					var cycle = wt_length - 1;
					while(write_idx <= write_target)
					{
						// nicer linear interpolator
						var rint = Std.int(read_idx);
						var wb1 = waveblock[rint];
						var wb2 = waveblock[(rint+1) & (cycle)];
						var wspi = Std.int(Math.min(1., Math.max( -1., 
							(wb1 + (wb2 - wb1) * (read_idx - rint)))) * scale + scale);
						buffer[write_idx] = (tf1[wspi] + tf2_delta[wspi] * wamp) * interp_amp;
						// advance the amplitude interpolation
						interp_amp += amp_advance;
						read_idx += read_advance;			
						write_idx++;
					}
				}
				else*/
				{
					while(write_idx <= write_target)
					{
						var wspi = Std.int(Math.min(1., Math.max( -1., waveblock[Std.int(read_idx)])) * scale + scale);
						// drop-sample interpolator with the waveshape transfer function interpolated in
						buffer[write_idx] = (tf1[wspi] + tf2_delta[wspi] * wamp) * interp_amp;
						wamp += wet_i;
						// advance the amplitude interpolation
						interp_amp += amp_advance;
						read_idx += read_advance;		
						write_idx++;
					}
				}
				
				last_position = read_idx;
				
			}
			
			var advance_seconds : Float = parent.mixer.samplesToSeconds(write_idx - prevwrite_idx);
			pitch_lfo.update(advance_seconds, whiteNoise() * patch.pitch.lfo.random_frequency);
			pitch_envelope.update(advance_seconds);
			vibrato_lfo.update(advance_seconds, whiteNoise() * patch.vibrato.lfo.random_frequency);
			waveshaper_lfo.update(advance_seconds, whiteNoise() * patch.waveshape.lfo.random_frequency);
			waveshaper_envelope.update(advance_seconds);
			amp_lfo.update(advance_seconds, whiteNoise() * patch.amp.lfo.random_frequency);
			
			if (patch.oscillator == osc(TonalNoise))
			{
				tonoise_lfo.update(advance_seconds, whiteNoise() * patch.tonoise.lfo.random_frequency);
				tonoise_envelope.update(advance_seconds);
			}
			
			amplitude = amplitude_target;
			frequency = frequency_target;
			
			//runFilter(buffer);
			runFilter2x(buffer);
			setOnValue(buffer.length);
			
			return true;			
		}
		else
		{
			amplitude = amplitude_target;
			frequency = frequency_target;
			var advance_seconds : Float = parent.mixer.samplesToSeconds(buffer.length);
			pitch_lfo.update(advance_seconds, whiteNoise() * patch.pitch.lfo.random_frequency);
			pitch_envelope.update(advance_seconds);
			vibrato_lfo.update(advance_seconds, whiteNoise() * patch.vibrato.lfo.random_frequency);
			amp_lfo.update(advance_seconds, whiteNoise() * patch.amp.lfo.random_frequency);
			waveshaper_lfo.update(advance_seconds, whiteNoise() * patch.waveshape.lfo.random_frequency);
			cutoff_lfo.update(advance_seconds, whiteNoise() * patch.cutoff.lfo.random_frequency);
			resonance_lfo.update(advance_seconds, whiteNoise() * patch.resonance.lfo.random_frequency);
			waveshaper_envelope.update(advance_seconds);
			cutoff_envelope.update(advance_seconds);
			resonance_envelope.update(advance_seconds);
			if (patch.oscillator == osc(TonalNoise))
			{
				tonoise_lfo.update(advance_seconds, whiteNoise() * patch.tonoise.lfo.random_frequency);
				tonoise_envelope.update(advance_seconds);
			}
			if (patch.filter_type != filterType(Off)) 
			{
				var cutoff_base = patch.cutoff.base;
				if (patch.cutoff_keytrack) cutoff_base += frequency;
				var resonance_base = patch.resonance.base;
				filter.cutoff = cutoff_base + cutoff_envelope.amplitude + cutoff_lfo.amplitude;
				filter.Q = resonance_base + resonance_envelope.amplitude + resonance_lfo.amplitude;				
				filter.calcCoefficents(true);
			}
			
			setOnValue(buffer.length);
			
			return false;
		}
	}
	
	public function setOnValue(advance_samples : Float)
	{
		samples_played += advance_samples;
		if (this.amp_envelope.attacking())
			on = 0.9 + this.amp_envelope.amplitude * 0.1;
		else if (this.amp_envelope.releasing)
			on = this.amp_envelope.amplitude * 0.1;
		else
			on = 1 - (0.8 / (advance_samples));
	}
	
	public function runFilter(buffer : Vector<Float>)
	{
		var n = 0;
		var FILT_STEP = 64; // max samples until we run LFO, envelope, coefficient calculations
		var advance_seconds = parent.mixer.samplesToSeconds(FILT_STEP);
		var cutoff_base = patch.cutoff.base;
		if (patch.cutoff_keytrack) cutoff_base += frequency;
		var resonance_base = patch.resonance.base;
		
		while (n<buffer.length - 1)
		{
			var nxt = Std.int(Math.min(FILT_STEP, buffer.length - n));
			cutoff_lfo.update(advance_seconds, whiteNoise() * patch.cutoff.lfo.random_frequency);
			resonance_lfo.update(advance_seconds, whiteNoise() * patch.resonance.lfo.random_frequency);
			cutoff_envelope.update(advance_seconds);
			resonance_envelope.update(advance_seconds);
			
			filter.cutoff = cutoff_base + cutoff_envelope.amplitude + cutoff_lfo.amplitude;
			filter.Q = resonance_base + resonance_envelope.amplitude + resonance_lfo.amplitude;
			filter.samplerate = 44100;
			filter.calcCoefficents(false);
			if (patch.filter_type == filterType(LP))
				filter.getManyLP(buffer, n, n + nxt);
			else if (patch.filter_type == filterType(HP))
				filter.getManyHP(buffer, n, n + nxt);
			else if (patch.filter_type == filterType(BP))
				filter.getManyBP(buffer, n, n + nxt);
			n+= nxt;
		}		
	}
	
	public var oversampleXtra : Float;
	public var sbuffer : Vector<Float>;
	
	public function runFilter2x(obuffer : Vector<Float>)
	{
		/* only oversample if we're going to actually use the filter... */
		var buffer = obuffer;
		if (patch.filter_type != filterType(Off))
		{
			/* oversample with the blackman window */
			if (sbuffer == null)
				sbuffer = new Vector(obuffer.length * 2);
			buffer = sbuffer;
			buffer[0] = (obuffer[0] + oversampleXtra) * BHARRIS25;
			buffer[1] = obuffer[0] * BHARRIS50;
			oversampleXtra = obuffer[obuffer.length - 1];
			for (i0 in 1...obuffer.length)
			{
				buffer[i0 * 2] = (obuffer[i0-1] + obuffer[i0]) * BHARRIS25;
				buffer[i0 * 2 + 1] = obuffer[i0] * BHARRIS50;
			}
		}
		var n = 0;
		var FILT_STEP = 128; // max samples until we run LFO, envelope, coefficient calculations
		var advance_seconds = parent.mixer.samplesToSeconds(FILT_STEP);
		var cutoff_base = patch.cutoff.base;
		if (patch.cutoff_keytrack) cutoff_base += frequency;
		var resonance_base = patch.resonance.base;
		
		while (n<buffer.length - 1)
		{
			var nxt = Std.int(Math.min(FILT_STEP, buffer.length - n));
			cutoff_lfo.update(advance_seconds, whiteNoise() * patch.cutoff.lfo.random_frequency);
			resonance_lfo.update(advance_seconds, whiteNoise() * patch.resonance.lfo.random_frequency);
			cutoff_envelope.update(advance_seconds);
			resonance_envelope.update(advance_seconds);
			
			filter.cutoff = cutoff_base + cutoff_envelope.amplitude + cutoff_lfo.amplitude;
			filter.Q = resonance_base + resonance_envelope.amplitude + resonance_lfo.amplitude;
			filter.samplerate = 44100 * 2;
			filter.calcCoefficents(false);
			if (patch.filter_type == filterType(LP))
				filter.getManyLP(buffer, n, n + nxt);
			else if (patch.filter_type == filterType(HP))
				filter.getManyHP(buffer, n, n + nxt);
			else if (patch.filter_type == filterType(BP))
				filter.getManyBP(buffer, n, n + nxt);
			n+= nxt;
		}
		
		/* quick decimation */
		if (patch.filter_type != filterType(Off))
		{
			for (i0 in 0...obuffer.length)
			{
				obuffer[i0] = buffer[i0 * 2 + 1]; // taking the 1 offset gives us the peaks most similar to the original
			}
		}
		
	}
	
	public function name() { return "PolyX"; }
		
	public static function header() : ModuleHeaderType
	{
		return {
			name:"PolyX", read:function(d:Dynamic) { return new PolyXPatch();}
		};
	}
	
	public function getPart()
	{
		return patch;
	}
	
	public function setPart(p : Dynamic)
	{
		this.patch = p;
	}
	
	public function id() { return MIDIPolyphonic.POLYX; }
	public static function _id() { return MIDIPolyphonic.POLYX; }
	
}

enum SequenceSourceType { Raw; Lerp; Sine; Square; Saw; Triangle; Unit; }

class SequenceProfile
{
	public var cache : Vector<Float>;
	public var src : Array<Float>;
	public var src_type : SequenceSourceType;
	
	public function new()
	{
	}
	
	public function parse(src, src_type)
	{
		this.src = src;
		this.src_type = src_type;
		var SEQRES = 4096;
		switch(src_type)
		{
			case Raw:
				cache = Vector.fromArrayCopy(src);
			case Lerp:
				cache = WaveformParser.lerp(Vector.fromArrayCopy(src), 32768);
			case Sine:
				if (_sintab == null) _sintab = Vector.fromArrayCopy([for (n in 0...SEQRES) Math.sin(n / SEQRES * Math.PI * 2)]);
				cache = _sintab; src = null;
			case Square:
				var SQRRES = SEQRES >> 1;
				if (_sqrtab == null) _sqrtab = Vector.fromArrayCopy([for (n in 0...SEQRES) n < SQRRES ? 1. : -1.]);
				cache = _sqrtab; src = null;
			case Saw:
				if (_sawtab == null) _sawtab = Vector.fromArrayCopy([for (n in 0...SEQRES) n / (SEQRES-1) * 2 - 1]);
				cache = _sawtab; src = null;
			case Triangle:
				var TRIRES = SEQRES >> 1;
				if (_tritab == null) _tritab = Vector.fromArrayCopy([for (n in 0...TRIRES) n / TRIRES * 2 - 1].concat([for (n in 0...TRIRES) 1 - (n / TRIRES * 2)]));
				cache = _tritab; src = null;
			case Unit:
				if (_unittab == null) _unittab = WaveformParser.lerp(Vector.fromArrayCopy([0., 1.]), 32768);
				cache = _unittab; src = null;
		}
	}
	
	private static var _sintab : Vector<Float>;
	private static var _sqrtab : Vector<Float>;	
	private static var _sawtab : Vector<Float>;	
	private static var _tritab : Vector<Float>;	
	private static var _unittab : Vector<Float>;
	
	private static inline var VERSION = 1;
	
	@:keep
	function hxSerialize(s : Serializer)
	{
		s.serialize({_v:VERSION, src:src, type:Type.enumIndex(src_type)});
	}
	
	@:keep
	function hxUnserialize(u : Unserializer)
	{
		var o = u.unserialize();
		parse(o.src, Type.createEnumIndex(SequenceSourceType, o.type));
	}
	
}

class LFOProfile
{
	
	public var sequence : SequenceProfile;
	public var frequency : Float;
	public var envelope : EnvelopeProfile;
	public var interp : Bool;
	public var depth : Float;
	public var random_frequency : Float;
	
	public function new()
	{
		sequence = new SequenceProfile();
		sequence.parse(null, Sine);
		interp = true;
		envelope = EnvelopeProfile.instant_env();
		frequency = 1.;
		depth = 0.;
		random_frequency = 0.;		
	}
	
	private static inline var VERSION = 1;
	
	@:keep
	function hxSerialize(s : Serializer)
	{
		s.serialize( { _v:VERSION, sequence:sequence, frequency:frequency, envelope:envelope,
			interp:interp, depth:depth, random_frequency:random_frequency });
	}
	
	@:keep
	function hxUnserialize(u : Unserializer)
	{
		var o = u.unserialize();
		sequence = o.sequence;
		frequency = o.frequency;
		envelope = o.envelope;
		interp = o.interp;
		depth = o.depth;
		random_frequency = o.random_frequency;
	}
	
}

class GenericParameter
{
	
	public var base : Float;
	public var envelope : EnvelopeProfile;
	public var envelope_depth : Float;
	public var lfo : LFOProfile;
	
	public function new()
	{
		base = 0.;
		envelope = EnvelopeProfile.flat_env();
		lfo = new LFOProfile();
		envelope_depth = 0.;
		
	}
	
	private static inline var VERSION = 1;
	
	@:keep
	function hxSerialize(s : Serializer)
	{
		s.serialize( { _v:VERSION, base:base, envelope:envelope, envelope_depth:envelope_depth,
			lfo:lfo } );
	}
	
	@:keep
	function hxUnserialize(u : Unserializer)
	{
		var o = u.unserialize();
		base = o.base;
		envelope = o.envelope;
		envelope_depth = o.envelope_depth;
		lfo = o.lfo;
	}	
	
	public function parse(data : String, db_envelope : Bool)
	{
		var arch = new TypeletArchetype();
		arch.set("base", ["float"]);
		if (db_envelope)
			arch.set("envelope", ["envelope_db", "string"]);
		else
			arch.set("envelope", ["envelope_pct","string"]);
		arch.set("envelope_depth", ["float"]);
		arch.set("lfo_sequence", ["sequence","string"]);
		arch.set("lfo_frequency", ["float"]);
		arch.set("lfo_depth", ["float"]);
		arch.set("lfo_envelope", ["envelope_pct","string"]);
		arch.set("lfo_interp", ["bool"]);
		arch.set("lfo_random_frequency", ["float"]);
		
		var table = new TypeletTable([ { name:"string", parser:Std.string, unparse:Std.string },
			{ name:"float", parser:Std.parseFloat, unparse:Std.string },
			{ name:"int", parser:Std.parseInt, unparse:Std.string },
			{ name:"bool", parser:function(s:String):Dynamic {
				s = StringTools.trim(s.toLowerCase());
				return (s == "true"); }, unparse:Std.string },
			{ name:"sequence", parser:function(s:String):Dynamic {
				return s;
				}, unparse:function(s:Typelet) { return s.data; } },
			{ name:"envelope_db", parser:function(s:String):Dynamic {
				var e = EnvelopeProfile.stringAsDSAHDSHR(s, -9999, 0., 1.);
				e.start = Conversions.attentuationDBtoPctPower(e.start);
				e.sustain = Conversions.attentuationDBtoPctPower(e.sustain);
				if (e.start <= PolyX.MIN_POWER)
					e.start = 0.;
				if (e.sustain <= PolyX.MIN_POWER)
					e.sustain = 0.;
				var v = new EnvelopeProfile();
				v.parse(e, ADSR);
				return v;
			}, unparse:function(s:Typelet) { return s.data; } },
			{ name:"envelope_pct", parser:function(s:String):Dynamic {
				var e = EnvelopeProfile.stringAsDSAHDSHR(s, 0., 1., 1.);
				var v = new EnvelopeProfile();
				v.parse(e, ADSR);
				return v;
			}, unparse:function(s:Typelet) { return s.data; } }
			]);
		
		var t = Typelet.read(data, table, arch);
		
		var base = t.get('base');
		var envelope = t.get('envelope');
		var envelope_depth = t.get('envelope_depth');
		var lfo_sequence = t.get('lfo_sequence');
		var lfo_frequency = t.get('lfo_frequency');
		var lfo_depth = t.get('lfo_depth');
		var lfo_envelope = t.get('lfo_envelope');
		var lfo_interp = t.get('lfo_interp');
		var lfo_random_frequency = t.get('lfo_random_frequency');
		
		if (base != null)
		{
			if (db_envelope)
				this.base = Conversions.attentuationDBtoPctPower(base.result);
			else
				this.base = base.result;
		}
		
		if (envelope != null) { this.envelope = envelope.result; }
		if (envelope_depth != null) this.envelope_depth = envelope_depth.result;
		if (lfo_sequence != null) { this.lfo.sequence = new SequenceProfile(); 
			this.lfo.sequence.parse(WaveformParser.parse(lfo_sequence.result),Lerp); }
		if (lfo_envelope != null) { this.lfo.envelope = lfo_envelope.result; }
		if (lfo_frequency != null) this.lfo.frequency = lfo_frequency.result;
		if (lfo_interp != null) this.lfo.interp = lfo_interp.result;
		if (lfo_random_frequency != null) this.lfo.random_frequency = lfo_random_frequency.result;
		if (lfo_depth != null) this.lfo.depth = lfo_depth.result;
		
	}
	
}

class PolyXPatch
{
	
	public var oscillator : Int;
	
	public var amp_expression_curve : Float;
	
	public var amp : GenericParameter;
	public var pitch : GenericParameter;
	public var vibrato : GenericParameter;
	public var cutoff : GenericParameter;
	public var resonance : GenericParameter;
	public var tonoise : GenericParameter;
	public var tonoise_interpolation : Int;
	public var tonoise_volatility : Float;
	public var waveshape : GenericParameter;
	public var waveshaper_cache : {tf1:Vector<Float>,tf2:Vector<Float>,tf2_delta:Vector<Float>};
	public var cutoff_keytrack : Bool;
	
	public var filter_type : Int;
	
	public var trigger_rules : Array<ITriggerRule>; 
	
	public var name : String;
	
	public static var ws_flat : Vector<Float>;
	
	private static inline var VERSION = 1;

	public function new():Void 
	{
		oscillator = PolyX.osc(Sine);
		amp_expression_curve = 0.3;
		tonoise_interpolation = 5;
		tonoise_volatility = 0.15;
		cutoff_keytrack = true;
		
		this.amp = defaultAmp();
		this.pitch = defaultPitch();
		this.vibrato = defaultVibrato();
		this.cutoff = defaultCutoff();
		this.resonance = defaultResonance();		
		this.tonoise = defaultTonoise();		
		this.waveshape = defaultWaveshape();
		this.name = "default";
		filter_type = PolyX.filterType(Off);	
		
		if (ws_flat == null) ws_flat = Vector.fromArrayCopy([for (n in 0...32768) n/32767]);
		waveshaper_cache = Waveshaper.compile(ws_flat, ws_flat);
		
		trigger_rules = new Array();
		
	}
	
	private static function defaultWaveshape()
	{
		var waveshape = new GenericParameter();
		waveshape.base = 0.0;
		waveshape.envelope_depth = 1.0;
		waveshape.lfo.depth = 0.0;
		return waveshape;
	}
	
	private static function defaultAmp()
	{
		var amp = new GenericParameter();
		amp.base = 1.0;
		var p = new EnvelopeProfile();
		p.parse( { attack:0.03, decay:0.3, sustain:0.4, release:0.5, curve_atk:0.2, curve_dec:3., curve_rel:3.,
			delay:0.,start:0.,hold_atk:0.,hold_rel:0.}, ADSR);
		amp.envelope = p;
		amp.envelope_depth = 1.0;
		return amp;
	}
	
	private static function defaultPitch()
	{
		return new GenericParameter();
	}
	
	private static function defaultTonoise()
	{
		var tonoise = new GenericParameter();
		tonoise.envelope_depth = 20.0;
		tonoise.lfo.depth = 0.0;
		return tonoise;
	}
	
	private static function defaultVibrato()
	{
		var vibrato = new GenericParameter();
		var p = new EnvelopeProfile(); p.parse( {
			delay:0.1, start:0., attack:1.0, hold_atk:0., decay:0., sustain:1.0, hold_rel:99999., release:99999., 
			curve_atk:1.0, curve_dec:1.0, curve_rel:1.0},ADSR);
		vibrato.lfo.envelope = p;
		vibrato.lfo.depth = 0.5;
		vibrato.lfo.frequency = 3.0;
		return vibrato;
	}
	
	private static function defaultCutoff()
	{
		var cutoff = new GenericParameter();
		cutoff.base = 5000.;
		return cutoff;
	}
	
	private static function defaultResonance()
	{
		var resonance = new GenericParameter();
		resonance.base = 1.0;
		return resonance;
	}

	public function toString()
	{
		return name;
	}
	
	public function module()
	{
		return MIDIPolyphonic.POLYX;
	}
	
	public static function compile(d:PolyXHLPart)
	{
		var p = new PolyXPatch();
		var setupEnvLFO = function(f : String) {
			var lfo : LFOConfig; var env : ADSRConfig; var gp : GenericParameter;
			lfo = d.lfo[Reflect.field(d, f).lfo]; env = d.env[Reflect.field(d, f).env]; gp = Reflect.field(p, f);
			
			gp.envelope = new EnvelopeProfile();
			gp.envelope.parse(env, ADSR); 
			
			gp.lfo.frequency = lfo.r;
			gp.lfo.envelope.parse( { delay:lfo.d, start:0., attack:lfo.a, hold_atk : 0., decay : 0., sustain : 1., 
				hold_rel : 9999., release : 9999., curve_atk : 2., curve_dec : 1., curve_rel : 1. }, ADSR);
			switch(lfo.t)
			{
				case "Sine": gp.lfo.sequence.parse(null, Sine);
				case "Square": gp.lfo.sequence.parse(null, Square);
				case "Saw": gp.lfo.sequence.parse(null, Saw);
				case "Triangle": gp.lfo.sequence.parse(null, Triangle);
			}			
		};
		setupEnvLFO("amp");
		p.amp.envelope_depth = d.amp.env_depth;
		p.amp.base = d.amp.base;
		p.amp_expression_curve = d.amp.expression;
		p.amp.lfo.depth = d.amp.lfo_depth;
		setupEnvLFO("cutoff");
		p.cutoff.envelope_depth = d.cutoff.env_depth;
		p.cutoff.base = d.cutoff.base;
		p.cutoff_keytrack = d.cutoff.keytrack;
		p.cutoff.lfo.depth = d.cutoff.lfo_depth;
		setupEnvLFO("resonance");
		p.resonance.envelope_depth = d.resonance.env_depth;
		p.resonance.base = d.resonance.base;
		p.resonance.lfo.depth = d.resonance.lfo_depth;
		setupEnvLFO("tonoise");
		p.tonoise.base = d.tonoise.base;
		p.tonoise.lfo.depth = d.tonoise.lfo_depth;
		p.tonoise.envelope_depth = d.tonoise.env_depth;
		setupEnvLFO("waveshape");
		p.waveshape.base = d.waveshape.base;
		p.waveshape.lfo.depth = d.waveshape.lfo_depth;
		p.waveshape.envelope_depth = d.waveshape.env_depth;
		setupEnvLFO("vibrato");
		p.vibrato.base = d.vibrato.base0 + d.vibrato.base1;
		p.vibrato.envelope_depth = d.vibrato.env_depth;
		p.vibrato.lfo.depth = d.vibrato.lfo_depth0 + d.vibrato.lfo_depth1;
		setupEnvLFO("pitch");
		p.pitch.base = d.pitch.base0 + d.pitch.base1;
		p.pitch.envelope_depth = d.pitch.env_depth0 + d.pitch.env_depth1;
		p.pitch.lfo.depth = d.pitch.lfo_depth;
		p.filter_type = d.filter_type;
		p.tonoise_interpolation = d.tonoise.interpolation;
		p.tonoise_volatility = d.tonoise.volatility;
		p.oscillator = d.oscillator;
		p.waveshaper_cache = d.tf_cache;
		return p;
	}
	
}

enum LFOType { Sine; Square; Saw; Triangle; }
typedef LFOConfig = { t:String, r/*rate(frequency)*/ : Float, d/*delay time*/:Float, a/*attack time*/:Float };

typedef WaveshapeConfig = { /*ramp curve*/ rcurve : Float, /*ramp amplitude*/ ramp : Float, 
	/*sine offset*/ soff : Float, /*sine frequency coarse*/ sfreq0 : Int, /*sine frequency fine*/ sfreq1 : Float, /*sine amplitude*/ samp : Float };

class PolyXHLPart
{
	
	/*
	 * 
	 * The HL part is a simplified interface into PolyXPatch. It doesn't support every feature of the sound engine.
	 * It is the mapping between the low-level patch and the editing UI, providing boxed numeric types and valid ranges.
	 * 
	 * */	
	
	public var env : Array<ADSRConfig>;
	public var lfo : Array<LFOConfig>;
	public var amp : { env:Int, lfo:Int, base:Float, env_depth:Float, lfo_depth:Float, expression:Float };
	public var cutoff : { env:Int, lfo:Int, base:Float, env_depth:Float, lfo_depth:Float, keytrack:Bool };
	public var resonance : { env:Int, lfo:Int, base:Float, env_depth:Float, lfo_depth:Float };
	public var vibrato : { env:Int, lfo:Int, base0:Int, base1:Float, env_depth:Float, lfo_depth0:Int, lfo_depth1:Float };
	public var pitch : { env:Int, lfo:Int, base0:Int, base1:Float, env_depth0:Float, env_depth1:Float, lfo_depth:Float };
	public var waveshape : { env:Int, lfo:Int, base:Float, env_depth:Float, lfo_depth:Float};
	public var tonoise : { env:Int, lfo:Int, base:Float, env_depth:Float, lfo_depth:Float, interpolation:Int, volatility:Float };
	public var filter_type : Int;
	public var oscillator : Int;
	public var ws0 : WaveshapeConfig;
	public var ws1 : WaveshapeConfig;
	public var tf_cache : { tf1:Vector<Float>, tf2:Vector<Float>, tf2_delta:Vector<Float> };
	
	public function new() { }
	
	/* these don't actually serialize...they just act on a form of serializable object. Beware if you copy!*/
	public function serialize() {
		var ser = {
			version:0,
			id:"PolyXHLPart",
			env:env, lfo:lfo,
			amp:amp, cutoff:cutoff,
			resonance:resonance, vibrato:vibrato,
			pitch:pitch, waveshape:waveshape,
			tonoise:tonoise, 
			filter_type:filter_type, 
			oscillator:oscillator,
			ws0:ws0, ws1:ws1
		}; // v0: should save everything except tf_cache
		return ser;
	}
	public function unserialize(ser : Dynamic) {
		if (ser.version == 0)
		{
			env = ser.env; lfo = ser.lfo; amp = ser.amp; cutoff = ser.cutoff;
			resonance = ser.resonance; vibrato = ser.vibrato; pitch = ser.pitch;
			waveshape = ser.waveshape; tonoise = ser.tonoise; filter_type = ser.filter_type;
			oscillator = ser.oscillator; ws0 = ser.ws0; ws1 = ser.ws1;
			recacheWaveshape();
		}
		else throw 'unknown polyx part version ${ser.version}';
	}
	
	public function blank() {
		env = [
				{ delay : 0., start : 0., attack : 0.05, hold_atk : 0., 
				  decay : 0.3, sustain : 0.5, hold_rel : 0., release : 0.3, curve_atk : 4/10, curve_dec : 4/10, curve_rel : 4/10},
				{ delay : 0., start : 0., attack : 0.05, hold_atk : 0., 
				  decay : 0.3, sustain : 0.5, hold_rel : 0., release : 0.3, curve_atk : 4/10, curve_dec : 4/10, curve_rel : 4/10},
				{ delay : 0., start : 0., attack : 0.05, hold_atk : 0., 
				  decay : 0.3, sustain : 0.5, hold_rel : 0., release : 0.3, curve_atk : 4/10, curve_dec : 4/10, curve_rel : 4/10},
				{ delay : 0., start : 0., attack : 0.05, hold_atk : 0., 
				  decay : 0.3, sustain : 0.5, hold_rel : 0., release : 0.3, curve_atk : 4/10, curve_dec : 4/10, curve_rel : 4/10},
		]; 
		lfo = [
			{t:Type.enumConstructor(Sine), d:0.03, a:0.3, r:2.5},
			{t:Type.enumConstructor(Sine), d:0.03, a:0.3, r:2.5},
			{t:Type.enumConstructor(Sine), d:0.03, a:0.3, r:2.5},
			{t:Type.enumConstructor(Sine), d:0.03, a:0.3, r:2.5},
		];
		amp = { env:0, lfo:0, base:1., env_depth:1., lfo_depth:0., expression:0.3 };
		cutoff = { env:0, lfo:0, base:22050., env_depth:0., lfo_depth:0., keytrack:true };
		resonance = { env:0, lfo:0, base:1., env_depth:0., lfo_depth:0. };
		vibrato = { env:0, lfo:0, base0:0, base1:0., env_depth:0., lfo_depth0:0, lfo_depth1:0.5 };
		pitch = { env:0, lfo:0, base0:0, base1:0., env_depth0:0., env_depth1:0., lfo_depth:0. };
		var flat = Vector.fromArrayCopy([for (n in 0...32768) n/32767]);
		waveshape = { env:0, lfo:0, base:0., env_depth:0., lfo_depth:0. };
		tonoise = { env:0, lfo:0, base:0., env_depth:0., lfo_depth:0., interpolation:5, volatility:0.1 };
		filter_type = 0;
		oscillator = 0;
		ws0 = { rcurve : 1., ramp : 1., soff : 0., sfreq0 : 0, sfreq1 : 1., samp : 0. };
		ws1 = { rcurve : 1., ramp : 1., soff : 0., sfreq0 : 0, sfreq1 : 1., samp : 0. };
		tf_cache = Waveshaper.compile(flat, flat);
	}

	/* box range float, int, bool, adsrconfig */
	private function brf(o : Dynamic, f : String, r : RangeMapping) { 
		return { g:function() : Float { return Reflect.field(o, f); }, s:function(v : Float) { Reflect.setField(o, f, v); }, r:r }; }
	private function bri(o : Dynamic, f : String, r : RangeMapping) { 
		return { g:function() : Int { return Reflect.field(o, f); }, s:function(v : Float) { Reflect.setField(o, f, Std.int(v)); }, r:r }; }
	private function brb(o : Dynamic, f : String, d /*default*/ : Bool) { 
		return { g:function() : Bool { return Reflect.field(o, f); }, s:function(v : Bool) { Reflect.setField(o, f, v); }, d:d }; }
	private function brlt(o : Dynamic, f : String, d /*default*/ : String) { 
		return { g:function() : String { return Reflect.field(o, f); }, s:function(v : String) { Reflect.setField(o, f, v); }, d:d }; }
	private function bradsr(o : ADSRConfig) { 
		return {
			delay : brf(o, "delay", RangeMapping.pos(0., 10., 1/4., 0.)),
			start : brf(o, "start", RangeMapping.pos(0., 1., 1., 0.)),
			sustain : brf(o, "sustain", RangeMapping.pos(0., 1., 1/2, 1.)),
			attack : brf(o, "attack", RangeMapping.pos(0., 30., 1/4., 0.)),
			decay : brf(o, "decay", RangeMapping.pos(0., 30., 1/4., 0.)),
			release : brf(o, "release", RangeMapping.pos(0., 30., 1/4., 0.)),
			hold_atk : brf(o, "hold_atk", RangeMapping.pos(0., 10., 1/4., 0.)),
			hold_rel : brf(o, "hold_rel", RangeMapping.pos(0., 10., 1/4., 0.)),
			curve_atk : brf(o, "curve_atk", RangeMapping.pos(0., 6., 1/3, 0.3)),
			curve_dec : brf(o, "curve_dec", RangeMapping.pos(0., 6., 1/3, 0.3)),
			curve_rel : brf(o, "curve_rel", RangeMapping.pos(0., 6., 1/3, 0.3))
		};
	}
	private function brlfo(o : LFOConfig) { 
		return {
			rate : brf(o, "r", RangeMapping.pos(0.001, 80., 1/4., 1.)),
			delay : brf(o, "d", RangeMapping.pos(0., 10., 1/4., 0.)),
			attack : brf(o, "a", RangeMapping.pos(0., 30., 1 / 4., 0.)),
			type : brlt(o, "t", Type.enumConstructor(Sine))
		};
	}
	private function brws(o : WaveshapeConfig) {
		return {
			rcurve : brf(o, "rcurve", RangeMapping.pos(0.01, 10, 1/4., 1.)), 
			ramp : brf(o, "ramp", RangeMapping.neg(-4., 4., 1/4., 1.)),
			soff : brf(o, "soff", RangeMapping.neg(-1., 1., 1/2., 0.)),
			sfreq0 : bri(o, "sfreq0", RangeMapping.pos(0., 32, 1., 1.)),
			sfreq1 : brf(o, "sfreq1", RangeMapping.pos(0.01, 1, 1., 1.)),
			samp : brf(o, "samp", RangeMapping.neg( -4, 4., 1 / 4., 0.)),
			recache : recacheWaveshape
		};
	}
	
	public static var _last_ws = new Array<{in0:WaveshapeConfig,in1:WaveshapeConfig,output:{tf1:Vector<Float>,tf2:Vector<Float>,tf2_delta:Vector<Float>}}>();
	
	public function wsEquals(c0 : WaveshapeConfig, c1 : WaveshapeConfig)
	{
		return (
			c0.ramp == c1.ramp && c0.rcurve == c1.rcurve && c0.samp == c1.samp && c0.sfreq0 == c1.sfreq0 && c0.sfreq1 == c1.sfreq1 && c0.soff == c1.soff
		);
	}
	
	public function recacheWaveshape()
	{
		var r = new Array<Vector<Float>>();
		for (n in _last_ws) // optimization to reuse the last waveshapes (a huge savings on recompile times)
		{
			if (wsEquals(ws0, n.in0) && wsEquals(ws1, n.in1))
			{
				tf_cache = n.output;
				return;
			}
		}
		if (_last_ws.length > 64) _last_ws.shift();
		for (w in [ws0, ws1])
		{
			var LIM = 2048; var rx = new Vector<Float>(LIM); r.push(rx);
			for (i in 0...LIM)
			{
				var pct = i / (LIM - 1);
				var a = Math.max(-1., Math.min(1., (Math.pow(pct, w.rcurve) * w.ramp) + Math.sin((pct + w.soff) * Math.PI * 2 * (w.sfreq0 + w.sfreq1)) * w.samp));
				rx[i] = (a);
			}
		}
		var wsd0 = WaveformParser.lerp(r[0], 32768);
		var wsd1 = WaveformParser.lerp(r[1], 32768);
		tf_cache = Waveshaper.compile(wsd0, wsd1);
		_last_ws.push({in0:Reflect.copy(ws0), in1:Reflect.copy(ws1), output:tf_cache});
	}
	
	public function boxes()
	{
		return {
			env:[for (i in env) bradsr(i)],
			lfo:[for (i in lfo) brlfo(i)],
			amp_eg_type:bri(amp, "env", RangeMapping.pos(0., env.length, 1., 0)),
			amp_eg_depth:brf(amp, "env_depth", RangeMapping.pos(0., 1., 1/2, 1.)),
			amp_lfo_depth:brf(amp, "lfo_depth", RangeMapping.pos(0., 1., 1/2, 1.)),
			amp_lfo_type:bri(amp, "lfo", RangeMapping.pos(0., lfo.length, 1., 0.)),
			amp_base:brf(amp, "base", RangeMapping.pos(0., 3., 1/2, 1.)),
			amp_expression:brf(amp, "expression", RangeMapping.pos(0., 3., 1/2, 0.3)),
			cut_eg_type:bri(cutoff, "env", RangeMapping.pos(0., env.length, 1., 0)),
			cut_eg_depth:brf(cutoff, "env_depth", RangeMapping.pos(0., 22050., 1/3, 0.)),
			cut_lfo_depth:brf(cutoff, "lfo_depth", RangeMapping.pos(0., 22050., 1/3, 0.)),
			cut_lfo_type:bri(cutoff, "lfo", RangeMapping.pos(0., lfo.length, 1., 0.)),
			cut_base:brf(cutoff, "base", RangeMapping.pos(0.01, 22050., 1/3, 800.)),
			cut_keytrack:brb(cutoff, "keytrack", true),
			res_eg_type:bri(resonance, "env", RangeMapping.pos(0., env.length, 1., 0)),
			res_eg_depth:brf(resonance, "env_depth", RangeMapping.pos(0., 6., 1/2, 1.)),
			res_lfo_depth:brf(resonance, "lfo_depth", RangeMapping.neg(0., 6., 1/2, 1.)),
			res_lfo_type:bri(resonance, "lfo", RangeMapping.pos(0., lfo.length, 1., 0.)),
			res_base:brf(resonance, "base", RangeMapping.pos(0.1, 6., 1/3, 1.)),
			vib_eg_type:bri(vibrato, "env", RangeMapping.pos(0., env.length, 1., 0)),
			vib_eg_depth:brf(vibrato, "env_depth", RangeMapping.neg(-32., 32., 1/3, 1.)),
			vib_lfo_depth0:bri(vibrato, "lfo_depth0", RangeMapping.neg(-32., 32., 1., 1.)),
			vib_lfo_depth1:brf(vibrato, "lfo_depth1", RangeMapping.pos(0., 1., 1., 1.)),
			vib_lfo_type:bri(vibrato, "lfo", RangeMapping.pos(0., lfo.length, 1., 0.)),
			vib_base0:bri(vibrato, "base0", RangeMapping.neg(-32., 32., 1., 0.)),
			vib_base1:brf(vibrato, "base1", RangeMapping.pos(0., 1., 1., 0.)),
			pit_eg_type:bri(pitch, "env", RangeMapping.pos(0., env.length, 1., 0)),
			pit_eg_depth0:bri(pitch, "env_depth0", RangeMapping.neg(-32., 32., 1., 0.)),
			pit_eg_depth1:brf(pitch, "env_depth1", RangeMapping.pos(0., 1., 1., 0.)),
			pit_lfo_depth:brf(pitch, "lfo_depth", RangeMapping.neg(-16., 16., 1/3, 0.)),
			pit_lfo_type:bri(pitch, "lfo", RangeMapping.pos(0., lfo.length, 1., 0.)),
			pit_base0:bri(pitch, "base0", RangeMapping.neg(-32., 32., 1., 0.)),
			pit_base1:brf(pitch, "base1", RangeMapping.pos(0., 1., 1., 0.)),
			wav_eg_type:bri(waveshape, "env", RangeMapping.pos(0., env.length, 1., 0)),
			wav_eg_depth:brf(waveshape, "env_depth", RangeMapping.pos(0., 1., 1., 1.)),
			wav_lfo_depth:brf(waveshape, "lfo_depth", RangeMapping.pos(0., 1., 1., 1.)),
			wav_lfo_type:bri(waveshape, "lfo", RangeMapping.pos(0., lfo.length, 1., 0.)),
			wav_base:brf(waveshape, "base", RangeMapping.pos(0., 1., 1., 0.)),
			ton_eg_type:bri(tonoise, "env", RangeMapping.pos(0., env.length, 1., 0)),
			ton_eg_depth:brf(tonoise, "env_depth", RangeMapping.pos(0., 10., 1/2, 1.)),
			ton_lfo_depth:brf(tonoise, "lfo_depth", RangeMapping.pos(0., 10., 1/2, 1.)),
			ton_lfo_type:bri(tonoise, "lfo", RangeMapping.pos(0., lfo.length, 1., 0.)),
			ton_base:brf(tonoise, "base", RangeMapping.pos(0., 10., 1/2, 0.)),
			ton_interp:bri(tonoise, "interpolation", RangeMapping.pos(0., 6., 1., 0.)),
			ton_volatility:brf(tonoise, "volatility", RangeMapping.pos(0., 8., 1/4, 0.)),
			filter:bri(this, "filter_type", RangeMapping.pos(0., 3., 1., 0.)),
			oscillator:bri(this, "oscillator", RangeMapping.pos(0., 7., 1., 0.)),
			ws0:brws(ws0),
			ws1:brws(ws1)
		};
	}
	
}