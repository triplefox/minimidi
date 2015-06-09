package minisynthi.modules;
import minimidi.MIDITuning;
import minimidi.SynthModule;
import minimidi.SynthMixer;
import minimidi.MIDIEvent;
import minimidi.MIDIBytes;
import haxe.ds.Vector;

class MIDISineModule implements SynthModule
{
	public var mixer : SynthMixer;
	
	public var on : Bool;
	public var frequency : Float;
	
	public var tuning : MIDITuning;
	
	public function processEvents(n : MIDIEvent)
	{
		var event_type = n.bytes.type();
		if (event_type == MIDIBytes.NOTE_ON)
		{
			frequency = tuning.midiNoteBentToFrequency(n.bytes.note(), 0);
			on = true;
		}
		else if (event_type == MIDIBytes.NOTE_OFF)
		{
			on = false;
		}
	}
	
	public var vib_pos : Float;

	public function renderBuffer(buffer : Vector<Float>)
	{
		var advance = mixer.sampleAdvanceRate(frequency) * Math.PI * 2;
		if (on)
		{
			for (i in 0 ... mixer.monoSize()) 
			{
				var sin = Math.sin(vib_pos);
				var i2 = i << 1;
				buffer.set(i2, sin);
				buffer.set(i2 + 1, sin);
				vib_pos += advance;
			}
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
		}
	}
	
	public function new()
	{
		vib_pos = 0.;
		tuning = EvenTemperament.cache;
		on = false;
		frequency = 440.;
	}
	
}
