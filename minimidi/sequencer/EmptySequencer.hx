package minimidi.sequencer;
import minimidi.tools.SampleRate;
import minimidi.Sequencer;
import minimidi.SynthMixer;
import minimidi.MIDIEvent;

class EmptySequencer implements Sequencer
{
	
	public var mixer : SynthMixer;
	public var channel_offset : Int;
	
	public function new()
	{
		channel_offset = 0;
	}	
	
	public function request(samples : Int) : Array<MIDIEvent>
	{
		return [];
	}
	
}