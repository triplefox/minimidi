package minisynthi.modules.poly.shared ;
import haxe.ds.Vector;
import haxe.io.Bytes;
import minimidi.tools.Envelope;
import minimidi.MIDIEvent;
import minimidi.SynthModule;
import minimidi.SynthMixer;
import minimidi.MIDIBytes;
import minisynthi.modules.poly.IPolyphonicModule;
import minisynthi.modules.poly.shared.PatchList;

class MIDIPolyphonic implements SynthModule
{
	
	public var mixer : SynthMixer;
	public var mixbuf : Vector<Float>;
	
	public var voices : Map<Int, Array<IPolyphonicModule>>;
	public var allocated_voices : Map<Int, Array<AllocatedVoice>>;
	public var channels : Array<MIDIChannelState>;
	
	public static inline var SQUARE = 123;
	public static inline var POLYX = 415;

	public function new(voices : Array<IPolyphonicModule>, default_patchlist : PatchList, ?channels = 16)
	{
		this.voices = new Map<Int, Array<IPolyphonicModule>>(); 
		this.allocated_voices = new Map<Int, Array<AllocatedVoice>>(); 
		for (v in voices) { 
			var id = v.id();
			v.parent = this; 
			
			if (this.voices.exists(id)) { 
				this.voices.get(id).push(v); 
			}
			else { this.voices.set(id, [v]); allocated_voices.set(id, []); }
		}
		this.channels = [for (c in 0...channels) (new MIDIChannelState(default_patchlist))];
	}
	
	public function processEvents(n : MIDIEvent)
	{
		//trace([for (v in voices) v.amp_envelope.releasing ? "~" : "_" ]);
		//trace([for (v in voices) v.amp_envelope.amplitude < 0.0001 ? "+" : "_" ]);
		
		var event_type = n.bytes.type();
		if (event_type == MIDIBytes.NOTE_OFF || (event_type == MIDIBytes.NOTE_ON && n.bytes.velocity() == 0))
		{
			if (channels[n.shadow_channel].sustain_pedal()) return;
			for (vgroup in allocated_voices)
			{
				for (v in vgroup)
				{
					if (
						v.shadow_channel == n.shadow_channel &&
						v.note == n.bytes.note())
						{ v.voice.processEvents(n); }
				}
			}
		}
		else if (event_type == MIDIBytes.NOTE_ON)
		{
			
			var patch = channels[n.bytes.channel()].getPatch();
			if (patch == null) patch = channels[n.bytes.channel()].getDefaultPatch();
			
			// for each module type listed in data, we prepare a set of voices.
			
			var PARTTYPES : Array<Array<Dynamic>> = [patch.square, patch.polyx];
			for (parts in PARTTYPES)
			{
				for (patchdef in parts)
				{
					var count = parts.length;
					{
						var module_id = parts[0].module();
						var unallocated = voices.get(module_id);
						if (unallocated.length < count)
						{
							var allocated = allocated_voices.get(module_id);
							var available = allocated.length + unallocated.length;
							
							if (available < count) count = available;
							while (unallocated.length < count)
							{
								// find a voice module with a matching ID number that is most available for use.
								var best_on = 9999.;
								var best : AllocatedVoice = null;
								for (v in allocated)
								{
									if (v.voice.id() == module_id && v.voice.on < best_on) // figure out which one is safest to drop
									{
										best = v; best_on = v.voice.on;
									}
								}
								if (best == null) best = allocated[0];
								allocated.remove(best);
								unallocated.push(best.voice);
							}
						}
					}
					var unallocated = voices.get(patchdef.module());
					var allocated = allocated_voices.get(patchdef.module());
					for (i in 0...count)
					{
						var mpart = parts[i];
						
						var voice = unallocated.pop();
						allocated.push( { channel:n.bytes.channel(), shadow_channel:n.shadow_channel, note:n.bytes.note(),
							velocity:n.bytes.velocity(), voice:voice});
						voice.setPart(mpart);
						voice.processEvents(n);
						
					}
				}
			}
			
		}
		else if (event_type == MIDIBytes.PITCH_BEND)
		{
			channels[n.shadow_channel].pitch_bend = n.bytes.pitch_bend();
		}
		else if (event_type == MIDIBytes.PROGRAM_CHANGE)
		{
			forceOffChannel(n.shadow_channel);
			channels[n.shadow_channel].program = n.bytes.program();
		}
		else if (event_type == MIDIBytes.CONTROL_CHANGE)
		{
			var cc : Int = n.bytes.cc_type();
			var value : Int = n.bytes.cc_value();
			var chn = channels[n.shadow_channel];
			if (cc == MIDIBytes.CC_SUSTAIN_PEDAL)
			{
				var result = (value >= 64);
				if (chn.sustain_pedal() && !result)
				{
					forceOffChannel(n.shadow_channel);
				}
				chn.cc[cc] = value;
			}
			else if (cc == MIDIBytes.CC_BANK_SELECT_MSB)
			{
				forceOffChannel(n.shadow_channel);
				chn.cc[cc] = value;
			}
			else if (cc == MIDIBytes.CC_ALL_NOTES_OFF)
			{
				for (i in 0...channels.length)
					forceOffChannel(i);
			}
			else if (cc == MIDIBytes.CC_DATA_ENTRY_MSB)
			{
				chn.cc[cc] = value;
				if (chn.cc[MIDIBytes.CC_RPN_LSB] == 0 && 
					chn.cc[MIDIBytes.CC_RPN_MSB] == 0) // set bend range
				{
					chn.bend_semitones = n.bytes.cc_value();
				}
			}
			else
			{
				chn.cc[cc] = value;
			}
		}
	}
	
	private function forceOffChannel(channel : Int)
	{
		for (vgroup in allocated_voices)
		{
			for (v in vgroup)
			{
				if ((v.voice.amp_envelope.amplitude > 0. || v.voice.amp_envelope.attacking()) && 
					v.shadow_channel == channel)
					{ v.voice.noteOff(); }
			}		
		}
	}
	
	public function renderBuffer(buffer : Vector<Float>)
	{
		// We prepare a mix buffer and reuse it for each voice - voices are responsible for clearing the buffer.
		// This is a completely monaural mix. (Stereo is kind of a big expense.)
		
		if (mixbuf == null)
			mixbuf = new Vector<Float>(mixer.buffer.length >> 1);
		else
		{
			for (i in 0 ... mixer.monoSize())
			{
				var i2 = i << 1;
				buffer[i2] = 0.;
				buffer[i2+1] = 0.;
			}
		}
		
		for (vgid in allocated_voices.keys())
		{
			var vgroup = allocated_voices.get(vgid);
			var to_push = new Array<AllocatedVoice>();
			for (v in vgroup)
			{
				if (v.voice.renderBuffer(mixbuf, v))
				{
					var output_amplitude = v.voice.output_amplitude;
					for (i in 0 ... mixer.monoSize()) 
					{
						var i2 = i << 1;
						var data = buffer.get(i2) + mixbuf.get(i) * output_amplitude;
						buffer.set(i2, data);
					}
				}
				if (v.voice.on <= 0) to_push.push(v);
			}
			for (n in to_push) { vgroup.remove(n); voices.get(vgid).push(n.voice); }
		}
		
		// fill in other channel
		for (i in 0 ... mixer.monoSize()) 
		{
			var i2 = i << 1;
			var data = buffer.get(i2);
			buffer.set(i2 + 1, data);
		}
	}
	
	public function loadPatchList(patches : PatchList, channel : Int)
	{
		channels[channel].patchlist = patches;
	}
	
	public function getPatch(channel : Int, bank : Int, program : Int)
	{
		return channels[channel].patchlist.get(bank, program);
	}
	
	public function setPatch(channel : Int, bank : Int, program : Int, patch : TPatch)
	{
		channels[channel].patchlist.set(bank, program, patch);
	}
	
}
