package minimidi;

abstract MIDIBytes(Array<Int>)
{

	// MIDI Message Codes
	public static inline var NOTE_OFF = 0x80;
	public static inline var NOTE_ON = 0x90;
	public static inline var KEY_PRESSURE = 0xa0;
	public static inline var CONTROL_CHANGE = 0xb0;
	public static inline var PROGRAM_CHANGE = 0xc0;
	public static inline var CHANNEL_PRESSURE = 0xd0;
	public static inline var PITCH_BEND = 0xe0;
	public static inline var SYSTEM_EXCLUSIVE = 0xf0;
	public static inline var END_SYSTEM_EXCLUSIVE = 0xf7;
	public static inline var META = 0xff;
	
	// Meta Codes
	public static inline var META_SEQNUM = 0x00;
	public static inline var META_TEXT = 0x01;
	public static inline var META_AUTHOR = 0x02;
	public static inline var META_TITLE = 0x03;
	public static inline var META_INSTRUMENT = 0x04;
	public static inline var META_LYRICS = 0x05;
	public static inline var META_MARKER = 0x06;
	public static inline var META_CUE = 0x07;
	public static inline var META_PROGRAM_NAME = 0x08;
	public static inline var META_DEVICE_NAME = 0x09;
	public static inline var META_CHANNEL = 0x20;
	public static inline var META_PORT = 0x21;
	public static inline var META_TRACK_END = 0x2f;
	public static inline var META_TEMPO = 0x51;
	public static inline var META_SMPTE_OFFSET = 0x54;
	public static inline var META_TIME_SIGNATURE = 0x58;
	public static inline var META_KEY_SIGNATURE = 0x59;
	public static inline var META_SEQUENCER_SPEC = 0x7f;

	// General MIDI Control Changes
	public static inline var CC_BANK_SELECT_MSB = 0;
	public static inline var CC_BANK_SELECT_LSB = 32;
	public static inline var CC_MODULATION = 1;
	public static inline var CC_PORTAMENTO_TIME = 5;
	public static inline var CC_DATA_ENTRY_MSB = 6;
	public static inline var CC_DATA_ENTRY_LSB = 38;
	public static inline var CC_VOLUME = 7;
	public static inline var CC_BALANCE = 8;
	public static inline var CC_PAN = 10;
	public static inline var CC_EXPRESSION = 11;
	public static inline var CC_SUSTAIN_PEDAL = 64;
	public static inline var CC_PORTAMENTO = 65;
	public static inline var CC_SOSTENUTO_PEDAL = 66;
	public static inline var CC_SOFT_PEDAL = 67;
	public static inline var CC_RESONANCE = 71;
	public static inline var CC_RELEASE_TIME = 72;
	public static inline var CC_ATTACK_TIME = 73;
	public static inline var CC_CUTOFF_FREQ = 74;
	public static inline var CC_DECAY_TIME = 75;
	public static inline var CC_PORTAMENTO_CONTROL = 84;
	public static inline var CC_REVERB_SEND = 91;
	public static inline var CC_CHORUS_SEND = 93;
	public static inline var CC_DELAY_SEND = 94;
	public static inline var CC_NRPN_LSB = 98;
	public static inline var CC_NRPN_MSB = 99;
	public static inline var CC_RPN_LSB = 100;
	public static inline var CC_RPN_MSB = 101;	
	public static inline var CC_ALL_SOUND_OFF = 120;
	public static inline var CC_ALL_CONTROLLERS_OFF = 121;
	public static inline var CC_LOCAL_KEYBOARD_OFF = 122;
	public static inline var CC_ALL_NOTES_OFF = 123;
	public static inline var CC_OMNI_MODE_OFF = 124;
	public static inline var CC_OMNI_MODE_ON = 125;
	public static inline var CC_MONO_MODE_ON = 126;
	public static inline var CC_POLY_MODE_ON = 127;
	
	public static inline var RPN_PITCHBEND_SENCE = 0;
	public static inline var RPN_FINE_TUNE = 1;
	public static inline var RPN_COARSE_TUNE = 2;
	
	public function new(bytes : Array<Int>)
	{
		this = bytes;
	}
	
	public inline function array() : Array<Int> { return this; }
	
	private static inline function shortMSB(short : Int) { return short >> 8; }	
	private static inline function shortLSB(short : Int) { return short & 0xFF; }
	private static inline function makeShort(msb : Int, lsb : Int) { return (msb << 8) | lsb; }
	
	public inline function length24(i : Int)
	{
		return (this[i] << 16) | makeShort(this[i+1], this[i+2]);
	}
	
	public inline function length14(i : Int)
	{
		return this[i] | (this[i+1] << 7);
	}
	
	public inline function readVLQ(?i : Int = 0, ?value:Int = 0) : {i:Int, value:Int}
	{
		var t : Int = this[i];
		i++;
		value += t & 0x7F;
		while (t & 0x80 > 0)
		{
			value <<= 7;
			t = this[i];
			i++;
			value += t & 0x7F;
		}
		return {i:i, value:value};
	}
	
	public static inline function writeVLQ(value:Int) : Array<Int>
	{
		var result = new Array<Int>();
		while (value > 127)
		{
			result.insert(0, value & 127);
			value >>= 7;
		}
		result.insert(0, value);
		for (n in 0...result.length - 1) 
			result[n] |= 128;
		return result;
	}
	
	// Returns the 4-bit event type, where events exist between 0x8 and 0xF.
	public inline function type()
	{
		return this[0] & 0xF0;
	}
	
	// Returns the 4-bit channel number.
	public inline function channel()
	{
		return this[0] & 0x0F;
	}
	
	// note number of note events: 0x8n 0x9n 0xAn
	public inline function note() { return this[1]; }
	// velocity of note events: 0x8n 0x9n 0xAn
	public inline function velocity() { return this[2]; }
	
	// controller of event 0xBn
	public inline function cc_type() { return this[1]; }
	// value of event 0xBn
	public inline function cc_value() { return this[2]; }
	
	// value of program event 0xCn
	public inline function program() { return this[1]; }
	
	// value of channel pressure event 0xDn
	public inline function channel_pressure() { return this[1]; }
	
	// value of pitch bend event 0xEn
	public inline function pitch_bend() { return length14(1); }
	
	// for sysex messages 0xFn; this gives us the raw bytes of the message.
	public inline function sysex_data() { var vlq = readVLQ(1); return this.slice(vlq.i); }
	
	// FF - All meta commands
	public inline function isMeta() { return this[0] == 0xFF; }
	// This gives us the raw bytes and the meta message type.
	// Meta 7F - Sequencer Specific Event (arbitrary bytes data)
	public inline function meta_data() { var vlq = readVLQ(2); return { type:this[1], data:this.slice(vlq.i) }; }
	
	// Meta 00 - Sequence Number
	public inline function sequence_number() 
	{ var meta = meta_data(); return makeShort(meta.data[0], meta.data[1]); }
	
	// Meta 01 - Text
	// Meta 02 - Copyright
	// Meta 03 - Sequence / Track Name
	// Meta 04 - Instrument Name
	// Meta 05 - Lyric
	// Meta 06 - Marker
	// Meta 07 - Cue Point
	// Meta 08 - Program Name
	// Meta 09 - Device Name
	public inline function meta_text()
	{
		var result = "";
		var meta = meta_data();
		for (i in 0...meta.data.length)
		{
			result += String.fromCharCode(meta.data[i]);
		}
		return result;
	}
	
	// Meta 20 - MIDI Channel Prefix
	// Meta 21 - MIDI Port
	// Meta 2F - End of track(should = 0)
	
	// Meta 51 - Tempo
	public inline function meta_tempo() { return length24(3); }
	public inline function meta_bpm() { return 60000000 / meta_tempo(); }
	
	// Meta 54 - SMPTE Offset
	public inline function meta_smpte_offset()
	{
		return {hours:this[3], minutes:this[4], seconds:this[5], fps:this[6], centi_fps:this[7]};
	}
	
	// Meta 58 - Time Signature
	public inline function meta_time_signature()
	{
		return {numerator:this[3], denominator:this[4], clocks:this[5], n32nds_per_quarter:this[6]};
	}
	
	// Meta 59 - Key Signature
	// First is # of flats or sharps (-1 = 1 flat, 0 = key of C, 1 = 1 sharp), second is major(0) or minor(1)
	public inline function meta_key_signature()
	{
		return {flats_sharps:this[3], major_minor:this[4]};
	}
	
	public static inline function makeNoteOn(channel : Int, note : Int, velocity : Int)
	{
		return new MIDIBytes([channel + 0x90, note, velocity]);
	}
	
	public static inline function makeNoteOff(channel : Int, note : Int, velocity : Int)
	{
		return new MIDIBytes([channel + 0x80, note, velocity]);
	}
	
	public static inline function makeAllOff(channel : Int)
	{
		// This does a "soft off" for the channel, sending an off for all 128 notes.
		// Although the "all off" CC exists, it is poorly specified.
		return [for (i in 0...128) makeNoteOff(channel, i, 0)];
	}
	
	public static inline function makeProgramChange(channel : Int, program : Int)
	{
		return new MIDIBytes([channel + 0xC0, program]);
	}
	
	public static inline function makeBankChange(channel : Int, bank : Int)
	{
		return new MIDIBytes([channel + 0xB0, 0, bank]);
	}
	
	public static inline function makeTempoChange(bpm : Float)
	{
		var inv = Std.int(60000000 / bpm);
		return new MIDIBytes([0xFF, 0x51, 0x03, (inv >> 16) & 0xFF, (inv >> 8) & 0xFF, inv & 0xFF]);
	}
	
	public static inline function makeTrackEnd()
	{
		return new MIDIBytes([0xFF, 0x2F, 0x00]);
	}
	
}