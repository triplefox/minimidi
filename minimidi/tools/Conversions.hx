package minimidi.tools;

class Conversions
{

	/* attentuation here is defined as SPL, p0 = 20 μPa*/
	
	public static inline function semitonesOfCentFs(cents : Float) { return cents*0.001; }
	public static inline function pctPowerToAttenuationdB(data : Float) { return 20*(Math.log(data/20.)/Math.log(10));  }
	public static inline function attentuationCBtoPctPower(data : Float) { return Math.pow(10, CBtoDB(data)/20.);  }
	public static inline function attentuationDBtoPctPower(data : Float) { return Math.pow(10, data/20.);  }
	public static inline function DBtoCB(data : Float) { return data * 10.; }
	public static inline function CBtoDB(data : Float) { return data / 10.; }

}