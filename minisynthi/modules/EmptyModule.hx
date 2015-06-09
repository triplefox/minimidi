package minisynthi.modules;

import minimidi.SynthModule;
import minimidi.SynthMixer;
import minimidi.MIDIEvent;
import minimidi.MIDIBytes;
import haxe.ds.Vector;

class EmptyModule implements SynthModule
{
	public static inline var DC_OFFSET = 0.000020;
	
	public var mixer : SynthMixer;
	
	public function processEvents(n : MIDIEvent)
	{
		trace([n.bytes.type(), n.bytes]);
	}

	public function renderBuffer(buffer : Vector<Float>)
	{
		// clear
		for (i in 0 ... mixer.monoSize()) 
		{
			var i2 = i << 1;
			buffer.set(i2, DC_OFFSET);
			buffer.set(i2+1, DC_OFFSET);
		}
	}
	
	public function new()
	{
		
	}
	
}

