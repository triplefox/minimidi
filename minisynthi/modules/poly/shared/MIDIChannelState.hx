package minisynthi.modules.poly.shared ;
import minimidi.MIDIBytes;

class MIDIChannelState
{
	
	public var program : Int;
	public var pitch_bend : Int;
	public var bend_semitones : Int;
	
	public var cc : Array<Int>;
	
	public var patchlist : PatchList;
	
	public function new(patchlist : PatchList)
	{
		program = 0;
		cc = [for (n in 0...128) 0];
		pitch_bend = 0x2000;
		bend_semitones = 2;
		cc[MIDIBytes.CC_VOLUME] = 127;
		cc[MIDIBytes.CC_EXPRESSION] = 127;
		cc[MIDIBytes.CC_PAN] = 63;
		cc[MIDIBytes.CC_BALANCE] = 63;
		this.patchlist = patchlist;
	}
	
	public inline function getPatch()
	{
		return patchlist.get(cc[MIDIBytes.CC_BANK_SELECT_MSB], program);
	}
	
	public inline function getDefaultPatch()
	{
		while (patchlist.get(cc[MIDIBytes.CC_BANK_SELECT_MSB], program) == null)
		{
			if (program <= 0)
			{
				program = 128;
				cc[MIDIBytes.CC_BANK_SELECT_MSB]--;
				if (cc[MIDIBytes.CC_BANK_SELECT_MSB] < 0)
					throw "no default patch";
			}
			else
				program--;
		}
		return patchlist.get(cc[MIDIBytes.CC_BANK_SELECT_MSB], program);
	}
	
	public inline function sustain_pedal() : Bool
	{
		return cc[MIDIBytes.CC_SUSTAIN_PEDAL] >= 64;
	}
	
	public inline function volume()
	{
		return cc[MIDIBytes.CC_VOLUME];
	}
	
	public inline function expression()
	{
		return cc[MIDIBytes.CC_EXPRESSION];
	}
	
}
