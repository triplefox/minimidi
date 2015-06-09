package minimidi;

import haxe.ds.Vector;

interface SynthModule
{
	
	public var mixer : SynthMixer;
	
	public function processEvents(n : MIDIEvent) : Void;
	public function renderBuffer(b : Vector<Float>) : Void;
	
}
