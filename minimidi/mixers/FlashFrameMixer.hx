package minimidi.mixers;

import flash.events.Event;
import flash.utils.ByteArray;
import flash.Lib;
import minimidi.tools.SampleRate;

class FlashFrameMixer extends SynthMixer
{
	
	/**
	 * A form of "mixer" that is designed to run during Flash's per-frame update, rather than
	 * during the SampleDataEvent. This allows a smaller buffer size to be used where the goal is to
	 * direct output into XMLCLient.
	 * @param	rate
	 * @param	sequencer
	 * @param	module
	 */
	public function new(rate : SampleRate, sequencer : Array<Sequencer>, 
		module : SynthModule)
	{
		var framerate = Lib.current.stage.frameRate;
		var framesize = Std.int(rate.rate / framerate);
		if (framesize != rate.rate / framerate)
			throw 'stage framerate($framerate) should divide evenly into the samplerate(${rate.rate})';
		super(rate, sequencer, module, framesize, 1);
	}
	
	public function play()
	{
		Lib.current.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}
	
	public function stop()
	{
		Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
	}
	
	public function onEnterFrame(?ev : Event) 
	{
		
		executeFrame();
		frame++;
		
	}
	
}