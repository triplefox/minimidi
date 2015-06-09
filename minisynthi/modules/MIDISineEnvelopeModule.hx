package minisynthi.modules;
import haxe.ds.Vector;
import minimidi.tools.Envelope;
import minimidi.tools.MathTools;
import minimidi.MIDITuning;
import minimidi.*;

class MIDISineEnvelopeModule implements SynthModule
{
	public static inline var MIN_POWER = 0.000020;
	
	public var mixer : SynthMixer;
	
	public var amplitude : Float;
	public var amplitude_target : Float;
	public var frequency : Float;
	public var envelope : Envelope;
	public var envelope_profile : EnvelopeProfile;
	
	public var tuning : MIDITuning;
	
	public function processEvents(n : MIDIEvent)
	{
		var event_type = n.bytes.type();
		if (event_type == MIDIBytes.NOTE_ON)
		{
			frequency = tuning.midiNoteBentToFrequency(n.bytes.note(), 0);
			var p = envelope_profile;
			envelope = new Envelope(p.attack, p.release, p.endpoint);
		}
		else if (event_type == MIDIBytes.NOTE_OFF)
		{
			if (envelope != null)
				envelope.setRelease();
			else
				amplitude = 0.;
		}
	}
	
	public var vib_pos : Float;

	public function renderBuffer(buffer : Vector<Float>)
	{
		if (envelope == null)
			amplitude = 0.;
		else
		{
			var env_advance = mixer.samplesToSeconds(mixer.monoSize());
			amplitude_target = envelope.update(env_advance);
		}
		
		var advance = mixer.sampleAdvanceRate(frequency) * Math.PI * 2;
		if (amplitude_target > MIN_POWER)
		{
			// lerp into the amplitude target
			var amp_advance = (amplitude_target - amplitude) * 1. / mixer.monoSize();
			for (i in 0 ... mixer.monoSize())
			{
				var sin = Math.sin(vib_pos) * amplitude;
				var i2 = i << 1;
				buffer.set(i2, sin);
				buffer.set(i2 + 1, sin);
				vib_pos += advance;
				amplitude += amp_advance;
			}
			amplitude = amplitude_target;
		}
		else
		{
			for (i in 0 ... mixer.monoSize()) 
			{
				var i2 = i << 1;
				buffer.set(i2, 0.);
				buffer.set(i2 + 1, 0.);
				vib_pos += advance;
			}
			amplitude = amplitude_target;
		}
	}
	
	public function new()
	{
		vib_pos = 0.;
		tuning = EvenTemperament.cache;
		amplitude = 0.;
		amplitude_target = 0.;
		frequency = 440.;
		envelope_profile = Envelope.ADSR(0.03, 0.3, 0.1, 0.1, 0.3, 0.3, 0.3);
	}
	
}
