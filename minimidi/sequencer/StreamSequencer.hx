package minimidi.sequencer;
import minimidi.MIDIStream;
import minimidi.tools.SampleRate;
import minimidi.Sequencer;
import minimidi.SynthMixer;
import minimidi.MIDIEvent;
import minimidi.SMF;
import minimidi.tools.BPMTicker;

class StreamSequencer implements Sequencer
{
	
	public var stream : MIDIStream;
	
	public var mixer : SynthMixer;
	public var channel_offset : Int;
	
	/**
	 * Sequencer that returns events from an MIDIStream instance.
	 * For example, an XMLClient may write bytes into a MIDIStream,
	 * and then the sequencer returns them as MIDIEvents.
	 * */	
	public function new(stream)
	{
		this.stream = stream;
		channel_offset = 0;
		tick = 0;
	}	
	
	public function request(samples : Int) : Array<MIDIEvent>
	{
		var result = new Array<MIDIEvent>();
		for (p in stream.packets)
			result.push(new MIDIEvent(0, 0, p));
		return result;
	}
	
}