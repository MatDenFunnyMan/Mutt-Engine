package funkin.graphics.shaders;

import flixel.FlxCamera;
import flixel.addons.display.FlxRuntimeShader;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.utils.Assets;
import funkin.util.Logger;

class CustomBlendShader extends FlxRuntimeShader
{
	public static final SUPPORTED:Array<BlendMode> = [
		DARKEN,
		DIFFERENCE,
		HARDLIGHT,
		INVERT,
		LIGHTEN,
		OVERLAY
	];

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
				Logger.warn('CustomBlendShader: customBlend.frag not found, falling back to the default renderer');
		}

		return _source != null && _source.length > 0;
	}

	public function new()
	{
		super(_source, null);
	}

	public function setBackground(value:BitmapData):Void
		setSampler2D('backgroundSwag', value);

	public function setSource(value:BitmapData):Void
		if (value != null) setSampler2D('spriteSwag', value);

	public function setBlend(value:BlendMode):Void
		setInt('blendMode', cast value);

	public function updateViewInfo(camera:FlxCamera):Void
	{
		setFloatArray('uViewport', [FlxG.stage.stageWidth, FlxG.stage.stageHeight]);
		setFloatArray('uCamRect', [
			camera.flashSprite.x,
			camera.flashSprite.y,
			camera.width * camera.totalScaleX,
			camera.height * camera.totalScaleY
		]);
	}
}
