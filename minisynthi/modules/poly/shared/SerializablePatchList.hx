package minisynthi.modules.poly.shared;

import minisynthi.modules.poly.shared.PatchList;
import minisynthi.modules.poly.shared.TPatch;
import minisynthi.modules.poly.PolyX;

class SerializablePatchList
{
	
	/* PatchList is a low-level container for voices. We don't ordinarily serialize it. 
	 * 
	 * Instead we act upon a SerializablePatchList and then compile from that.
	 * 
	 * 
	 * */
	
	public var patches : Map < Int, Map < Int, {name:String, parts:Array<Dynamic>} >> ;
	
	public function new()
	{
		patches = new Map();
	}
	
	public function set(bank : Int, program : Int, patch : {name:String, parts: Array<Dynamic>})
	{
		if (!patches.exists(bank))
			patches.set(bank, new Map<Int, {name:String, parts:Array<Dynamic>}>());
		var bk = patches.get(bank);
		bk.set(program, patch);
	}
	
	public function compileAll(pl : PatchList)
	{
		for (b in patches.keys())
		{
			for (p in patches.get(b).keys())
			{
				compile(b, p, pl);
			}
		}
	}
	
	public function compile(bank : Int, program : Int, pl : PatchList)
	{
		if (patches.exists(bank))
		{
			var b = patches.get(bank);
			if (b.exists(program))
			{
				var p = b.get(program);
				var rp = new TPatch(p.name);
				for (v in p.parts)
				{
					switch(v.id)
					{
						case "PolyXHLPart":
							var pt = new PolyXHLPart();
							pt.unserialize(v);
							rp.polyx.push(PolyXPatch.compile(pt));
					}
				}
				pl.set(bank, program, rp);
			}
		}
	}
	
	public function serialize()
	{
		var result = new Array<{bank:Int,patch:Int,name:String,parts:Array<Dynamic>}>();
		for (bkid in patches.keys())
		{
			var bank = patches.get(bkid);
			for (phid in bank.keys())
			{
				var prgm = bank.get(phid);
				result.push({bank:bkid,patch:phid,name:prgm.name,parts:prgm.parts});
			}
		}
		return result;
	}
	
	public static function fromSerialized(src : Array<{bank:Int,patch:Int,name:String,parts:Array<Dynamic>}>)
	{
		var spl = new SerializablePatchList();
		for (n in src) spl.set(n.bank, n.patch, { name:n.name, parts:n.parts } );
		return spl;
	}
	
}