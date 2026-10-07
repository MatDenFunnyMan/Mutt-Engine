package funkin.audio;

import flixel.system.ui.FlxSoundTray;
import openfl.display.Bitmap;
import openfl.utils.Assets;
import openfl.display.BitmapData;

class FunkinSoundTray extends FlxSoundTray
{
	var graphicScale:Float = 0.30;
	var lerpYPos:Float = 0;
	var alphaTarget:Float = 0;

	var volumeMaxSound:String;
	var _lastMod:String = '';

	public static inline final MIN_VOLUME:Float = 0.001;
	public static inline final VOLUME_STEPS:Int = 10;
	public static var volumeLevel:Int = VOLUME_STEPS;

	public static function levelToVolume(level:Int):Float
	{
		if(level <= 0) return 0;
		if(level >= VOLUME_STEPS) return 1;
		return Math.exp(Math.log(MIN_VOLUME) * (1 - level / VOLUME_STEPS));
	}

	public static function volumeToLevel(volume:Float):Int
	{
		if(volume <= 0) return 0;
		var linear:Float = 1 - Math.log(Math.max(volume, MIN_VOLUME)) / Math.log(MIN_VOLUME);
		return Std.int(FlxMath.bound(Math.round(linear * VOLUME_STEPS), 0, VOLUME_STEPS));
	}

	public static function syncVolume()
	{
		volumeLevel = volumeToLevel(FlxG.sound.volume);
		FlxG.sound.volume = levelToVolume(volumeLevel);
	}

	public function new()
	{
		super();
		_buildGraphics();
		trace("Custom sound tray initialized!");
	}

	function _getImageData(file:String):BitmapData
	{
		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders('images/soundtray/' + file + '.png');
		if (sys.FileSystem.exists(modPath))
			return BitmapData.fromFile(modPath);
		#end
		return Assets.getBitmapData(Paths.getPath('images/soundtray/' + file + '.png', IMAGE));
	}

	function _getSoundPath(file:String):String
	{
		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders('sounds/soundtray/' + file + '.ogg');
		if (sys.FileSystem.exists(modPath))
			return modPath;
		#end
		return Paths.getPath('sounds/soundtray/' + file + '.ogg', SOUND);
	}

	function _buildGraphics()
	{
		removeChildren();

		var bg:Bitmap = new Bitmap(_getImageData('volumebox'));
		bg.scaleX = graphicScale;
		bg.scaleY = graphicScale;
		bg.smoothing = ClientPrefs.data.antialiasing;
		addChild(bg);

		y = -height;
		visible = false;

		var backingBar:Bitmap = new Bitmap(_getImageData('bars_10'));
		backingBar.x = 9;
		backingBar.y = 5;
		backingBar.scaleX = graphicScale;
		backingBar.scaleY = graphicScale;
		backingBar.smoothing = ClientPrefs.data.antialiasing;
		addChild(backingBar);
		backingBar.alpha = 0.4;

		_bars = [];

		for (i in 1...11)
		{
			var bar:Bitmap = new Bitmap(_getImageData('bars_' + i));
			bar.x = 9;
			bar.y = 5;
			bar.scaleX = graphicScale;
			bar.scaleY = graphicScale;
			bar.smoothing = ClientPrefs.data.antialiasing;
			addChild(bar);
			_bars.push(bar);
		}

		y = -height;
		screenCenter();

		volumeUpSound = _getSoundPath('Volup');
		volumeDownSound = _getSoundPath('Voldown');
		volumeMaxSound = _getSoundPath('VolMAX');

		_lastMod = Mods.currentModDirectory;
	}

	override public function update(MS:Float):Void
	{
		var elapsed:Float = MS / 1000;
		y = FlxMath.lerp(y, lerpYPos, 0.1);
		alpha = FlxMath.lerp(alpha, alphaTarget, 0.25);

		if (_timer > 0)
		{
			_timer -= (MS / 1000);
			alphaTarget = 1;
			lerpYPos = 10;
		}
		else
		{
			lerpYPos = -height - 10;
			alphaTarget = 0;
		}

		if (y <= -height && alpha <= 0.01)
		{
			visible = false;
			active = false;

			#if FLX_SAVE
			if (FlxG.save.isBound)
			{
				FlxG.save.data.mute = FlxG.sound.muted;
				FlxG.save.data.volume = (funkin.Main.focusVolume != null) ? funkin.Main.focusVolume : FlxG.sound.volume;
				FlxG.save.flush();
			}
			#end
		}
	}

	override public function show(up:Bool = false):Void
	{
		if (Mods.currentModDirectory != _lastMod)
			_buildGraphics();

		_timer = 1;
		lerpYPos = 10;
		visible = true;
		active = true;
		if (parent != null)
			parent.setChildIndex(this, parent.numChildren - 1);
		if (funkin.Main.focusVolume == null && FlxG.sound.volume != levelToVolume(volumeLevel))
		{
			volumeLevel = Std.int(FlxMath.bound(volumeLevel + (up ? 1 : -1), 0, VOLUME_STEPS));
			FlxG.sound.volume = levelToVolume(volumeLevel);
		}

		var globalVolume:Int = FlxG.sound.muted ? 0 : volumeLevel;

		if (!silent)
		{
			var sound = up ? volumeUpSound : volumeDownSound;

			if (globalVolume == 10) sound = volumeMaxSound;

			if (sound != null) FlxG.sound.load(sound).play();
		}

		for (i in 0..._bars.length)
		{
			if (i < globalVolume)
			{
				_bars[i].visible = true;
			}
			else
			{
				_bars[i].visible = false;
			}
		}
	}
}