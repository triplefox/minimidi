package minimidi.sequencer;
import minimidi.MIDIBytes;
import minimidi.tools.SampleRate;
import minimidi.Sequencer;
import minimidi.SynthMixer;
import minimidi.MIDIEvent;
import minimidi.tools.BPMTicker;

class SimpleSequencer implements Sequencer
{
	
	public var mixer : SynthMixer;
	public var sample_position : Float;
	public var position : Int;
	public var notes : Array<Int>;
	public var last_note : Int;
	public var channel_offset : Int;
	
	public var chord : Array<Int>;
	
	public var bpm : BPMTicker;
	
	/**
	 * Sequencer that plays a repeating pattern with notes of exactly one half beat length.
	 * */
	public function new()
	{
		channel_offset = 0;
		sample_position = 0;
		position = 0;
		notes = [69, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72];
		chord = [0, 5, 10];
		last_note = 0;
		bpm = new BPMTicker(120.0);
	}	
	
	public function request(samples : Int) : Array<MIDIEvent>
	{
		var ar = new Array<MIDIEvent>();
		
		var samples_per_beat = mixer.BPMToSamples(1., bpm.bpm) * 0.5;
		
		var position_max = notes.length << 1;
		position = position % position_max; // in case notes data changes
		
		sample_position += samples;
		while (sample_position > samples_per_beat)
		{
			sample_position -= samples_per_beat;
			if (position == (position >> 1) << 1)
			{
				last_note = notes[position >> 1];
				if (last_note >= 0)
				{
					for (c in chord)
						ar.push(new MIDIEvent(0, 0, new MIDIBytes([MIDIBytes.NOTE_ON, last_note+c, 127])));
				}
			}
			else
			{
				for (c in chord)
					ar.push(new MIDIEvent(0, 0, new MIDIBytes([MIDIBytes.NOTE_OFF, last_note+c, 127])));
			}
			position = (position + 1) % position_max;
		}
		
		bpm.advanceFrame(mixer);
		
		return ar;
	}
	
}