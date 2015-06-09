package minisynthi.modules.poly.shared ;
import minimidi.MIDIBytes;
class TriggerRuleParser
{
	
	public static function parse(line : String)
	{
		var result = new Array<ITriggerRule>();
		var datas = line.split("\n");
		for (d in datas)
		{
			var words = d.split(" ");
			switch(StringTools.trim(words[0]))
			{
				case "noterange":
					try {
						var numbers = StringTools.trim(words[1]).split("-");
						result.push(new NoteRangeTrigger(Std.parseInt(numbers[0]),
							Std.parseInt(numbers[1])));
					}
					catch (d:Dynamic) { throw 'invalid noterange (e.g. "noterange 36-67")'; }
			}
		}
		return result;
	}
	
	public static function allow(bytes : MIDIBytes, rules : Array<ITriggerRule>)
	{
		for (r in rules)
		{
			if (!r.allow(bytes)) return false;
		}
		return true;
	}
	
}