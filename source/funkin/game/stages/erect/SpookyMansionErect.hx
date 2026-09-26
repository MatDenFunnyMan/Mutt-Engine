package funkin.game.stages.erect;

import funkin.game.Character;
import funkin.game.notes.Note;
import funkin.game.notes.Note.EventNote;
import funkin.game.states.GameOverSubstate;
import funkin.game.stages.objects.*;
import funkin.graphics.shaders.AdjustColorShader;
import funkin.graphics.shaders.DropShadowShader;
import funkin.graphics.shaders.DropShadowScreenspace;
import funkin.graphics.shaders.RainShader;
import funkin.graphics.shaders.WiggleEffectRuntime;
class SpookyMansionErect extends BaseStage
{
	var halloweenBG:BGSprite;
	var halloweenBGLight:BGSprite;

	var shader:RainShader;
	var halloweenWindow:BGSprite;

	var stairsDark:BGSprite;
	var stairsLight:BGSprite;

	var boyfriendLit:Character;
	var gfLit:Character;
	var dadLit:Character;

	public function new() {
		super();
	}
	override function create()
	{
		var bg:FlxSprite = makeSolid(-300,-500, 2400, 2000, 0xFF242336);
		add(bg);

		halloweenBG = new BGSprite('erect/bgDark', -560, -220);
		halloweenBGLight = new BGSprite('erect/bgLight', -560, -220);
		halloweenBGLight.alpha = 0;

		stairsDark = new BGSprite('erect/stairsDark', 966, -225);
		stairsLight = new BGSprite('erect/stairsLight', 966, -225);
		stairsLight.alpha = 0;

		halloweenWindow = new BGSprite('erect/bgtrees', 200, 50, 0.8, 0.8, ["bgtrees0"],true);
		halloweenWindow.animation.curAnim.frameRate = 5;

		add(halloweenWindow);
		add(halloweenBG);
		add(halloweenBGLight);

		Paths.sound('thunder_1');
		Paths.sound('thunder_2');
	}

	override function createPost()
	{
		super.createPost();
		if(ClientPrefs.data.shaders){
			shader = new RainShader();
			shader.scale = FlxG.height / 200 * 2;
			shader.intensity = 0.4;
			shader.spriteMode = true;
			halloweenWindow.shader = shader;
		}

		halloweenWindow.animation.play("bgtrees0");
		if (!ClientPrefs.data.lowQuality)
		{
			boyfriendLit = makeLit(boyfriend, boyfriendGroup);
			dadLit = makeLit(dad, dadGroup);
			gfLit = makeLit(gf, gfGroup);
			FlxG.signals.preDraw.add(syncAllLit);
		}
		add(stairsDark);
		add(stairsLight);
	}

	override function update(elapsed:Float) {
		if(ClientPrefs.data.shaders){
		shader?.updateFrameInfo(halloweenWindow.frame);
		shader?.update(elapsed);
		}
		super.update(elapsed);
	}

	override function destroy()
	{
		FlxG.signals.preDraw.remove(syncAllLit);
		super.destroy();
	}

	function syncAllLit()
	{
		syncLit(boyfriend, boyfriendLit);
		syncLit(dad, dadLit);
		syncLit(gf, gfLit);
	}
	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;

	override function beatHit()
	{
		super.beatHit();
		if(ClientPrefs.data.lowQuality) return;
		if(curBeat == 4 && songName == "spookeez-erect") lightningStrikeShit(false);
		if (FlxG.random.bool(10) && curBeat > lightningStrikeBeat + lightningOffset)
		{
			lightningStrikeShit();
		}
	}

	function lightningStrikeShit(playSound:Bool = true):Void
	{
		if(playSound) FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));

		if (boyfriend != null && boyfriend.hasAnimation('scared') && boyfriend.getAnimationName() != 'cheer')
			boyfriend.playAnim('scared', true);
		if (gf != null && gf.hasAnimation('scared'))
			gf.playAnim('scared', true);

		if (ClientPrefs.data.flashing)
		{
			if (PicoCapableStage.instance != null && game.stages.contains(PicoCapableStage.instance)) PicoCapableStage.instance.ABot_plink();
			setLightning(true);
			FlxTimer.wait(0.06, () -> setLightning(false));
			FlxTimer.wait(0.12, () ->
			{
				setLightning(true);
				for (obj in [halloweenBGLight, stairsLight])
					FlxTween.tween(obj, {alpha: 0}, 1.5);
				for (char in [boyfriend, dad, gf])
					if (char != null) FlxTween.tween(char, {alpha: 1}, 1.5);
			});
		}

		lightningStrikeBeat = curBeat;
		lightningOffset = FlxG.random.int(8, 24);

		if (ClientPrefs.data.camZooms)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;

			if (!game.camZooming)
			{
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 0.5);
				FlxTween.tween(camHUD, {zoom: 1}, 0.5);
			}
		}
	}

	function setLightning(on:Bool)
	{
		halloweenBGLight.alpha = on ? 1 : 0;
		stairsLight.alpha = on ? 1 : 0;
		for (char in [boyfriend, dad, gf])
			if (char != null) char.alpha = on ? 0 : 1;
	}

	function makeLit(dark:Character, group:FlxSpriteGroup):Character
	{
		if (dark == null || group == null) return null;

		var name:String = dark.curCharacter.split("-")[0];
		if (name == "pico" && dark.isPlayer) name = "pico-playable";
		if (name == dark.curCharacter) return null;

		var lit:Character = new Character(0, 0, name, dark.isPlayer);
		lit.debugMode = true;
		lit.alpha = 0;
		group.insert(group.members.indexOf(dark), lit);
		return lit;
	}

	function syncLit(dark:Character, lit:Character)
	{
		if (dark == null || lit == null) return;

		lit.alpha = dark.alpha < 1 ? 1 : 0;
		if (lit.alpha == 0) return;

		var name:String = dark.getAnimationName();
		if (name != null && lit.hasAnimation(name))
		{
			var frame:Int = (dark.animation.curAnim != null) ? dark.animation.curAnim.curFrame : 0;
			if (lit.getAnimationName() != name) lit.playAnim(name, true, false, frame);
			if (lit.animation.curAnim != null)
				lit.animation.curAnim.curFrame = Std.int(Math.min(frame, lit.animation.curAnim.numFrames - 1));
		}
		lit.setPosition(dark.x, dark.y);
	}
}
