package minimidi.modules;
import minimidi.SynthModule;

class SineModule implements SynthModule
{
	public static inline var DC_OFFSET = 0.000020;
	
	public var mixer : SynthMixer;
	
	public function processEvents(n : MIDIEvent)
	{
		trace([n.type, n.data]);
	}
	
	public var vib_pos : Float;

	public function renderBuffer(buffer : FastFloatBuffer)
	{
		var advance = mixer.sampleAdvanceRate(440.) * Math.PI * 2;
		for (i in 0 ... mixer.monoSize()) 
		{
			var i2 = i << 1;
			var sin = DC_OFFSET + Math.sin(vib_pos);
			buffer.set(i2, sin);
			buffer.set(i2 + 1, sin);
			vib_pos += advance;
		}
	}
	
	public function new()
	{
		vib_pos = 0.;
	}
	
}
