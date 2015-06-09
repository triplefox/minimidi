package minimidi.sequencer;
import minimidi.tools.SampleRate;
import minimidi.Sequencer;
import minimidi.SynthMixer;
import minimidi.MIDIEvent;
import minimidi.SMF;
import minimidi.tools.BPMTicker;

class SMFSequencer implements Sequencer
{
	
	private var smf : SMF;
	private var trackptr : Array<Int>;
	private var track_length_ticks : Int;
	private var tempos : Map<Int, {bpm:Float,tempo:Int,tick:Int}>;
	
	public var bpm : BPMTicker;	
	
	public var mixer : SynthMixer;
	public var sample_position : Float;
	public var tick : Int;
	public var channel_offset : Int;
	
	public var lockbpm : Bool;
	public var forced_bpm : Float;
	public var smf_bpm : Float;
	public var bpm_multiplier : Float;	
	public var loop : Bool;
	public var usebpm : Float;
	
	public var onSongEnd : SMFSequencer->Void;
	
	/**
	 * Sequencer that loads an SMF sequence and plays it back. 
	 * */
	
	public function new()
	{
		sample_position = 0;
		tick = 0;
		channel_offset = 0;
		bpm = new BPMTicker(120.0);
		track_length_ticks = 0;
		trackptr = new Array();
		tempos = new Map();
		lockbpm = false;
		smf_bpm = 120.;
		usebpm = 120.;
		smf = new SMF(0, 0, 0, 0, 0);
		bpm_multiplier = 1.;
	}	
	
	public function load(smf : SMF)
	{
		this.smf = smf;
		trackptr = new Array();
		track_length_ticks = 0;
		tempos = new Map();
	
		for (t in smf.tracks)
		{
			track_length_ticks = Std.int(Math.max(track_length_ticks, t.time));
			trackptr.push(0);
			for (tempo in t.tempos)
				tempos.set(tempo.tick, tempo);
		}
		
		smf_bpm = 120.;
		if (tempos.exists(0))
			smf_bpm = tempos.get(0).bpm;
		
		sample_position = 0;
		tick = 0;
	}
	
	public inline function length()
	{
		return track_length_ticks;
	}
	
	public function updateBPM()
	{
		usebpm = smf_bpm * bpm_multiplier;
		if (lockbpm)
			usebpm = forced_bpm;
		bpm.set(usebpm, true);
		
		return mixer.monoSize() / (mixer.framesToMidiTicks(1, smf.resolution, bpm.bpm));
	}
	
	public function request(samples : Int) : Array<MIDIEvent>
	{
		var ar = new Array<MIDIEvent>();
		
		var samples_per_tick = updateBPM();
		
		sample_position += samples;
		
		while (sample_position > samples_per_tick)
		{
			
			// We step one tick at a time - 
			// timing accuracy should be effectively perfect on the sequencer end of things.
			
			sample_position -= samples_per_tick;
			tick++;	
			bpm.advanceTick(smf.resolution);
			
			var tchange = tempos.get(tick);
			if (tchange != null)
			{
				smf_bpm = tchange.bpm;
				samples_per_tick = updateBPM();
			}
			
			for (t in 0...smf.tracks.length)
			{
				var trackdata = smf.tracks[t].track;
				if (trackptr[t] < trackdata.length)
				{
					var event = trackdata[trackptr[t]];
					while (event.tick <= tick)
					{
						trackptr[t]++;
						ar.push(event);
						if (trackptr[t] >= trackdata.length)
							break;
						else
							event = smf.tracks[t].track[trackptr[t]];
					}
				}
			}			
		}
		
		if (tick > length())
		{
			if (loop) load(this.smf);
			if (onSongEnd != null) onSongEnd(this);
		}

		return ar;
	}
	
	public function beatTime()
	{
		return mixer.rate.rate / mixer.BPMToSamples(bpm.interval_length, usebpm);
	}
	
}