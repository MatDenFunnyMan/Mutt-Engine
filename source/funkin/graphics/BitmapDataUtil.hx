package funkin.graphics;

import flixel.FlxCamera;
import flixel.math.FlxMatrix;
import openfl.display.BitmapData;
import openfl.display.OpenGLRenderer;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.Lib;

@:access(openfl.display.BitmapData)
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display3D.Context3D)
@:access(openfl.display.OpenGLRenderer)
@:access(flixel.FlxCamera)
@:access(openfl.display.Sprite)
@:access(openfl.geom.ColorTransform)
class BitmapDataUtil
{
	static var renderer(get, never):OpenGLRenderer;
	static var _renderer:OpenGLRenderer;

	static inline function get_renderer():OpenGLRenderer
	{
		if (_renderer == null)
		{
			_renderer = new OpenGLRenderer(FlxG.stage.context3D);
			_renderer.__worldTransform = new Matrix();
			_renderer.__worldColorTransform = new ColorTransform();
		}

		return _renderer;
	}

	public static function drawCameraScreens(bitmap:BitmapData, cameras:Array<FlxCamera>):BitmapData
	{
		bitmap.__fillRect(bitmap.rect, 0, true);

		for (camera in cameras)
			drawCameraScreen(bitmap, camera, false, camera.filters != null && camera.filters.length > 0);

		return bitmap;
	}

	public static function drawCameraScreen(bitmap:BitmapData, camera:FlxCamera, clearBitmap:Bool = true, drawFlashSprite:Bool = false):BitmapData
	{
		var matrix:FlxMatrix = new FlxMatrix();
		var pivotX:Float = FlxG.scaleMode.scale.x;
		var pivotY:Float = FlxG.scaleMode.scale.y;

		matrix.setTo(1 / pivotX, 0, 0, 1 / pivotY, camera.flashSprite.x / pivotX, camera.flashSprite.y / pivotY);

		if (clearBitmap) bitmap.__fillRect(bitmap.rect, 0, true);

		camera.render();
		camera.flashSprite.__update(false, true);

		renderer.__cleanup();

		renderer.setShader(renderer.__defaultShader);
		renderer.__allowSmoothing = false;
		renderer.__pixelRatio = Lib.current.stage.window.scale;
		renderer.__worldAlpha = 1 / camera.flashSprite.__worldAlpha;
		renderer.__worldTransform.copyFrom(camera.flashSprite.__renderTransform);
		renderer.__worldTransform.invert();
		renderer.__worldTransform.concat(matrix);
		renderer.__worldColorTransform.__copyFrom(camera.flashSprite.__worldColorTransform);
		renderer.__worldColorTransform.__invert();
		renderer.__setRenderTarget(bitmap);

		if (drawFlashSprite) bitmap.__drawGL(camera.flashSprite, renderer);
		else bitmap.__drawGL(camera.canvas, renderer);

		return bitmap;
	}
}
