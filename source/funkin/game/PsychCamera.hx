package funkin.game;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxShader;
import funkin.graphics.BitmapDataUtil;
import funkin.util.Logger;
import funkin.graphics.FixedBitmapData;
import funkin.graphics.shaders.CustomBlendShader;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

// PsychCamera handles followLerp based on elapsed
// and stops camera from snapping at higher framerates

class PsychCamera extends FlxCamera
{
	public static var blendShaderEnabled:Bool = true;
	public static var MAX_BLEND_LAYERS:Int = 8;

	static var _blendBroken:Bool = false;

	var _blendShaders:Array<CustomBlendShader> = [];
	var _blendCaptures:Array<FixedBitmapData> = [];
	var _blendIndex:Int = 0;
	var _capturing:Bool = false;
	var _captureWidth:Int = 0;
	var _captureHeight:Int = 0;

	inline function needsBlendShader(blend:BlendMode, shader:FlxShader):Bool
		return blendShaderEnabled && !_blendBroken && blend != null && shader == null && !_capturing
			&& CustomBlendShader.SUPPORTED.contains(blend) && CustomBlendShader.available;

	function prepareBlendShader(blend:BlendMode, ?source:BitmapData):CustomBlendShader
	{
		try
		{
			var w:Int = Std.int(width);
			var h:Int = Std.int(height);
			if (w < 1) w = 1;
			if (h < 1) h = 1;

			if (_captureWidth != w || _captureHeight != h)
			{
				for (bmp in _blendCaptures) bmp.dispose();
				_blendCaptures = [];
				_captureWidth = w;
				_captureHeight = h;
			}

			var index:Int = _blendIndex;
			if (index >= MAX_BLEND_LAYERS) index = MAX_BLEND_LAYERS - 1;
			else _blendIndex++;

			while (_blendShaders.length <= index) _blendShaders.push(new CustomBlendShader());
			while (_blendCaptures.length <= index) _blendCaptures.push(FixedBitmapData.create(w, h));

			var capture:FixedBitmapData = _blendCaptures[index];
			var shader:CustomBlendShader = _blendShaders[index];

			_capturing = true;
			BitmapDataUtil.drawCameraScreen(capture, this, true);
			_capturing = false;

			shader.setBackground(capture);
			shader.setSource(source);
			shader.setBlend(blend);
			shader.updateViewInfo(this);

			return shader;
		}
		catch (e:Dynamic)
		{
			_capturing = false;
			_blendBroken = true;
			Logger.error('PsychCamera: blend shader disabled after an error: ' + Std.string(e));
			return null;
		}
	}

	override public function render():Void
	{
		super.render();
		if (!_capturing) _blendIndex = 0;
	}

	override public function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode,
		?smoothing:Bool = false, ?shader:FlxShader):Void
	{
		if (FlxG.renderBlit || !needsBlendShader(blend, shader))
			return super.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);

		var source:BitmapData = (frame != null && frame.parent != null) ? frame.parent.bitmap : pixels;
		var blendShader:CustomBlendShader = prepareBlendShader(blend, source);
		if (blendShader == null)
			return super.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);

		super.drawPixels(frame, pixels, matrix, transform, null, smoothing, blendShader);
	}

	override public function drawTriangles(graphic:FlxGraphic, vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>,
		?colors:DrawData<Int>, ?position:FlxPoint, ?blend:BlendMode, repeat:Bool = false, smoothing:Bool = false, ?transform:ColorTransform,
		?shader:FlxShader):Void
	{
		if (FlxG.renderBlit || !needsBlendShader(blend, shader))
			return super.drawTriangles(graphic, vertices, indices, uvtData, colors, position, blend, repeat, smoothing, transform, shader);

		var blendShader:CustomBlendShader = prepareBlendShader(blend, graphic.bitmap);
		if (blendShader == null)
			return super.drawTriangles(graphic, vertices, indices, uvtData, colors, position, blend, repeat, smoothing, transform, shader);

		super.drawTriangles(graphic, vertices, indices, uvtData, colors, position, null, repeat, smoothing, transform, blendShader);
	}

	override public function destroy():Void
	{
		for (bmp in _blendCaptures) bmp.dispose();
		_blendCaptures = [];
		_blendShaders = [];
		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		// follow the target, if there is one
		if (target != null)
		{
			updateFollowDelta(elapsed);
		}

		updateScroll();
		updateFlash(elapsed);
		updateFade(elapsed);

		flashSprite.filters = filtersEnabled ? filters : null;

		updateFlashSpritePosition();
		updateShake(elapsed);
	}

	public function updateFollowDelta(?elapsed:Float = 0):Void
	{
		// Either follow the object closely,
		// or double check our deadzone and update accordingly.
		if (deadzone == null)
		{
			target.getMidpoint(_point);
			_point.addPoint(targetOffset);
			_scrollTarget.set(_point.x - width * 0.5, _point.y - height * 0.5);
		}
		else
		{
			var edge:Float;
			var targetX:Float = target.x + targetOffset.x;
			var targetY:Float = target.y + targetOffset.y;

			if (style == SCREEN_BY_SCREEN)
			{
				if (targetX >= viewRight)
				{
					_scrollTarget.x += viewWidth;
				}
				else if (targetX + target.width < viewLeft)
				{
					_scrollTarget.x -= viewWidth;
				}

				if (targetY >= viewBottom)
				{
					_scrollTarget.y += viewHeight;
				}
				else if (targetY + target.height < viewTop)
				{
					_scrollTarget.y -= viewHeight;
				}
				
				// without this we see weird behavior when switching to SCREEN_BY_SCREEN at arbitrary scroll positions
				bindScrollPos(_scrollTarget);
			}
			else
			{
				edge = targetX - deadzone.x;
				if (_scrollTarget.x > edge)
				{
					_scrollTarget.x = edge;
				}
				edge = targetX + target.width - deadzone.x - deadzone.width;
				if (_scrollTarget.x < edge)
				{
					_scrollTarget.x = edge;
				}

				edge = targetY - deadzone.y;
				if (_scrollTarget.y > edge)
				{
					_scrollTarget.y = edge;
				}
				edge = targetY + target.height - deadzone.y - deadzone.height;
				if (_scrollTarget.y < edge)
				{
					_scrollTarget.y = edge;
				}
			}

			if ((target is FlxSprite))
			{
				if (_lastTargetPosition == null)
				{
					_lastTargetPosition = FlxPoint.get(target.x, target.y); // Creates this point.
				}
				_scrollTarget.x += (target.x - _lastTargetPosition.x) * followLead.x;
				_scrollTarget.y += (target.y - _lastTargetPosition.y) * followLead.y;

				_lastTargetPosition.x = target.x;
				_lastTargetPosition.y = target.y;
			}
		}

		var mult:Float = 1 - Math.exp(-elapsed * followLerp / (1/60));
		scroll.x += (_scrollTarget.x - scroll.x) * mult;
		scroll.y += (_scrollTarget.y - scroll.y) * mult;
		//trace('lerp on this frame: $mult');
	}

	override function set_followLerp(value:Float)
	{
		return followLerp = value;
	}
}