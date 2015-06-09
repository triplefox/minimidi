package minisynthi.modules.poly.shared ;
import com.ludamix.icl.ICL;
import haxe.io.Bytes;
import minisynthi.modules.poly.PolyphonicSquare.SquarePatch;
import minisynthi.modules.poly.PolyX.PolyXPatch;

class TPatch
{
	
	/* low level engine voice definitions that we map to a MIDI assignment. */
	
	public var name : String;
	public var square : Array<SquarePatch>;
	public var polyx : Array<PolyXPatch>;
	
	public function new(name)
	{
		this.name = name;
		this.square = new Array();
		this.polyx = new Array();
	}
	
}