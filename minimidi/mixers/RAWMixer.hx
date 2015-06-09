package minimidi.mixers;

import flash.media.Sound;
import flash.media.SoundChannel;
import flash.events.SampleDataEvent;
import flash.utils.ByteArray;
import flash.Lib;
import flash.Vector;

import minimidi.tools.SampleRate;

class RAWMixer extends SynthMixer
{
	
	public function new(rate : SampleRate, sequencer : Array<Sequencer>, 
		module : SynthModule, ?framesize=4096, ?divisions=16)
	{
		super(rate, sequencer, module, framesize, divisions);
	}
	
	public function run(secs_duration : Float)
	{
		var output = new Vector<Float>();
		while (samplesToSeconds(output.length) < secs_duration)
		{
			for (count in 0...divisions)
			{
				
				executeFrame();
				
				// vector -> bytearray
				
				{
					for (i in 0 ... monoSize()) 
					{
						var i2 = i << 1;
						output.push(buffer.get(i2));
						output.push(buffer.get(i2+1));
					}
				}
				
				frame++;
			}		
		}
		return output;
	}
	
}