package funkin.game.stages.objects;

import funkin.game.cutscenes.CutsceneHandler;
import funkin.util.AtlasUtil.ModernAtlasUtil;

class PicoDopplegangerSprite extends animate.FlxAnimate
{
	static final ANIMS:Array<String> = ['shoot', 'explode', 'cigarette', 'loop'];
	static inline final ATLAS_OFFSET_X:Float = -584;
	static inline final ATLAS_OFFSET_Y:Float = -609;

	public var isPlayer:Bool = false;
	var suffix:String = '';
	var cutsceneSounds:FlxSound = null;

	public function new(x:Float, y:Float)
	{
		super(x + ATLAS_OFFSET_X, y + ATLAS_OFFSET_Y);
		frames = Paths.getAnimateAtlasFrames('philly/erect/cutscenes/pico_doppleganger');
		useRenderTexture = true;
		for (side in ['Opponent', 'Player'])
			for (anim in ANIMS)
				ModernAtlasUtil.addAnimation(this, anim + side, anim + side, null, 24, anim == 'loop');
		antialiasing = ClientPrefs.data.antialiasing;
	}

	public function playAnimation(name:String, force:Bool = true)
	{
		anim.play(name, force);
	}

	public function cancelSounds()
	{
		if(cutsceneSounds != null)
		{
			cutsceneSounds.stop();
			cutsceneSounds = null;
		}
	}

	function playSound(name:String)
	{
		cutsceneSounds = FlxG.sound.play(Paths.sound('cutscene/$name'));
	}

	public function doAnim(_suffix:String, shoot:Bool, explode:Bool, cutsceneHandler:CutsceneHandler)
	{
		suffix = _suffix;

		if(shoot)
		{
			playAnimation('shoot' + suffix);
			cutsceneHandler.timer(6.29, () -> playSound('picoShoot'));
			cutsceneHandler.timer(10.33, () -> playSound('picoSpin'));
		}
		else if(explode)
		{
			playAnimation('explode' + suffix);
			animation.finishCallback = function(name:String)
			{
				if(name != 'explode' + suffix) return;
				animation.finishCallback = null;
				playAnimation('loop' + suffix);
			};
			cutsceneHandler.timer(3.7, () -> playSound('picoCigarette2'));
			cutsceneHandler.timer(8.75, () -> playSound('picoExplode'));
			cutsceneHandler.objects.remove(this);
		}
		else
		{
			playAnimation('cigarette' + suffix);
			cutsceneHandler.timer(3.7, () -> playSound('picoCigarette'));
		}
	}
}
