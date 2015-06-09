package minisynthi.modules.poly.shared ;
import minimidi.MIDIBytes;

interface ITriggerRule
{
	
	public function allow(bytes : MIDIBytes) : Bool;
	public function toString() : String;
	
}