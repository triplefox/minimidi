package minimidi.tools;

class SampleRate
{
	
	public var rate : Float;
	
	public inline function waveLength(frequency : Float) { return rate / frequency; }
	
	public inline function frequency(wavelength : Float) { return rate / wavelength; }
	
	public inline function waveLengthOfBentNote(tuning : MIDITuning, note : Float, pitch_bend : Int, semitones : Int) 
	{ 
		return waveLength(tuning.midiNoteBentToFrequency(note, pitch_bend, semitones));
	}
	
	public inline function waveLengthOfBentFrequency(tuning : MIDITuning,
		frequency : Float, pitch_bend : Int, semitones : Float, bend_semitones : Int) 
	{ 
		return waveLengthOfBentNote(tuning, tuning.frequencyToMidiNote(frequency)+semitones, pitch_bend, bend_semitones);
	}
	
	public function new(rate)
	{
		this.rate = rate;
	}
	
}
