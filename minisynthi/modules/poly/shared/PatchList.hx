package minisynthi.modules.poly.shared ;
import com.ludamix.icl.ICL;
import haxe.io.BufferInput;
import haxe.io.Bytes;
import haxe.Serializer;
import haxe.Unserializer;
import minisynthi.modules.poly.PolyX;
import minisynthi.modules.poly.PolyphonicSquare;
import haxe.crypto.Crc32;

class PatchList
{
	
	public var patches : Map < Int, Map < Int, TPatch >> ;
	public var headertypes : Array<ModuleHeaderType>;
	
	public function new(headers : Array<ModuleHeaderType>) 
	{ 
		patches = new Map(); 
		this.headertypes = headers;
	}
	
	public function get(bank : Int, program : Int) : TPatch
	{
		if (patches.exists(bank))
		{
			var bk = patches.get(bank);
			if (bk.exists(program)) return bk.get(program);
		}
		return null;
	}
	
	public function set(bank : Int, program : Int, patch : TPatch)
	{
		if (!patches.exists(bank))
			patches.set(bank, new Map<Int, TPatch>());
		var bk = patches.get(bank);
		bk.set(program, patch);
	}
	
}