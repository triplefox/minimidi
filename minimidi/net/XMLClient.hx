package minimidi.net;

import flash.events.DataEvent;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.net.XMLSocket;
import minimidi.MIDIBytes;
import minimidi.MIDIEvent;

class XMLClient
{
	
	public var cnx : XMLSocket;
	
	public function new()
	{
	}
	
	public function connect(?host : String = "localhost", ?port : Int = 41500)
	{
		if (cnx != null) disconnect();
		cnx = new XMLSocket(host, port);
		cnx.timeout = 100000000;
		cnx.addEventListener(Event.CONNECT, onConnect);
		cnx.addEventListener(DataEvent.DATA, onData);
		cnx.addEventListener(Event.CLOSE, onClose);
		cnx.addEventListener(IOErrorEvent.IO_ERROR, ioError);
		cnx.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityError);
		cnx.addEventListener(Event.ACTIVATE, onActivate);
		cnx.addEventListener(Event.DEACTIVATE, onDeactivate);
	}
	
	public function disconnect():Void 
	{
		try {
			cnx.removeEventListener(Event.CONNECT, onConnect);
			cnx.removeEventListener(DataEvent.DATA, onData);
			cnx.removeEventListener(Event.CLOSE, onClose);
			cnx.removeEventListener(IOErrorEvent.IO_ERROR, ioError);
			cnx.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityError);
			cnx.removeEventListener(Event.ACTIVATE, onActivate);
			cnx.removeEventListener(Event.DEACTIVATE, onDeactivate);
		}
		catch(d: Dynamic) {}
	}
	
	public function send(event : MIDIEvent)
	{
		cnx.send(event.bytes.array().toString()+':'+Std.string(event.tick_delta));
	}
	
	public function onConnect(ce : Event)
	{
		trace("connected");
	}
	
	public function onData(de : DataEvent)
	{
		trace(de.data);
		//send(new MIDIEvent(0, 0, new MIDIBytes([for (n in de.data.split(",")) Std.parseInt(n)])));
	}
	
	public function ioError(ie : IOErrorEvent)
	{
		trace(ie.text);
	}
	
	public function securityError(se : SecurityErrorEvent)
	{
		trace(se.text);
	}
	
	public function onActivate(ev : Event)
	{
		//trace(ev.toString());
	}
	
	public function onDeactivate(ev : Event)
	{
		//trace(ev.toString());
	}
	
	public function onClose(ce : Event)
	{
		trace("XMLSocket closed");
	}
	
}