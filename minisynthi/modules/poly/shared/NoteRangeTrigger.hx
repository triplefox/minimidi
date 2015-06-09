package minisynthi.modules.poly.shared ;
import minimidi.MIDIBytes;
import haxe.Serializer;
import haxe.Unserializer;

class NoteRangeTrigger implements ITriggerRule
{
	
	public var low : Int;
	public var hi : Int;
	
	public function new(low : Int, hi : Int)
	{
		if (low > hi)
		{
			this.low = hi;
			this.hi = low;
		}
		else
		{
			this.low = low;
			this.hi = hi;
		}
	}
	
	public function allow(bytes : MIDIBytes) : Bool
	{
		if (bytes.type() == MIDIBytes.NOTE_ON ||
			bytes.type() == MIDIBytes.NOTE_OFF)
		{
			return (bytes.note() >= low && bytes.note() <= hi);
		}
		else return true;
	}
	
	public function toString()
	{
		return 'noterange $low-$hi';
	}
	
	private static inline var VERSION = 1;
	
	@:keep
	function hxSerialize(s : Serializer)
	{
		s.serialize( { _v:VERSION, low:low, hi:hi});
	}
	
	@:keep
	function hxUnserialize(u : Unserializer)
	{
		var o = u.unserialize();
		low = o.low;
		hi = o.hi;
	}	
	
}