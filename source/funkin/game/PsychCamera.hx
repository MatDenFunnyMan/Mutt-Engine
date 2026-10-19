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
import funkin.graphics.shaders.RuntimeCustomBlendShader;
import animate.internal.RenderTexture;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import flixel.tweens.FlxEase.EaseFunction;

// PsychCamera handles followLerp based on elapsed
// and stops camera from snapping at higher framerates

@:access(openfl.display.DisplayObject)
@:access(openfl.geom.ColorTransform)
class PsychCamera extends FlxCamera
{
	public static var blendShaderEnabled:Bool = true;

	public static final SHADER_BLEND_MODES:Array<BlendMode> = [
		DARKEN,
		HARDLIGHT,
		LIGHTEN,
		OVERLAY,
		DIFFERENCE,
		INVERT,
		SUBTRACT,
		COLORDODGE,
		COLORBURN,
		SOFTLIGHT,
		EXCLUSION,
		HUE,
		SATURATION,
		COLOR,
		LUMINOSITY
	];

	static var _blendBroken:Bool = false;

	public var crossCameraBlending:Bool = false;

	var _blendShader:RuntimeCustomBlendShader;
	var _blendRenderTexture:RenderTexture;
	var _backgroundRenderTexture:RenderTexture;
	var _cameraTexture:FixedBitmapData;
	var _cameraTextureWidth:Int = 0;
	var _cameraTextureHeight:Int = 0;
	var _cameraMatrix:FlxMatrix = new FlxMatrix();
	var _blendMatrix:FlxMatrix = new FlxMatrix();
	var _blendVertices:DrawData<Float> = new DrawData<Float>();
	var _capturing:Bool = false;

	public var viewAngle:Float = 0;

	var _rotating:Bool = false;
	var _rotCos:Float = 1;
	var _rotSin:Float = 0;
	var _rotMatrix:FlxMatrix = new FlxMatrix();
	var _rotVertices:DrawData<Float> = new DrawData<Float>();
	var _rotPosition:FlxPoint = FlxPoint.get();
	var _marginsExpanded:Bool = false;
	var _savedMarginX:Float = 0;
	var _savedMarginY:Float = 0;

	public static function setRotation(camera:FlxCamera, angle:Float):Void
	{
		if (camera == null) return;
		if (camera is PsychCamera) cast(camera, PsychCamera).viewAngle = angle;
		else camera.angle = angle;
	}

	public static function getRotation(camera:FlxCamera):Float
	{
		if (camera == null) return 0;
		return (camera is PsychCamera) ? cast(camera, PsychCamera).viewAngle : camera.angle;
	}

	public static function tweenRotation(camera:FlxCamera, angle:Float, duration:Float, ?ease:EaseFunction, ?onComplete:FlxTween->Void):FlxTween
	{
		if (camera == null) return null;
		var values:Dynamic = (camera is PsychCamera) ? {viewAngle: angle} : {angle: angle};
		return FlxTween.tween(camera, values, duration, {ease: ease, onComplete: onComplete});
	}

	function beginRotationFrame():Void
	{
		restoreMargins();
		_rotating = !FlxG.renderBlit && viewAngle % 360 != 0;
		if (!_rotating) return;

		var radians:Float = viewAngle * Math.PI / 180;
		_rotCos = Math.cos(radians);
		_rotSin = Math.sin(radians);

		var halfWidth:Float = (width - viewMarginX * 2) * 0.5;
		var halfHeight:Float = (height - viewMarginY * 2) * 0.5;
		var absCos:Float = Math.abs(_rotCos);
		var absSin:Float = Math.abs(_rotSin);

		_savedMarginX = viewMarginX;
		_savedMarginY = viewMarginY;
		_marginsExpanded = true;
		viewMarginX = width * 0.5 - (absCos * halfWidth + absSin * halfHeight);
		viewMarginY = height * 0.5 - (absSin * halfWidth + absCos * halfHeight);
	}

	function restoreMargins():Void
	{
		if (!_marginsExpanded) return;
		viewMarginX = _savedMarginX;
		viewMarginY = _savedMarginY;
		_marginsExpanded = false;
	}

	function rotateMatrix(matrix:FlxMatrix):FlxMatrix
	{
		var centerX:Float = width * 0.5;
		var centerY:Float = height * 0.5;
		_rotMatrix.copyFrom(matrix);
		_rotMatrix.translate(-centerX, -centerY);
		_rotMatrix.rotateWithTrig(_rotCos, _rotSin);
		_rotMatrix.translate(centerX, centerY);
		return _rotMatrix;
	}

	override function clearDrawStack():Void
	{
		super.clearDrawStack();
		if (!_capturing) beginRotationFrame();
	}

	inline function needsBlendShader(blend:BlendMode):Bool
		return blendShaderEnabled && !_blendBroken && !_capturing && blend != null && !FlxG.renderBlit
			&& SHADER_BLEND_MODES.contains(blend) && RuntimeCustomBlendShader.available;

	function prepareBlendTextures():Void
	{
		var w:Int = Std.int(Math.max(1, width));
		var h:Int = Std.int(Math.max(1, height));

		if (_blendShader == null) _blendShader = new RuntimeCustomBlendShader();
		if (_blendRenderTexture == null) _blendRenderTexture = new RenderTexture(w, h);
		if (_backgroundRenderTexture == null) _backgroundRenderTexture = new RenderTexture(w, h);
		if (_cameraTexture == null || _cameraTextureWidth != w || _cameraTextureHeight != h)
		{
			if (_cameraTexture != null) _cameraTexture.dispose();
			_cameraTexture = FixedBitmapData.create(w, h);
			_cameraTextureWidth = w;
			_cameraTextureHeight = h;
		}
	}

	function captureBackground():Void
	{
		_capturing = true;
		if (crossCameraBlending)
		{
			var index:Int = FlxG.cameras.list.indexOf(this);
			var below:Array<FlxCamera> = [for (i in 0...(index + 1)) FlxG.cameras.list[i]];
			if (index < 0) below = [this];
			BitmapDataUtil.drawCameraScreens(_cameraTexture, below);
			for (camera in below)
			{
				camera.clearDrawStack();
				camera.canvas.graphics.clear();
			}
		}
		else
		{
			BitmapDataUtil.drawCameraScreen(_cameraTexture, this);
			clearDrawStack();
			canvas.graphics.clear();
		}
		_capturing = false;
	}

	function drawBlended(blend:BlendMode, smoothing:Bool, drawSource:FlxCamera->Void):Bool
	{
		try
		{
			prepareBlendTextures();
			captureBackground();

			var w:Int = Std.int(Math.max(1, width));
			var h:Int = Std.int(Math.max(1, height));

			_blendRenderTexture.init(w, h);
			_blendRenderTexture.antialiasing = smoothing;
			_blendRenderTexture.drawToCamera((camera, _) -> drawSource(camera));
			_blendRenderTexture.render();

			var sourceFrame:FlxFrame = _blendRenderTexture.graphic.imageFrame.frame;
			_blendShader.sourceSwag = _blendRenderTexture.graphic.bitmap;
			_blendShader.backgroundSwag = _cameraTexture;
			_blendShader.blendSwag = blend;

			var clampedScale:Float = Math.max(1, Lib.current.stage.window.scale);
			var colorTransform:ColorTransform = canvas.transform.colorTransform;
			_backgroundRenderTexture.init(Std.int(w * clampedScale), Std.int(h * clampedScale));
			_backgroundRenderTexture.drawToCamera((camera, matrix) ->
			{
				camera.zoom = zoom;
				matrix.scale(clampedScale, clampedScale);
				camera.drawPixels(sourceFrame, null, matrix, colorTransform, null, false, _blendShader);
			});
			_backgroundRenderTexture.render();

			_cameraMatrix.identity();
			_cameraMatrix.scale(1 / (scaleX * clampedScale), 1 / (scaleY * clampedScale));
			_cameraMatrix.translate((width - width / scaleX) * 0.5, (height - height / scaleY) * 0.5);
			super.drawPixels(_backgroundRenderTexture.graphic.imageFrame.frame, null, _cameraMatrix, null, null, smoothing, null);
			return true;
		}
		catch (e:Dynamic)
		{
			_capturing = false;
			_blendBroken = true;
			Logger.error('PsychCamera: advanced blend modes disabled after an error: ' + Std.string(e));
			return false;
		}
	}

	function cameraScaledMatrix(matrix:FlxMatrix):FlxMatrix
	{
		var pivotX:Float = width / 2;
		var pivotY:Float = height / 2;
		_blendMatrix.copyFrom(matrix);
		_blendMatrix.translate(-pivotX, -pivotY);
		_blendMatrix.scale(scaleX, scaleY);
		_blendMatrix.translate(pivotX, pivotY);
		return _blendMatrix;
	}

	function cameraScaledVertices(vertices:DrawData<Float>, ?position:FlxPoint):DrawData<Float>
	{
		var offsetX:Float = (position != null) ? position.x : 0;
		var offsetY:Float = (position != null) ? position.y : 0;
		var pivotX:Float = width / 2;
		var pivotY:Float = height / 2;

		_blendVertices.length = vertices.length;
		var i:Int = 0;
		while (i < vertices.length - 1)
		{
			_blendVertices[i] = (vertices[i] + offsetX - pivotX) * scaleX + pivotX;
			_blendVertices[i + 1] = (vertices[i + 1] + offsetY - pivotY) * scaleY + pivotY;
			i += 2;
		}
		return _blendVertices;
	}

	override public function render():Void
	{
		super.render();
		if (!_capturing) restoreMargins();
	}

	override public function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode,
		?smoothing:Bool = false, ?shader:FlxShader):Void
	{
		if (_rotating) matrix = rotateMatrix(matrix);
		drawPixelsWithBlend(frame, pixels, matrix, transform, blend, smoothing, shader);
	}

	override public function copyPixels(?frame:FlxFrame, ?pixels:BitmapData, ?sourceRect:Rectangle, destPoint:Point, ?transform:ColorTransform,
		?blend:BlendMode, ?smoothing:Bool = false, ?shader:FlxShader):Void
	{
		if ((!_rotating && !needsBlendShader(blend)) || frame == null)
			return super.copyPixels(frame, pixels, sourceRect, destPoint, transform, blend, smoothing, shader);

		if (!_rotating)
		{
			_rotMatrix.identity();
			_rotMatrix.translate(destPoint.x + frame.offset.x, destPoint.y + frame.offset.y);
			return drawPixelsWithBlend(frame, pixels, _rotMatrix, transform, blend, smoothing, shader);
		}

		_rotMatrix.identity();
		_rotMatrix.translate(destPoint.x + frame.offset.x, destPoint.y + frame.offset.y);
		drawPixelsWithBlend(frame, pixels, rotateMatrix(_rotMatrix), transform, blend, smoothing, shader);
	}

	function drawPixelsWithBlend(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode,
		?smoothing:Bool = false, ?shader:FlxShader):Void
	{
		if (frame == null || !needsBlendShader(blend))
			return super.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);

		var scaled:FlxMatrix = cameraScaledMatrix(matrix);
		if (!drawBlended(blend, smoothing, (camera) -> camera.drawPixels(frame, pixels, scaled, transform, null, smoothing, shader)))
			super.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);
	}

	override public function drawTriangles(graphic:FlxGraphic, vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>,
		?colors:DrawData<Int>, ?position:FlxPoint, ?blend:BlendMode, repeat:Bool = false, smoothing:Bool = false, ?transform:ColorTransform,
		?shader:FlxShader):Void
	{
		if (_rotating)
		{
			vertices = rotateVertices(vertices, position);
			position = _rotPosition.set(0, 0);
		}

		if (!needsBlendShader(blend))
			return super.drawTriangles(graphic, vertices, indices, uvtData, colors, position, blend, repeat, smoothing, transform, shader);

		var scaled:DrawData<Float> = cameraScaledVertices(vertices, position);
		if (!drawBlended(blend, smoothing, (camera) -> camera.drawTriangles(graphic, scaled, indices, uvtData, colors, null, null, repeat, smoothing, transform, shader)))
			super.drawTriangles(graphic, vertices, indices, uvtData, colors, position, blend, repeat, smoothing, transform, shader);
	}

	function rotateVertices(vertices:DrawData<Float>, ?position:FlxPoint):DrawData<Float>
	{
		var offsetX:Float = (position != null) ? position.x : 0;
		var offsetY:Float = (position != null) ? position.y : 0;
		var centerX:Float = width * 0.5;
		var centerY:Float = height * 0.5;

		_rotVertices.length = vertices.length;
		var i:Int = 0;
		while (i < vertices.length - 1)
		{
			var x:Float = vertices[i] + offsetX - centerX;
			var y:Float = vertices[i + 1] + offsetY - centerY;
			_rotVertices[i] = x * _rotCos - y * _rotSin + centerX;
			_rotVertices[i + 1] = x * _rotSin + y * _rotCos + centerY;
			i += 2;
		}
		return _rotVertices;
	}

	override public function destroy():Void
	{
		restoreMargins();
		_rotPosition.put();
		if (_blendRenderTexture != null) _blendRenderTexture.destroy();
		if (_backgroundRenderTexture != null) _backgroundRenderTexture.destroy();
		if (_cameraTexture != null) _cameraTexture.dispose();
		_blendRenderTexture = null;
		_backgroundRenderTexture = null;
		_cameraTexture = null;
		_blendShader = null;
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