package minimidi.mixers;


import flash.media.Sound;
import flash.media.SoundChannel;
import flash.events.SampleDataEvent;
import flash.utils.ByteArray;
import flash.Lib;
import minimidi.tools.Conversions;

import minimidi.tools.SampleRate;

class FlashSynthMixer extends SynthMixer
{
	
	public var sound : Sound;
	public var channel : SoundChannel;
	
	public var rms_db : Float;
	
	public function new(rate : SampleRate, sequencer : Array<Sequencer>, 
		module : SynthModule, ?framesize : Int = 4096, ?divisions : Int = 8)
	{
		super(rate, sequencer, module, framesize, divisions);
		rms_db = 0.;
        sound = new Sound();
		sound.addEventListener(SampleDataEvent.SAMPLE_DATA, onSamples);
	}
	
	public function play() : SoundChannel
	{ 
		// if you get "invalid parameters" you may have made your frames too large relative to the samplerate.
		channel = sound.play(); 
		return channel;
	}
	
	public function stop() { if (channel != null) channel.stop(); }
	
	public function onSamples(event : SampleDataEvent) 
	{
		
		var time = Lib.getTimer();
		
		rms_db = 0.;
		for (count in 0...divisions)
		{
			
			executeFrame();
			
			// vector -> bytearray
			
			{
				for (i in 0 ... monoSize()) 
				{
					var i2 = i << 1;
					event.data.writeFloat(buffer[i2]);					
					event.data.writeFloat(buffer[i2 + 1]);
					rms_db += (buffer[i2]*buffer[i2]) + (buffer[i2 + 1]*buffer[i2 + 1]);
				}
			}
			
			frame++;
		}
		rms_db = Conversions.pctPowerToAttenuationdB(Math.sqrt((rms_db/2) / (divisions * monoSize())));
		
	}
	
}