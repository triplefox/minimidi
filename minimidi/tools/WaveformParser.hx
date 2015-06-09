package minimidi.tools;
import haxe.ds.Vector;

class WaveformParser
{
	
	public static function parse(e : String)
	{
		// parses strings of format "<level> <level> <level>...",
		// returns a Vector<Float> containing an linearly interpolated form of the string,
		// stretched to the indicated number of samples.
		
		var sverts = e.split(" ");
		var verts = new Array<Float>();
		for (e in sverts)
		{
			verts.push(Std.parseFloat(StringTools.trim(e)));
		}
		
		return verts;
	}	
	
	public static function lerp(verts : Vector<Float>, len : Int)
	{
		if ((len << 1) >> 1 != len) throw "waveform length is not a power of two";
		
		var result = new Vector<Float>(len);
		
		var lt = len - 1;
		var pos = 0.;
		var inc = 1 / lt * (verts.length - 1);
		for (n in 0...lt)
		{
			var pint = Std.int(pos);
			var wb1 = verts[pint];
			var wb2 = verts[pint + 1];
			result[n] = (wb1 + (wb2 - wb1) * (pos - pint));
			pos += inc;
		}
		result[len - 1] = verts[verts.length - 1];
		
		return result;		
	}
	
}