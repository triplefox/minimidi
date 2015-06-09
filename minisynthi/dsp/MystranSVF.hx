package minisynthi.dsp ;
import haxe.ds.Vector;

class MystranSVF
{
	
	// Submitted by mystran (Teemu Voipio) 2012
	// http://www.kvraudio.com/forum/viewtopic.php?p=4913251#p4913251
	// With additions:
	// 	smooth coefficient calculation
	// 	softer saturation (using tanh)
	
	public function new(cutoff, Q, samplerate)
	{
		this.cutoff = cutoff;
		this.Q = Q;
		this.last_c = cutoff;
		this.last_q = Q;
		this.samplerate = samplerate;
		this.z01 = 0.;
		this.z02 = 0.;
		this.i0 = 0.;
		this.f = 0.;
		this.r = 0.;
		this.g = 0.;
		
		calcCoefficents(true);
	}

	public var cutoff : Float;
	public var Q : Float;
	public var samplerate : Float;
	
	public var last_c : Float;
	public var last_q : Float;
	
	public var hp : Float;
	public var bp : Float;
	public var lp : Float;
	
	private var f : Float;
	private var r : Float;
	private var g : Float;
	private var z1 : Float;
	private var z2 : Float;	
	private var z01 : Float;
	private var z02 : Float;
	private var i0 : Float;
	
	public inline function calcCoefficents(?force : Bool = false)
	{
		// update coeffs when parameters change
		
		if (this.cutoff == last_c && this.Q == last_q && !force)
			return;
		
		var c = cutoff;
		var Q = this.Q;
		if (force)
		{
			z1 = 0.;
			z2 = 0.;
			z01 = 0.;
			z02 = 0.;
			i0 = 0.;
		}
		last_c = c;
		last_q = Q;
		
		if (c < 1.)
			c = 1.;
		if (c > samplerate / 2)
			c = samplerate / 2;
		if (Q <= 0.000001) 
			Q = 0.000001;
			
		// the trig function here represents a waveshaping transfer function; tanh has a nicer soft knee.
		//f = Math.tan(Math.PI * c / samplerate);
		f = accurate_tanh(Math.PI * c / samplerate);
		r = f + 1 / Q;
		g = 1 / (f * r + 1);
		
		smoothCoefficients();
		
	}
	
	private inline function accurate_tanh(x : Float) : Float
	{
		var ex = Math.exp(2 * x);
		return (ex - 1) / (ex + 1);
	}

	private inline function smoothCoefficients()
	{		
		// anti-click: we roll back the filter one frame, run it, and average
		// the two different results to achieve a smooth transition.
		
		var zp1 = z1;
		var zp2 = z2;
		
		z1 = z01;
		z2 = z02;
		update(i0);
		
		z1 = (zp1 + z01) * 0.5;
		z2 = (zp2 + z02) * 0.5;
	}
	
	public inline function update(inp : Float)
	{
		
		// calculate outputs
		hp = (inp - r * z1 - z2) * g;
		bp = z1 + f * hp;
		lp = z2 + f * bp;

		// and update state
		z01 = z1;
		z02 = z2;		
		i0 = inp;
		
		// update and antidenormal
		z1 += 2 * f * hp + 0.0000000000001;
		z2 += 2 * f * bp - 0.0000000000001;

	}
	
	public inline function getLP(inp : Float) { update(inp); return lp; }
	public inline function getHP(inp : Float) { update(inp); return hp; }
	public inline function getBP(inp : Float) { update(inp); return bp; }
	
	// note: it's cheaper to run the getMany functions in most situations because
	// of variable locality.
	
	public inline function getManyLP(buffer : Vector<Float>, start : Int, end : Int)
	{
		for (i in start...end)
		{
			update(buffer[i]);
			buffer[i] = lp;
		}
	}	
	
	public inline function getManyHP(buffer : Vector<Float>, start : Int, end : Int)
	{
		for (i in start...end)
		{
			update(buffer[i]);
			buffer[i] = hp;
		}
	}	
	
	public inline function getManyBP(buffer : Vector<Float>, start : Int, end : Int)
	{
		for (i in start...end)
		{
			update(buffer[i]);
			buffer[i] = bp;
		}
	}	
}