package minimidi.modules;
import minimidi.*;
import minimidi.net.XMLClient;
import haxe.ds.Vector;

class MIDIOut implements SynthModule
{
	
	public var mixer : SynthMixer;
	public var client : XMLClient;
	
	public function processEvents(n : MIDIEvent)
	{
		client.send(n);
	}

	public function renderBuffer(buffer : Vector<Float>)
	{
	}
	
	/**
	 * A very simple module that redirects all output out towards an XMLClient connection.
	 * Note that the precision of this is limited by the audio buffer size.
	 * @param	client
	 */
	public function new(client)
	{
		this.client = client;
	}
	
}
