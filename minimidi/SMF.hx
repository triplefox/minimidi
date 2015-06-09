package minimidi;
import flash.utils.ByteArray;
import flash.utils.Endian;
import haxe.io.BytesBuffer;
using minimidi.tools.ByteArrayTools;

class SMF
{
	
	// Things to do:
	//    Better support for signature meta events
	//    Test more obscure things like sysex and smpte
	
	public var resolution : Int;
	
	public var tracks:Array<SMFTrack>;	
	
	public static function read(bytes : ByteArray)
	{
		bytes.position = 0;
		bytes.endian = Endian.BIG_ENDIAN;
		var smf = new SMF(0, 0, 0, 0, 8192);
		var len:Int = 0;
		var format = 0;
		while (bytes.bytesAvailable >= 4) {
			var type:String = bytes.readASCII(4);
			switch(type) {
			case "MThd": // MIDI header
				var len = bytes.readUnsignedInt();
				format = bytes.readUnsignedShort(); // Type-0, Type-1, Type-2
				var num_tracks = bytes.readUnsignedShort();
				smf.resolution = bytes.readUnsignedShort();
				// resolution tells us how our delta times relate to time signature
				if ((smf.resolution & 0x800) == 0) // we're using "ticks per beat" aka "pulses per quarter note" method
				{
					//trace(resolution);
				}
				else // we're using "frames per second" method.
				{
					var fps = Math.abs(smf.resolution >> 8);
					var frame_subdivisions = smf.resolution & 0xFF;
				}
				// walk to the end of the chunk
				var cont_val = 6;
				while (cont_val < Std.int(len))
				{
					bytes.readByte();
					cont_val++;
				}
			case "MTrk": // start of track data
				len = bytes.readUnsignedInt();
				smf.tracks.push(new SMFTrack(bytes, len));
			default:
				len = bytes.readUnsignedInt();
				bytes.position += len;
			}
		}
		
		return smf;
	}
	
	public static function readVariableLength(bytes:ByteArray, ?time:Int = 0) : Int
	{
		var t : Int = bytes.readUnsignedByte();
		time += t & 0x7F;
		return (t & 0x80)>0 ? readVariableLength(bytes, time<<7) : time;
	}
	
	public function new(signature_n, signature_d, signature_sf, signature_mi, resolution)
	{
		this.resolution = resolution;
		this.tracks = new Array();
	}
	
	public static function write(record : Array<MIDIEvent>, resolution : Int)
	{
		var bbdata = new BytesBuffer();
		var bbtrack = new BytesBuffer();
		var bbsmf = new BytesBuffer();
		
		var writeInt32 = function(bb : BytesBuffer, i : Int)
		{
			bb.addByte((i >> 24) & 0xFF);
			bb.addByte((i >> 16) & 0xFF);
			bb.addByte((i >> 8) & 0xFF);
			bb.addByte((i) & 0xFF);
		}
		var writeInt16 = function(bb : BytesBuffer, i : Int)
		{
			bb.addByte((i >> 8) & 0xFF);
			bb.addByte((i) & 0xFF);
		}
		var writeChars = function(bb : BytesBuffer, s : String)
		{
			for (i in 0...s.length)
				bb.addByte(s.charCodeAt(i));
		}
		
		// track data
		// we sort the recording by tick and type in ascending order
		record.sort(function(a, b) { var t = a.tick - b.tick; if (t == 0) { t = a.bytes.type() - b.bytes.type(); } return t; } );
		var last = record[record.length-1];
		if (!last.bytes.isMeta() || (last.bytes.meta_data().type != MIDIBytes.META_TRACK_END))
			record.push(new MIDIEvent(last.tick, last.tick_delta, MIDIBytes.makeTrackEnd()));
		var tick = record[0].tick;
		for (r in record)
		{
			for (n in MIDIBytes.writeVLQ(r.tick - tick))
				bbdata.addByte(n);
			for (n in r.bytes.array())
				bbdata.addByte(n);
			tick = r.tick;
		}
		
		// track header
		{
			writeChars(bbtrack, "MTrk");
			var length = bbdata.length;
			if (bbdata.length % 2 == 1) // pad
				bbdata.addByte(0);
			var data = bbdata.getBytes();
			writeInt32(bbtrack, length);
			bbtrack.add(data);
		}
		
		// smf
		{
			writeChars(bbsmf, "MThd"); 
			writeInt32(bbsmf, 6); // size of header
			writeInt16(bbsmf, 0); // type 0
			writeInt16(bbsmf, 1); // 1 track
			writeInt16(bbsmf, resolution); // resolution
			bbsmf.add(bbtrack.getBytes());
			if (bbsmf.length % 2 == 1) // pad
				bbsmf.addByte(0);
		}
		
		return bbsmf.getBytes();
		
	}
	
}

class SMFTrack
{
	
	// we should have our data be encoded with both absolute _and_ delta times.
	
	public var track : Array<MIDIEvent>;
	public var track_text : Array<{tick:Int,delta_tick:Int,type:Int,message:String}>;
	public var tempos : Array<{tick:Int,tempo:Int,bpm:Float}>;
	public var delta_time : Int;
	public var time : Int;
	public var oldstatus : Int;
	public var status : Int;
	public var signature_n : Int;
	public var signature_d : Int;
	public var signature_sf : Int;
	public var signature_mi : Int;
	
	public function setTimeSignature(numerator : Int, denominator : Int)
	{
		signature_n = numerator;
		signature_d = denominator;
	}	
	
	public function new(bytes : ByteArray, len : Int)
	{
		
		track = new Array<MIDIEvent>();
		track_text = new Array<{tick:Int,delta_tick:Int,type:Int,message:String}>();
		tempos = new Array();
		
		delta_time = 0;
		time = 0;		
		
		oldstatus = 0;
		status = 0;

		this.signature_n = 0;
		this.signature_d = 0;
		this.signature_sf = 0;
		this.signature_mi = 0;
		
		while (bytes.bytesAvailable > 0 && readSMFTrack(bytes)) {}
		
	}

	public function readSMFTrack(bytes : ByteArray)
	{
		
		var cont = true;
		
		delta_time = SMF.readVariableLength(bytes);
		time += delta_time;
		
		// status byte reusage rules:
		// if the last status was between 0x80 and 0xEF, we
		// can reuse it when we see an upcoming data byte.
		// status bytes above 0xEF have other rules.
		
		if (status>=0x80 && status<=0xEF) // reusable
		{
			oldstatus = status;
		}
		else if (status >= 0xF0 && status <= 0xF7) // System Common Category messages - CLEAR the status.
		{
			oldstatus = 0;
		}
		// else we have a Real Time Category message, which doesn't get reused but also doesn't clear
		
		status = bytes.readUnsignedByte();
		if (status < 0x80) // we got a data byte
		{
			status = oldstatus;
			bytes.position -= 1;
		}
		
		// now we have to discern if this is a meta/sysex event or a regular track status.
		
		if (status == MIDIBytes.META)
		{
			var metaEventType:Int = bytes.readUnsignedByte();
			var len = SMF.readVariableLength(bytes);
			var mbytes : Array<Int> = [for (i in 0...len) bytes.readUnsignedByte()];
			var headerbytes = [status, metaEventType].concat(MIDIBytes.writeVLQ(len));
			trackEvent(track, delta_time, new MIDIBytes(headerbytes.concat(mbytes)));
			if ((metaEventType & 0x00f0) == 0) {
				var text = new StringBuf();
				for (i in mbytes) text.addChar(i);
				track_text.push({delta_tick:time,tick:time,message:text.toString(),type:metaEventType});
			} else {
				switch (metaEventType) {
				case MIDIBytes.META_KEY_SIGNATURE:
					this.signature_sf = mbytes[0];
					this.signature_mi = mbytes[1];
				case MIDIBytes.META_TEMPO:
					var tempo = (mbytes[0] << 16) | (mbytes[1] << 8) | (mbytes[2]);
					var bpm = 60000000 / tempo;
					this.tempos.push({ tick:time, tempo:tempo, bpm:bpm});
				case MIDIBytes.META_TIME_SIGNATURE:
					var value = (mbytes[0] << 16) | (1 << mbytes[1]);
					this.signature_n = value>>16;
					this.signature_d = value & 0xffff;
				case MIDIBytes.META_PORT:
					var value = mbytes[0];
				case MIDIBytes.META_TRACK_END:  
					cont = false;
				default:
				}
			}
		}
		else if (status == MIDIBytes.SYSTEM_EXCLUSIVE || status == MIDIBytes.END_SYSTEM_EXCLUSIVE)
		{
			// walk through sysex data
			status = 0;
			while (status != MIDIBytes.END_SYSTEM_EXCLUSIVE) { status = bytes.readUnsignedByte(); }
		}
		else
		{
			var status_base = status & 0xf0;
			switch (status_base) 
			{
				case MIDIBytes.PROGRAM_CHANGE, MIDIBytes.CHANNEL_PRESSURE:
					trackEvent(track, delta_time, new MIDIBytes([status, 
						bytes.readUnsignedByte()]));
				case MIDIBytes.NOTE_OFF, MIDIBytes.NOTE_ON, MIDIBytes.KEY_PRESSURE,
					MIDIBytes.CONTROL_CHANGE, MIDIBytes.PITCH_BEND:
					trackEvent(track, delta_time, new MIDIBytes([status, bytes.readUnsignedByte(), bytes.readUnsignedByte()]));
				default:
					var channel = status & 0x0f;
					throw "error: bad status("+Std.string(status)+") " + Std.string(status_base) +
						" on channel "+Std.string(channel)+" at byte "+Std.string(bytes.position);
			}
		
		}		
		return cont;
	}
	
	private inline function trackEvent(track : Array<MIDIEvent>, tick : Int, bytes : MIDIBytes )
		{ track.push( new MIDIEvent(time, tick, bytes)); }	
	
}