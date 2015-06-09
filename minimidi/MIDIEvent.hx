package minimidi;

class MIDIEvent
{
	
	public var tick : Int;
	public var tick_delta : Int;
	public var shadow_channel : Int; // mixer-redirected channel #
	public var bytes : MIDIBytes;
	
	public function new(tick, tick_delta, bytes : MIDIBytes)
	{
		this.tick = tick;
		this.tick_delta = tick_delta;
		this.shadow_channel = bytes.channel();
		this.bytes = bytes;
	}
	
	public function copy()
	{
		var e = new MIDIEvent(this.tick, this.tick_delta,
			new MIDIBytes(this.bytes.array().copy()));
		e.shadow_channel = this.shadow_channel;
		return e;
	}
	
	public function toString()
	{
		return 'tick: $tick delta: $tick_delta shadow: $shadow_channel bytes:$bytes';
	}
	
}
