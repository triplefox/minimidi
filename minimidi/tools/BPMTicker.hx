package minimidi.tools;
import minimidi.SynthMixer;
import minimidi.tools.BPMTicker;

class BPMTicker
{
	
	
	public var bpm : Float;
	public var fractional_beat : Float;
	public var cur_beat : Float;
	
	public var onInterval : BPMTicker->Void;
	public var interval_length : Float;
	
	public function set(bpm : Float, ?preserve_beats = false)
	{
		this.bpm = bpm;
		if (!preserve_beats)
		{
			this.fractional_beat = 0.;
			this.cur_beat = 0.;
		}
	}
	
	public function advanceTick(resolution : Int)
	{
		fractional_beat += 1 / resolution;
		while (fractional_beat > interval_length)
		{
			fractional_beat -= interval_length; cur_beat += interval_length; 
			if (onInterval != null) onInterval(this);
		}
	}
	
	public function new(bpm : Float)
	{
		this.interval_length = 1.0;
		set(bpm);
	}
	
}