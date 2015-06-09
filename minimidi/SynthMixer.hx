package minimidi;

import minimidi.tools.ByteArrayTools;
import minimidi.tools.SampleRate;

import haxe.ds.Vector;

class SynthMixer
{
	
	// Combination master MIDI control and buffer mixer.
	
	public var sequencer : Array<Sequencer>;
	public var module : SynthModule;
	public var frame : Int;	
	public var buffer : Vector<Float>;
	public var rate : SampleRate;
	
	private var framesize : Int; // buffer size of one (monaural) frame request
	private var divisions : Int; // to increase the framerate we slice the buffer by this number of divisions
	
	public var onFrame : SynthMixer->Void;
	public var postFrame : SynthMixer->Void;
	
	public inline function samplerate() { return rate.rate; }
	public inline function monoSize() { return Std.int(framesize/divisions); }
	public inline function stereoSize() { return Std.int(framesize*2/divisions); }
	public inline function framerate() { return rate.rate / (framesize/divisions); }
	
	public inline function secondsToFrames(secs : Float) : Float { return secs * framerate(); }
	public inline function secondsToSamples(secs : Float) : Float { return secs * samplerate(); }
	public inline function samplesToSeconds(samples : Float) : Float { return samples / samplerate(); }
	public inline function BPMToFrames(beat : Float, bpm : Float) : Float
		{ return (beat / (bpm / 60) * framerate()); }
	public inline function BPMToSamples(beat : Float, bpm : Float) : Float
		{ return (beat / (bpm / 60) * rate.rate); }
	public inline function framesToBeats(frames : Int, bpm : Float) : Float
		{ return frames / BPMToFrames(1., bpm); }
	public inline function framesToMidiTicks(frames : Int, resolution : Int, bpm : Float) : Float
		{ return framesToBeats(frames, bpm) * resolution; }
	public inline function beatsToMidiTicks(beats : Float, resolution : Int) : Float
		{ return beats * resolution; }
	public inline function midiTicksToBeats(ticks : Int, resolution : Int) : Float
		{ return ticks / resolution; }
	public inline function beatsToSeconds(beats : Float, bpm : Float) : Float { return beats / (bpm / 60); }	
	public inline function sampleAdvanceRate(frequency : Float) : Float { return frequency / samplerate(); }
	
	public inline function executeFrame()
	{
		if (onFrame != null) onFrame(this);
		
		// ask the sequencer for some events
		
		var events = new Array<MIDIEvent>();
		for (s in sequencer)
		{
			for (e in s.request(monoSize()))
			{
				e.shadow_channel += s.channel_offset;
				events.push(e);
			}
		}
		
		for (e in events)
		{
			module.processEvents(e);	
		}
		
		module.renderBuffer(buffer);
		
		if (postFrame != null) postFrame(this);
	}
	
	public function new(rate : SampleRate, sequencer : Array<Sequencer>, 
		module : SynthModule, ?framesize : Int = 4096, ?divisions : Int = 4)
	{
		this.rate = rate;
		this.framesize = framesize;
		this.divisions = divisions;
		this.sequencer = sequencer;
		this.module = module;
		module.mixer = this;
		for (s in sequencer) s.mixer = this;
		buffer = new Vector(stereoSize());
	}
	
}
