package funkin.util;

#if lime
import lime.graphics.opengl.GL;
#end

class GLInfo
{
	public static var checked:Bool = false;
	public static var advancedBlend:Bool = false;
	public static var coherentBlend:Bool = false;
	public static var extensions:Array<String> = [];

	public static function check():Void
	{
		if(checked) return;
		checked = true;

		#if lime
		try
		{
			var list:Array<String> = GL.getSupportedExtensions();
			if(list != null) extensions = list;
		}
		catch(e:Dynamic)
		{
			Logger.warn('GLInfo: could not read the extension list');
			return;
		}

		for(name in extensions)
		{
			if(name == null) continue;

			if(name.indexOf('blend_equation_advanced') > -1)
			{
				advancedBlend = true;
				if(name.indexOf('coherent') > -1) coherentBlend = true;
			}
		}
		#end
	}

	public static function dump():Void
	{
		check();

		Logger.notice('GLInfo: ${extensions.length} extensions reported');
		Logger.notice('GLInfo: blend_equation_advanced = $advancedBlend');
		Logger.notice('GLInfo: blend_equation_advanced_coherent = $coherentBlend');

		for(name in extensions)
			if(name != null && name.indexOf('blend') > -1) Logger.notice('GLInfo: found $name');
	}
}
