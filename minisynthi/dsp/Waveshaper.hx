package minisynthi.dsp ;
import haxe.ds.Vector;
import minimidi.tools.Envelope;

class Waveshaper
{

	public var tf1 : Vector<Float>;
	public var tf2 : Vector<Float>;
	public var tf2_delta : Vector<Float>;
	
	public function new()
	{
		
	}
	
	public static function compile(tf1 : Vector<Float>, tf2 : Vector<Float>)
	{
		if (tf1.length != tf2.length)
			throw "transfer functions must have matching length";
		
		var rtf1 = new Vector<Float>(tf1.length << 1);
		var rtf2 = new Vector<Float>(tf1.length << 1);
		
		// mirror the transfer functions for negative values
		var len = tf1.length;
		for (n in 0...len)
		{
			var rn = (len - 1) - n;
			rtf1[rn] = -tf1[n];
			rtf1[n + len] = tf1[n];
			rtf2[rn] = -tf2[n];
			rtf2[n + len] = tf2[n];
		}
		
		var tf1 = rtf1;
		var tf2 = rtf2;
		var tf2_delta = new Vector<Float>(rtf1.length);
		
		// compute a delta
		for (n in 0...rtf2.length)
		{
			tf2_delta[n] = rtf2[n] - rtf1[n];
		}
		
		return {tf1:tf1, tf2:tf2, tf2_delta:tf2_delta };
		
	}
	
	public inline function apply(buffer : Vector<Float>, start : Int, end : Int, wet_0 : Float, wet_1 : Float)
	{
		var scale = (tf1.length >> 1) - 1;
		
		if (wet_0 == 0. && wet_1 == 0.)
		{
			for (i in start...end)
			{
				var wspi = Std.int(Math.min(1., Math.max( -1., buffer[i])) * scale + scale);
				buffer[i] = tf1[wspi];
			}		
		}
		else if (wet_0 == 1. && wet_1 == 1.)
		{
			for (i in start...end)
			{
				var wspi = Std.int(Math.min(1., Math.max( -1., buffer[i])) * scale + scale);
				buffer[i] = tf2[wspi];
			}		
		}
		else
		{
			var wet_i = (wet_1 - wet_0) / (end - start);
			for (i in start...end)
			{
				var wspi = Std.int(Math.min(1., Math.max( -1., buffer[i])) * scale + scale);
				var ws1 = tf1[wspi];
				var ws2 = tf2_delta[wspi];
				buffer[i] = (ws1 + ws2 * wet_0);
				wet_0 += wet_i;
			}		
		}
		
	}
	
	
}