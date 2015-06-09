package minisynthi.modules.poly ;

import minisynthi.modules.poly.shared.AllocatedVoice;
import minisynthi.modules.poly.shared.MIDIPolyphonic;
import minimidi.SynthModule;
import minimidi.MIDIEvent;
import minimidi.tools.Envelope;
import haxe.ds.Vector;

interface IPolyphonicModule
{
	
	public var parent : MIDIPolyphonic;
	
	public function processEvents(n : MIDIEvent) : Void;
	public function renderBuffer(b : Vector<Float>, v : AllocatedVoice) : Bool;
	public function noteOff() : Void;
	
	public var amp_envelope : Envelope;
	public var output_amplitude : Float;
	
	public function name() : String;
	public function getPart() : Dynamic;
	public function setPart(p : Dynamic) : Void;
	public function id() : Int;
	public var uid : Int;
	public var on : Float;
	
}
