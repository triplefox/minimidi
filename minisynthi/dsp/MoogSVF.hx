package minisynthi.dsp ;
import haxe.ds.Vector;

class MoogSVF
{
	
	public function new(cutoff, Q, samplerate)
	{
		this.cutoff = cutoff;
		this.Q = Q;
		this.output = 0.;
		this.samplerate = samplerate;
		this.lcutoff = -1;
		this.lQ = -1;
		this.lsamplerate = -1;
		t0 = 0.;
		t2 = 0.;
		x0 = 0.;
		f0 = 0.;
		k0 = 0.;
		p0 = 0.;
		r0 = 0.;
		y1 = 0.;
		y2 = 0.;
		y3 = 0.;
		y4 = 0.;
		ox0 = 0.;
		oy1 = 0.;
		oy2 = 0.;
		oy3 = 0.;
		oinp = 0.;
	}

	public var cutoff : Float;
	public var lcutoff : Float;
	public var Q : Float;
	public var lQ : Float;
	public var samplerate : Float;
	public var lsamplerate : Float;
	
	public var t0 : Float;
	public var t2 : Float;
	public var x0 : Float;
	public var f0 : Float;
	public var k0 : Float;
	public var p0 : Float;
	public var r0 : Float;
	public var y1 : Float;
	public var y2 : Float;
	public var y3 : Float;
	public var y4 : Float;
	public var ox0 : Float;
	public var oy1 : Float;
	public var oy2 : Float;
	public var oy3 : Float;
	public var oinp : Float;
	
	public var output : Float;
	
	public inline function calcCoefficents(?force : Bool = false)
	{
		if (cutoff < 1.0) cutoff = 1.0;
		if (Q < 0.000001) Q = 0.000001;
		if (Q > 8) Q = 8;
		if (samplerate < 1) samplerate = 1;
		
		if (cutoff != lcutoff || Q != lQ || samplerate != lsamplerate || force)
		{
			var ax0 = x0; 
			var ay1 = y1; 
			var ay2 = y2; 
			var ay3 = y3;
			var aox0 = ox0; 
			var aoy1 = oy1; 
			var aoy2 = oy2; 
			var aoy3 = oy3;
			var aoinp = oinp;
			
			f0  =  (cutoff+cutoff) / samplerate;
			p0 = f0*(1.8-0.8*f0);
			k0=2*Math.sin(f0*Math.PI/2)-1;
			t0 = (1.0-p0)*1.386249;
			t2 = 12.0+t0*t0;
			r0  =  (Q/10)*(t2+6.0*t0)/(t2-6.0*t0);
			lcutoff = cutoff;
			lQ = Q;
			lsamplerate = samplerate;
			
			// smooth the coefficients
			
			update(aoinp);
			
			x0 = (x0 + ax0) * 0.5;
			y1 = (y1 + ay1) * 0.5;
			y2 = (y2 + ay2) * 0.5;
			y3 = (y3 + ay3) * 0.5;
			ox0 = (ox0 + aox0) * 0.5;
			oy1 = (oy1 + aoy1) * 0.5;
			oy2 = (oy2 + aoy2) * 0.5;
			oy3 = (oy3 + aoy3) * 0.5;			
			oinp = aoinp;
			
		}
		
	}
	
	public inline function update(inp : Float)
	{
		
		// calculate outputs
		x0  =  inp - r0*y4;
		y1 = x0*p0 + ox0*p0 - k0*y1;
		y2 = y1*p0+oy1*p0 - k0*y2;
		y3 = y2*p0+oy2*p0 - k0*y3;
		y4 = y3*p0+oy3*p0 - k0*y4;
		y4 = y4 - ((y4 * y4 * y4) / 6.0);
		
		ox0 = x0;
		oy1 = y1+0.0000001;
		oy2 = y2-0.0000001;
		oy3 = y3+0.0000001;
		output = y4;
		
	}
	
	public inline function getLP(inp : Float) { update(inp); return output; }
	public inline function getHP(inp : Float) { update(inp); return output; }
	public inline function getBP(inp : Float) { update(inp); return 3.0 * (y3 - output); }
	
	// note: it's cheaper to run the getMany functions in most situations because
	// of variable locality.
	
	public inline function getManyLP(buffer : Vector<Float>, start : Int, end : Int)
	{
		for (i in start...end)
		{
			update(buffer[i]);
			buffer[i] = output;
		}
	}	
	
	public inline function getManyHP(buffer : Vector<Float>, start : Int, end : Int)
	{
		for (i in start...end)
		{
			update(buffer[i]);
			buffer[i] = buffer[i] - y1 - y4; // still broken
		}
	}	
	
	public inline function getManyBP(buffer : Vector<Float>, start : Int, end : Int)
	{
		for (i in start...end)
		{
			update(buffer[i]);
			buffer[i] = 3.0 * (y3 - output);
		}
	}	
}