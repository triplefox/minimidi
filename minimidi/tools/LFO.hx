package minimidi.tools;

import haxe.ds.Vector;
import minimidi.tools.Envelope.EnvelopeProfile;

class LFO
{
	
	public var envelope : Envelope;
	public var amplitude : Float;
	public var amplitude_target : Float;
	public var frequency : Float;	
	public var pos : Float;	
	public var sequence : Vector<Float>;
	public var lerp_sequence : Bool;
	public var gain : Float;
	public var on : Bool;
	
	public function new(envelope_profile : EnvelopeProfile, sequence, lerp_sequence, frequency, gain : Float)
	{
		envelope = new Envelope(envelope_profile.attack, envelope_profile.release, envelope_profile.endpoint, 1.0);
		reset(envelope_profile, sequence, lerp_sequence, frequency, gain);
	}
	
	public function reset(envelope_profile, sequence, lerp_sequence, frequency, gain)
	{
		this.on = gain != 0.;
		envelope.reset(envelope_profile.attack, envelope_profile.release, envelope_profile.endpoint, 1.0);
		amplitude = 0.;
		amplitude_target = 0.;
		this.frequency = frequency;
		pos = 0.;
		this.sequence = sequence;
		this.lerp_sequence = lerp_sequence;
		this.gain = gain;
		update(0., 0.);
	}
	
	public function update(advance_seconds : Float, frequency_adjust : Float)
	{
		if (gain == 0.) return;
		amplitude = amplitude_target;
		amplitude_target = envelope.update(advance_seconds) * sequence[Std.int(pos * sequence.length)] * gain;
		if (!lerp_sequence)
			amplitude = amplitude_target;
		
		pos += advance_seconds * Math.max(0., (frequency + frequency_adjust));
		pos = pos % 1.;
	}	
	
}
