package minimidi;

interface Sequencer
{
	
	public var mixer : SynthMixer;
	public var channel_offset : Int;
	
	public function request(samples : Int) : Array<MIDIEvent>;
	
}