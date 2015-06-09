package minimidi.tools;
import minimidi.tools.Envelope.EnvelopeProfile;
import haxe.Serializer;
import haxe.Unserializer;

class EnvelopeSegment
{
	
	public var start:Float;
	public var end:Float;
	public var distance:Float;
	public var curvature:Float;
	public var next:EnvelopeSegment;
	public var attacks : Bool;
	public var sustains : Bool;
	public var releases : Bool;
	
	public function new(start : Float, end : Float, distance : Float, ?curvature : Float = 1.0)	
	{
		if (curvature != 1.0)
		{
			this.start = Math.pow(start, 1 / curvature); 
			this.end = Math.pow(end, 1 / curvature); 
		}
		else
		{
			this.start = start;
			this.end = end;
		}
		this.distance = distance; this.curvature = curvature; 
		next = this;
		attacks = false;  sustains = false; releases = false;
	}
	
	public inline function getLevel(pos : Float) : Float
	{
		return (end - start) * Math.pow(pos / distance, curvature) + start;
	}
	
	public function toString()
	{
		return '$start > $end over ($distance) curve ($curvature) ' +
			(attacks?"A":"")+(sustains?"S":"")+(releases?"R":"");
	}
	
}

enum EnvelopeSource
{
	Vect;
	ADSR;
	Flat;
	Instant;
}

class EnvelopeProfile
{
	
	public var src : Dynamic;
	public var src_type : EnvelopeSource;
	public var attack : EnvelopeSegment;
	public var release : EnvelopeSegment;
	public var endpoint : Float;
	
	public function new():Void { }
	
	public static var t = [0.,0.,0.,0.];
	public static var q = [0,0,0,0];
	
	public function parse(src : Dynamic, type : EnvelopeSource)
	{
		this.src = src;
		this.src_type = type;
		
		switch(src_type)
		{
			case Vect:
				var o : VectorConfig = src;
				fromVector(o.attack, o.sustain, o.release, o.endpoint);
			case ADSR:
				var o : ADSRConfig = src;
				fromDSAHDSHR(o.delay, o.start, o.attack, o.hold_atk, o.decay, o.sustain,
					o.hold_rel, o.release, o.curve_atk, o.curve_dec, o.curve_rel);
			case Flat:
				if (_flat_attack != null) _flat_attack = new EnvelopeSegment(0., 0., 1., 1.);
				attack = _flat_attack;
				release = null; endpoint = 0.; src = null;
			case Instant:
				if (_instant_attack != null) _instant_attack = new EnvelopeSegment(1., 1., 999999., 1.);
				attack = _instant_attack;
				release = _instant_attack; 
				endpoint = 1.; src = null; src_type = Instant;
		}
	}
	
	private static inline var VERSION = 1;
	
	@:keep
	function hxSerialize(s : Serializer)
	{
		s.serialize({_v:VERSION, src:src, src_type:Type.enumIndex(src_type)});
	}
	
	@:keep
	function hxUnserialize(u : Unserializer)
	{
		var o = u.unserialize();
		parse(o.src, Type.createEnumIndex(EnvelopeSource, o.src_type));
	}	
	
	private function fromVector( 
		i_attack : Array<Array<Float>>, i_sustain : Array<Array<Float>>, 
		i_release : Array<Array<Float>>, endpoint : Float)
	{
		// constructs a vector using more-or-less the exact syntax of EnvelopeSegment
		var convertVector = function(i : Array<Float>) : EnvelopeSegment
		{
			if (i.length == 3)
				return new EnvelopeSegment(i[0], i[1], i[2]);
			else
				return new EnvelopeSegment(i[0], i[1], i[2], i[3]);							
		}
		var linkVectors = function(i : Array<Array<Float>>) : Array<EnvelopeSegment>
		{
			var result = new Array<EnvelopeSegment>();
			for ( n in i )
				result.push(convertVector(n));
			if (result.length > 1)
			{
				for (r in 0...result.length - 1)
					result[r].next = result[r + 1];
			}
			return result;
		}
		
		var attack = linkVectors(i_attack);
		for (a in attack) a.attacks = true;
		var release = linkVectors(i_release);
		for (r in release) r.releases = true;
		var sustain = linkVectors(i_sustain == null ? i_release : i_sustain);		
		for (s in sustain) s.sustains = true;
		
		attack[attack.length - 1].next = sustain[0];
		sustain[sustain.length - 1].next = i_sustain == null ? null : sustain[0];
		release[release.length - 1].next = null;
		
		this.attack = attack[0]; this.release = release[0]; this.endpoint = endpoint;
	}
	
	public static inline var PEAK = 1.0;
	
	private function fromDSAHDSHR(delay_time : Float, start_level : Float,
		attack_time : Float, attack_hold_time : Float, decay_time : Float, sustain_level : Float, 
		release_hold_time : Float, release_time : Float, attack_curve : Float, decay_curve : Float,
		release_curve : Float
	)
	{
		
		var l = delay_time<=0 ? null : [start_level, start_level, delay_time, attack_curve];		
		var a = attack_time<=0 ? null : [start_level, PEAK, attack_time, attack_curve];
		var a_h = attack_hold_time<=0 ? null : [PEAK, PEAK, attack_hold_time, attack_curve];	
		var d = decay_time<=0 ? null : [PEAK, sustain_level, decay_time, decay_curve];
		var s = [sustain_level, sustain_level, 10000, decay_curve];
		var r_h = release_hold_time<=0 ? null : [PEAK, PEAK, release_hold_time, release_curve];
		var r = release_time<=0 ? null : [PEAK, 0., release_time, release_curve];
		
		var base_atk = [l, a, a_h, d];
		var base_sus = [s];
		var base_rel = [r_h, r];
		
		var atk = new Array<Array<Float>>();
		var sus = new Array<Array<Float>>();
		var rel = new Array<Array<Float>>();
		for (n in base_atk) { if (n!=null && n[2] > 0) atk.push(n); }
		for (n in base_sus) { if (n!=null && n[2] > 0) sus.push(n); }
		for (n in base_rel) { if (n!=null && n[2] > 0) rel.push(n); }
		if (atk.length == 0) atk.push([start_level,PEAK,0.,attack_curve]);
		if (rel.length == 0) rel.push([PEAK,0.,0.,release_curve]);
		if (sus.length == 0) sus = null;
		
		fromVector(atk, sus, rel, 0.);
	}
	
	private function fromADSR( 
		attack_time : Float, decay_time : Float, sustain_level : Float, release_time : Float,
		attack_curve : Float, decay_curve : Float, release_curve : Float)
	{
		fromDSAHDSHR(0., 0., attack_time, 0., decay_time, sustain_level, 0., release_time,
			attack_curve, decay_curve, release_curve);
	}
	
	private static var _flat_env : EnvelopeProfile;
	private static var _flat_attack : EnvelopeSegment;
	
	public static function flat_env() {
		if (_flat_env == null)
		{
			var e = new EnvelopeProfile();
			e.parse(null, Flat);
			_flat_env = e;
		}
		return _flat_env;
	}	
	
	private static var _instant_env : EnvelopeProfile;
	private static var _instant_attack : EnvelopeSegment;
	
	public static function instant_env() {
		if (_instant_env == null) {
			var e = new EnvelopeProfile();
			e.parse(null, Instant);
			_instant_env = e;
		}
		return _instant_env;
	}
	
	public static function stringAsDSAHDSHR(i : String, default_start : Float, default_sustain : Float,
		default_curve : Float)
	{
		
		var result : ADSRConfig = {
			delay:0., start:default_start, 
			attack:0., hold_atk:0., decay:0., sustain:default_sustain, hold_rel:0., release:0.,
			curve_atk : default_curve, curve_dec : default_curve, curve_rel : default_curve
		};
		var sp = i.split(" ");
		for (n in sp)
		{
			var pair = n.split(":");
			var val = Std.parseFloat(pair[1]);
			var key = StringTools.trim(pair[0].toLowerCase());
			switch(key)
			{
				case "delay": result.delay = val;
				case "start": result.start = val;
				case "attack": result.attack = val;
				case "hold_atk": result.hold_atk = val;
				case "decay": result.decay = val;
				case "sustain": result.sustain = val;
				case "hold_rel": result.hold_rel = val;
				case "release": result.release = val;
				case "curve_atk": result.curve_atk = val;
				case "curve_dec": result.curve_dec = val;
				case "curve_rel": result.curve_rel = val;
				default: throw "unknown key: "+key;
			}
		}
		
		return result;
		
	}
	
}

class Envelope
{
	
	// Linear segmented envelope.
	// Each segment points to another segment or "null."
	// The envelope's release is run as a secondary segment, multiplied against the main segment.
	
	public var segment : EnvelopeSegment;
	public var release : EnvelopeSegment;
	public var position : Float;
	public var release_position : Float;
	private var level : Float;
	private var release_level : Float;
	public var amplitude : Float;
	public var endpoint : Float;
	public var gain : Float;
	public var releasing : Bool;
	public var on : Bool;
	
	// note: env segments should be in the 0.0-1.0 range.
	
	public function new(segment, release, endpoint, gain)
	{
		reset(segment, release, endpoint, gain);
	}
	
	public function reset(segment, release, endpoint, gain)
	{
		this.on = gain != 0.;
		this.segment = segment;
		this.release = release;
		this.endpoint = endpoint;
		this.gain = gain;
		this.level = 0.;
		this.release_level = 0.;
		this.amplitude = 0.;
		position = 0.;
		release_position = 0.;
		releasing = false;
		update(0.);
	}
	
	public function update(amount : Float)
	{
		if (!on) return endpoint;
		
		level = endpoint;
		release_level = 0.;
		
		// calculate segment level
		
		if (segment != null)
		{
			position += amount;
			while (position >= segment.distance || segment.distance <= 0.)
			{
				position -= segment.distance;
				segment = segment.next; 
				if (segment == null) break;
			}
			if (segment != null)
				level = Math.pow(segment.getLevel(position), segment.curvature);
		}
		
		// calculate release level
		
		if (release != null)
		{
			if (!releasing)
			{
				release_level = 1.;
			}
			else
			{
				release_position += amount;
				while (release_position >= release.distance || release.distance <= 0.)
				{
					release_position -= release.distance;
					release = release.next;
					if (release == null) break;
				}
				if (release != null) 
				{
					release_level = release.getLevel(release_position);
				}
			}
		}
		
		amplitude = level * release_level * gain;
		return amplitude;
	}
	
	public inline function setRelease()
	{
		releasing = true;
	}
	
	public function setOff()
	{
		segment = null;
		release = null;
		release_level = 0.;
		releasing = false;
		level = 0.;
		amplitude = 0.;
	}
	
	public inline function attacking() { return segment!=null && segment.attacks; }
	
	public inline function sustaining() { return segment!=null && segment.sustains; }
	
	public inline function isOff() { return segment == null && endpoint==0.; }	
	
}

typedef ADSRConfig = { delay:Float, start:Float, attack:Float, hold_atk : Float, 
	decay : Float, sustain : Float, hold_rel : Float, release : Float, curve_atk : Float, curve_dec : Float,
	curve_rel : Float};
typedef VectorConfig = {
	attack : Array<Array<Float>>, sustain : Array<Array<Float>>, 
	release : Array<Array<Float>>, endpoint : Float
};
