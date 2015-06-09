package minimidi;

class MIDIStream
{
	public var cur_packet : Array<Int>;
	public var packets : Array<MIDIBytes>;
	
	public var status : Int;
	
	/**
	 * Parses an incoming stream of integer values into packets corresponding to MIDI messages.
	 */
	public function new()
	{
		cur_packet = new Array();
		packets = new Array();
		status = 0;
	}
	
	public function write(byte : Int)
	{
		
		// status byte reusage rules:
		// if the last status was between 0x80 and 0xEF, we
		// can reuse it when we see an upcoming data byte.
		// status bytes above 0xEF have other rules.
		
		// OK, I've determined that we need to flush that packet as soon as it's valid.
		// Otherwise we are "hanging" on them.
		
		if (status == MIDIBytes.META)
		{
			// assuming a valid VLQ is available...
			// we check to see if we've reached the indicated number of bytes.
			push(byte);
			try
			{
				var vlq = new MIDIBytes(cur_packet).readVLQ(1);
				if (cur_packet.length - vlq.i == vlq.value)
				{
					status = 0;
				}
			}
			catch(d:Dynamic) {}
		}
		else if (byte < 0x80) // data byte
		{
			push(byte);
			if (status != MIDIBytes.SYSTEM_EXCLUSIVE)
			{
				if (status >= 0xC0 && status < 0xE0 && cur_packet.length == 2) flushPacket();
				else if (cur_packet.length == 3) flushPacket();
			}
		}
		else if (byte>=0x80 && byte<=0xEF) // new status
		{
			flushPacket();
			status = byte;
			push(byte);
		}
		else if (byte >= MIDIBytes.SYSTEM_EXCLUSIVE && byte <= MIDIBytes.END_SYSTEM_EXCLUSIVE) // Sysex messages.
		{
			if (byte == MIDIBytes.SYSTEM_EXCLUSIVE)
			{
				flushPacket();
				push(byte);
				status = MIDIBytes.SYSTEM_EXCLUSIVE;
			}
			else
			{
				push(byte);
				status = 0;
				if (byte == MIDIBytes.END_SYSTEM_EXCLUSIVE)
				{
					flushPacket();
				}
			}
		}
		else // a Real Time Category message, which gets immediately turned into a packet
		{
			packets.push(new MIDIBytes([byte]));
		}
		
	}
	
	private function flushPacket()
	{
		if (cur_packet.length > 0)		
		{
			packets.push(new MIDIBytes(cur_packet));
			cur_packet = new Array();
		}
	}
	
	private inline function push(byte : Int)
	{
		cur_packet.push(byte);
	}
	
}