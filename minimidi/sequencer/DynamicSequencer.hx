package minimidi.sequencer;
import minimidi.MIDIBytes;
import minimidi.MIDIStream;
import minimidi.tools.SampleRate;
import minimidi.Sequencer;
import minimidi.SynthMixer;
import minimidi.MIDIEvent;
import minimidi.SMF;
import minimidi.tools.BPMTicker;

class DynamicSequencer implements Sequencer
{
	
	public var mixer : SynthMixer;
	public var channel_offset : Int;
	public var sample_position : Float;
	public var tick : Int;
	public var last_event_tick : Int;
	
	public var bpm : BPMTicker;	
	
	public var queue : Array<MIDIEvent>;
	public var record : Array<MIDIEvent>;
	public var ppqn : Int;
	
	public var recording : Bool;
	
	/**
	 * Sequencer that builds a dynamic, recordable event stream through external control.
	 * */	
	public function new()
	{
		channel_offset = 0;
		reset();
	}	
	
	public function request(samples : Int) : Array<MIDIEvent>
	{
		
		queue.sort(sorter);
		
		var ar = new Array<MIDIEvent>();
		
		var samples_per_tick = mixer.monoSize() / (mixer.framesToMidiTicks(1, ppqn, bpm.bpm));
		
		sample_position += samples;
		
		while (sample_position > samples_per_tick)
		{
			
			// We step one tick at a time - 
			// timing accuracy should be effectively perfect on the sequencer end of things.
			
			sample_position -= samples_per_tick;
			tick++;
			bpm.advanceTick(ppqn);
			
			var event = queue[0];
			if (event == null) continue;
			while (event.tick <= tick)
			{
				queue.shift();
				ar.push(event);
				if (event.bytes.isMeta())
				{
					var data = event.bytes.meta_data();
					if (data.type == MIDIBytes.META_TEMPO)
					{
						bpm.set(event.bytes.meta_bpm(), true);
					}
				}
				if (queue.length < 1)
					break;
				else
					event = queue[0];
			}
		}
		
		return ar;
	}
	
	public function add(e : MIDIEvent)
	{
		var snap = e.tick + tick;
		var e = new MIDIEvent(snap, e.tick_delta + tick - last_event_tick, e.bytes);
		if (recording)
			record.push(e);
		queue.push(e);
		last_event_tick = e.tick;
	}
	
	public function addBeats(e : MIDIEvent, beats : Float)
	{
		var ticks = Math.round(mixer.beatsToMidiTicks(beats, ppqn));
		add(new MIDIEvent(ticks, ticks, e.bytes));
	}
	
	public function startRecording()
	{
		recording = true;
		record = new Array();		
	}
	
	public function stopRecording()
	{
		recording = false;
	}
	
	public function beatTime()
	{
		return mixer.rate.rate / mixer.BPMToSamples(bpm.interval_length, bpm.bpm);
	}
	
	private function sorter(a : MIDIEvent, b : MIDIEvent)
	{
		return a.tick - b.tick;
	}
	
	public function clearChannel(idx : Int)
	{
		// strip everything related to the channel in the future.
		// To also turn off notes send a makeAllOff to the channel afterwards.
		var result = new Array<MIDIEvent>();
		for ( i in queue )
		{
			if (i.bytes.channel() != idx)
				result.push(i);
		}
		queue = result;
	}
	
	public function reset()
	{
		tick = 0;
		last_event_tick = 0;
		sample_position = 0.;
		ppqn = 96;
		queue = new Array();
		record = new Array();
		if (bpm !=null)
			bpm.set(120.0);
		else
			bpm = new BPMTicker(120.0);
		recording = false;
	}
	
}