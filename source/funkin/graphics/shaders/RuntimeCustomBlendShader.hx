package funkin.graphics.shaders;

import flixel.addons.display.FlxRuntimeShader;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.utils.Assets;
import funkin.util.Logger;

class RuntimeCustomBlendShader extends FlxRuntimeShader
{
	public static var available(get, never):Bool;

	static var _source:String = null;
	static var _sourceChecked:Bool = false;

	static function get_available():Bool
	{
		if (!_sourceChecked)
		{
			_sourceChecked = true;
			try
			{
				var path:String = Paths.shaderFragment('customBlend');
				if (Assets.exists(path)) _source = Assets.getText(path);
			}
			catch (e:Dynamic)
			{
				_source = null;
			}

			if (_source == null || _source.length < 1)
				Logger.warn('RuntimeCustomBlendShader: customBlend.frag not found, advanced blend modes are drawn as NORMAL');
		}

		return _source != null && _source.length > 0;
	}

	public var sourceSwag(default, set):BitmapData;

	function set_sourceSwag(value:BitmapData):BitmapData
	{
		setSampler2D('sourceSwag', value);
		return sourceSwag = value;
	}

	public var backgroundSwag(default, set):BitmapData;

	function set_backgroundSwag(value:BitmapData):BitmapData
	{
		setSampler2D('backgroundSwag', value);
		return backgroundSwag = value;
	}

	public var blendSwag(default, set):BlendMode;

	function set_blendSwag(value:BlendMode):BlendMode
	{
		setInt('blendMode', cast value);
		return blendSwag = value;
	}

	public function new()
	{
		super(_source, null);
	}
}
