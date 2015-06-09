package minisynthi.modules.poly ;

import com.ludamix.icl.ICL;
import minimidi.tools.Conversions;
import minisynthi.modules.poly.shared.*;
import minimidi.SynthModule;
import minimidi.MIDIEvent;
import minimidi.MIDITuning;
import minimidi.MIDIBytes;
import haxe.ds.Vector;
import minimidi.tools.Envelope;

class PolyphonicSquare implements IPolyphonicModule
{
	
	public static inline var MIN_POWER = 0.000020;
	
	public var parent : MIDIPolyphonic;
	public var amplitude : Float;
	public var amplitude_target : Float;
	public var frequency : Float;
	public var amp_envelope : Envelope;
	public var amp_envelope_profile : EnvelopeProfile;
	
	public var vib_pos : Float;
	public var patch : SquarePatch;
	
	public var tuning : MIDITuning;
	
	public var on : Float;
	private var samples_played : Float;
	
	public var last_note_event : { channel:Int, shadow_channel : Int, note:Int, velocity:Int };
	
	public var output_amplitude : Float;
	
	public var uid : Int;
	
	public function processEvents(n : MIDIEvent)
	{
		var mb = n.bytes;
		if (mb.type() == MIDIBytes.NOTE_OFF || mb.type() == MIDIBytes.NOTE_ON && mb.velocity() == 0)
		{
			on = 0.;
			noteOff();
			last_note_event = { channel:mb.channel(), shadow_channel:n.shadow_channel, 
				note:mb.note(), velocity:mb.velocity() };
		}
		else if (mb.type() == MIDIBytes.NOTE_ON)
		{
			on = 1.;
			samples_played = 0.;
			var p = amp_envelope_profile;
			amp_envelope = new Envelope(p.attack, p.release, p.endpoint, mb.velocity() / 128);
			last_note_event = { channel:mb.channel(), shadow_channel:n.shadow_channel,
				note:mb.note(), velocity:mb.velocity() };
		}
	}
	
	public function renderBuffer(buffer : Vector<Float>, note_event : AllocatedVoice)
	{
		if (note_event == null || note_event.shadow_channel == -1) return false;
		
		var channel = parent.channels[last_note_event.shadow_channel];
		
		var amplitude_modifier = (channel.volume() / 127) * (channel.expression() / 127);
		frequency = tuning.midiNoteBentToFrequency(last_note_event.note, channel.pitch_bend - 0x2000, channel.bend_semitones);
		
		var env_advance = parent.mixer.samplesToSeconds(parent.mixer.monoSize());
		amplitude_target = amp_envelope.update(env_advance) * amplitude_modifier;
		
		var advance = parent.mixer.sampleAdvanceRate(frequency);
		if (amplitude_target > MIN_POWER)
		{
			// lerp into the amplitude target
			var amp_advance = (amplitude_target - amplitude) * 1. / parent.mixer.monoSize();
			for (i in 0 ... buffer.length)
			{
				buffer.set(i, ((vib_pos % 1.0) > 0.5 ? 1.0 : 0.0) * amplitude);
				vib_pos += advance;
				amplitude += amp_advance;
			}
			amplitude = amplitude_target;
			setOnValue(buffer.length);
			return true;
		}
		else
		{
			for (i in 0 ... buffer.length) 
			{
				vib_pos += advance;
			}
			amplitude = amplitude_target;
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
	
	public function new(uid)
	{
		this.uid = uid;
		output_amplitude = 0.1;
		samples_played = 0.;
		on = 0.;
		vib_pos = 0.;
		tuning = EvenTemperament.cache;
		amplitude = 0.;
		amplitude_target = 0.;
		frequency = 440.;
		var p = new EnvelopeProfile(); p.parse({attack:0.03, decay:0.1, sustain:0.4, release:0.3, curve_atk:0.3, curve_dec:0.3, curve_rel:0.3}, ADSR);
		amp_envelope_profile = p;
		amp_envelope = new Envelope(null, null, amp_envelope_profile.endpoint, 1.0);
	}
	
	public function noteOff()
	{
		if (amp_envelope != null)
			amp_envelope.setRelease();
		else
			amplitude = 0.;		
	}
	
	public function name() { return "PolyphonicSquare"; }
	
	public static function header() : ModuleHeaderType
	{
		return {
			name:"PolyphonicSquare", read:function(d:Dynamic) { return new SquarePatch(); }
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
	
	public function id()
	{
		return MIDIPolyphonic.SQUARE;
	}
	
}

class SquarePatch
{
	
	public var amp_envelope : EnvelopeProfile;
	
	public function new():Void 
	{
		var p = new EnvelopeProfile(); p.parse({attack:0.03, decay:0.3, sustain:0.4, release:0.5, curve_atk:0.2, curve_dec:3., curve_rel:3.},ADSR);
		amp_envelope = p;
	}
	
	public function toString() { return Std.string(amp_envelope); }
	
	public function module()
	{
		return MIDIPolyphonic.SQUARE;
	}
	
}