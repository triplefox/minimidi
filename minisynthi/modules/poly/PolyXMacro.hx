package minisynthi.modules.poly ;
import haxe.macro.Expr;

class PolyXMacro
{
	macro public static function initEnvelope(param : Expr, envelope : Expr)
	{
		return macro
		{
			var p = $param.envelope;
			if ($envelope == null)
				$envelope = new Envelope(p.attack, p.release, p.endpoint, $param.envelope_depth);
			else
				$envelope.reset(p.attack, p.release, p.endpoint, $param.envelope_depth);
		}
	}
	
	macro public static function initLFO(param : Expr, lfo : Expr)
	{
		return macro
		{
			if ($lfo == null)
				$lfo = new LFO($param.lfo.envelope, $param.lfo.sequence.cache, 
					$param.lfo.interp, $param.lfo.frequency, $param.lfo.depth);
			else
				$lfo.reset($param.lfo.envelope, $param.lfo.sequence.cache, 
					$param.lfo.interp, $param.lfo.frequency, $param.lfo.depth);
		}
	}
}