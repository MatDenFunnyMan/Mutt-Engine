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
#if html5
import openfl.utils.Assets;
import openfl.display.BitmapData;
#end

class TankErect extends BaseStage
{
	var sniper:FlxSprite;
	var guy:FlxSprite;
	var tankmanRun:FlxTypedGroup<TankmenBG>;
	var cutscene:funkin.game.cutscenes.PicoTankman;
	var tankmanRim:DropShadowShader;
	var muzzleFlash:FlxSprite;
	#if html5
	var captainBloody_mask:BitmapData = null;
	#end

	override function create()
	{
		var bg:BGSprite = new BGSprite('erect/bg', -985, -805, 1, 1);
		bg.scale.set(1.15, 1.15);
		add(bg);

		sniper = new FlxSprite(-346, 245);
		sniper.frames = Paths.getSparrowAtlas('erect/sniper');
		sniper.animation.addByPrefix("idle", "Tankmanidlebaked instance 1", 24);
		sniper.animation.addByPrefix("sip", "tanksippingBaked instance 1", 24);
		sniper.scale.set(1.15, 1.15);
		add(sniper);

		guy = new FlxSprite(1175, 270);
		guy.frames = Paths.getSparrowAtlas('erect/guy');
		guy.animation.addByPrefix("idle", "BLTank2 instance 1", 24);
		guy.scale.set(1.15, 1.15);
		add(guy);

		tankmanRun = new FlxTypedGroup<TankmenBG>();
		add(tankmanRun);

		if (songName == "stress-(pico-mix)")
		{
			PicoCapableStage.addToGame(true);
			cutscene = new funkin.game.cutscenes.PicoTankman(this);
			if (!seenCutscene) setStartCallback(() -> game.startVideo('stressPicoCutscene'));
			setEndCallback(cutscene.playCutscene);
		}
	}

	function shootMuzzleFlash(shot:Int)
	{
		if (muzzleFlash == null || gf == null) return;

		var baseX:Float = gf.x - gf.offset.x + 13;
		var baseY:Float = gf.y - gf.offset.y + 132;
		switch (shot)
		{
			case 1: muzzleFlash.setPosition(baseX + 950, baseY);
			case 2: muzzleFlash.setPosition(baseX + 950, baseY - 50);
			case 3: muzzleFlash.setPosition(baseX - 350, baseY - 50);
			default: muzzleFlash.setPosition(baseX - 350, baseY - 100);
		}
		muzzleFlash.blend = openfl.display.BlendMode.ADD;
		muzzleFlash.visible = gf.visible;
		muzzleFlash.animation.play('shoot$shot', true);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (muzzleFlash != null && muzzleFlash.visible && muzzleFlash.animation.curAnim != null)
		{
			if (muzzleFlash.animation.curAnim.curFrame > 1) muzzleFlash.blend = null;
			if (muzzleFlash.animation.curAnim.finished) muzzleFlash.visible = false;
		}
	}

	override function beatHit()
	{
		super.beatHit();
		if (curBeat % 2 == 0)
		{
			sniper.animation.play('idle', true);
			guy.animation.play('idle', true);
		}
		if (FlxG.random.bool(2))
			sniper.animation.play('sip', true);
	}
	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float) {
		if(eventName == "EnableMask" && tankmanRim != null)
			tankmanRim.useAltMask = true;

		if(eventName == "Change Character" && ClientPrefs.data.shaders){
			switch(value1.toLowerCase().trim()) {
				case 'gf' | 'girlfriend' | '2':
					applyShader(gf, 'gf');
				case 'dad' | 'opponent' | '1':
					applyShader(dad, 'dad');
				default:
					applyShader(boyfriend, 'bf');
			}
		}
	}

	override function createPost()
	{
		if (ClientPrefs.data.shaders)
		{
			applyShader(boyfriend, 'bf');
			if (gf != null) applyShader(gf, 'gf');
			applyShader(dad, 'dad');

			var pico = PicoCapableStage.instance;
			if (pico != null && pico.abot != null && game.stages.contains(pico))
			{
				applyAbotShader(pico.abot.speaker);
				applyShader(pico.abot.bg, "");
			}
		}
		#if html5

		captainBloody_mask = null;
		var request = Assets.loadBitmapData("assets/week7/images/erect/masks/tankmanCaptainBloody_mask.png");
		request.onComplete(item ->{
			captainBloody_mask = item;
		});
		#end
		if (gf != null && gf.curCharacter == 'otis-speaker')
		{
			GameOverSubstate.characterName = 'pico-holding-nene-dead';

			muzzleFlash = new FlxSprite();
			muzzleFlash.frames = Paths.getSparrowAtlas('characters/otis/muzzle-flashes/otis_flashes');
			muzzleFlash.animation.addByPrefix('shoot1', 'shoot back0', 24, false);
			muzzleFlash.animation.addByPrefix('shoot2', 'shoot back low0', 24, false);
			muzzleFlash.animation.addByPrefix('shoot3', 'shoot forward0', 24, false);
			muzzleFlash.animation.addByPrefix('shoot4', 'shoot forward low0', 24, false);
			muzzleFlash.antialiasing = ClientPrefs.data.antialiasing;
			muzzleFlash.visible = false;
			addBehindGF(muzzleFlash);
			gf.onSpeakerShoot = shootMuzzleFlash;
		}
		if (cutscene != null) cutscene.preloadCutscene();

		if (!ClientPrefs.data.lowQuality)
		{
			var bricks:BGSprite = new BGSprite('erect/bricksGround', 375, 640, 1, 1);
			bricks.scale.set(1.15, 1.15);
			addBehindDad(bricks);

			for (daGf in gfGroup)
			{
				var gf:Character = cast daGf;
				if (gf.curCharacter == 'otis-speaker')
				{
					var firstTank:TankmenBG = new TankmenBG(20, 500, true);
					firstTank.resetShit(20, 1500, true,false);
					firstTank.strumTime = 10;
					firstTank.visible = false;
					tankmanRun.add(firstTank);

					for (i in 0...TankmenBG.animationNotes.length)
					{
						if (FlxG.random.bool(16))
						{
							var tankBih = tankmanRun.recycle(TankmenBG);
							if (ClientPrefs.data.shaders) applyShader(tankBih, "");
							tankBih.strumTime = TankmenBG.animationNotes[i][0];
							tankBih.scale.set(1, 1);
							tankBih.updateHitbox();
							tankBih.resetShit(500, 150, TankmenBG.animationNotes[i][1] < 2,false);

							tankmanRun.add(tankBih);
						}
					}
					break;
				}
			}
		}
	}

	public function applyAbotShader(sprite:FlxSprite){
		var rim = new DropShadowScreenspace();
		rim.setAdjustColor(-46, -38, -25, -20);
		rim.color = 0xFFDFEF3C;
		rim.antialiasAmt = 0;
		rim.attachedSprite = sprite;
		rim.distance = 5;
		rim.angle = 90;
		sprite.shader = rim;
		sprite.animation.callback = function(anim, frame, index)
		{
			rim.updateFrameInfo(sprite.frame);
			rim.curZoom = camGame.zoom;
		};
	}
	function applyShader(sprite:FlxSprite, role:String)
	{
		if (sprite == null) return;

		var rim = new DropShadowShader();
		rim.setAdjustColor(-46, -38, -25, -20);
		rim.color = 0xFFDFEF3C;
		rim.attachedSprite = sprite;
		rim.angle = 90;

		var charName:String = Std.isOfType(sprite, Character) ? cast(sprite, Character).curCharacter : '';
		switch (role)
		{
			case 'bf':
			case 'gf':
				var mask:String = switch (charName)
				{
					case 'gf-tankmen': 'erect/masks/gfTankmen_mask';
					case 'nene-tankmen': 'erect/masks/neneTankmen_mask';
					default: null;
				}
				if (mask != null && Paths.fileExists('images/$mask.png', IMAGE))
				{
					rim.altMaskImage = Paths.image(mask).bitmap;
					rim.maskThreshold = 0.4;
					rim.useAltMask = true;
				}
			case 'dad':
				rim.angle = 25;
				rim.threshold = 0.3;
				if (charName == 'tankman-bloody')
				{
					#if html5
					rim.altMaskImage = captainBloody_mask;
					#else
					rim.altMaskImage = Paths.image("erect/masks/tankmanCaptainBloody_mask").bitmap;
					#end
					rim.maskThreshold = 1;
					rim.useAltMask = false;
				}
				tankmanRim = rim;
			default:
				rim.threshold = 0.3;
		}

		sprite.animation.callback = function(anim, frame, index)
		{
			rim.updateFrameInfo(sprite.frame);
		};
		sprite.shader = rim;
	}

}
