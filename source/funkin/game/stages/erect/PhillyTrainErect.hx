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
import flixel.FlxSubState;

class PhillyTrainErect extends BaseStage
{
	var phillyLightsColors:Array<FlxColor>;
	var phillyWindow:BGSprite;
	var phillyStreet:BGSprite;
	var phillyTrain:PhillyTrain;
	var curLight:Int = -1;

	var cutsceneObj:funkin.game.cutscenes.TwoPicos;

	var curLightEvent:Int = -1;
	var colorShader:AdjustColorShader;

	override function create()
	{
		if (!ClientPrefs.data.lowQuality)
		{
			var bg:BGSprite = new BGSprite('philly/erect/sky', -100, 0, 0.1, 0.1);
			add(bg);
		}

		var city:BGSprite = new BGSprite('philly/erect/city', -255, 45, 0.3, 0.3);
		city.setGraphicSize(Std.int(city.width * 0.9));
		city.updateHitbox();
		add(city);

		phillyLightsColors = [0x502d64, 0x2663ac, 0x932c28, 0x329a6d, 0xb66f43];
		phillyWindow = new BGSprite('philly/win', -184, 155, 0.3, 0.3);
		phillyWindow.setGraphicSize(Std.int(phillyWindow.width * 0.9));
		phillyWindow.updateHitbox();
		add(phillyWindow);
		phillyWindow.alpha = 0;

		if (!ClientPrefs.data.lowQuality)
		{
			var streetBehind:BGSprite = new BGSprite('philly/erect/behindTrain', -299, 144);
			add(streetBehind);
		}

		phillyTrain = new PhillyTrain(2000, 360);
		add(phillyTrain);

		phillyStreet = new BGSprite('philly/erect/street', -299, 144);
		add(phillyStreet);

		if (ClientPrefs.data.shaders)
		{
			colorShader = new AdjustColorShader();
			colorShader.hue = -26;
			colorShader.saturation = -16;
			colorShader.contrast = 0;
			colorShader.brightness = -5;
		}

		if (!seenCutscene && PlayState.SONG.player1 == "pico-playable" && PlayState.SONG.player2 == "pico")
		{
			cutsceneObj = new funkin.game.cutscenes.TwoPicos(this, colorShader);
			setStartCallback(cutsceneObj.startCutscene);
		}

		new PhillyLights(phillyStreet, phillyWindow.x, phillyWindow.y, phillyLightsColors, 'philly/win', 0.9);
	}

	override function createPost()
	{
		super.createPost();

		if (ClientPrefs.data.shaders)
		{
			boyfriend.shader = colorShader;
			dad.shader = colorShader;
			gf.shader = colorShader;
			phillyTrain.shader = colorShader;
			PicoCapableStage.instance?.applyABotShader(colorShader);
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		if (eventName == "Change Character" && ClientPrefs.data.shaders)
		{
			switch (value1.toLowerCase().trim())
			{
				case 'gf' | 'girlfriend' | '2':
					gf.shader = colorShader;
				case 'dad' | 'opponent' | '1':
					dad.shader = colorShader;
				default:
					boyfriend.shader = colorShader;
			}
		}
		else if (eventName == "Philly Glow" && cutsceneObj != null && cutsceneObj.imposterPico != null)
		{
			switch (flValue1 == null ? 0 : Math.round(flValue1))
			{
				case 0:
					cutsceneObj.imposterPico.color = 0xFFFFFFFF;
				case 1:
					cutsceneObj.imposterPico.color = dad.color;
			}
		}
	}

	override function update(elapsed:Float)
	{
		phillyWindow.alpha -= (Conductor.crochet / 1000) * FlxG.elapsed * 1.9;
		super.update(elapsed);
	}

	override function beatHit()
	{
		phillyTrain.beatHit(curBeat);
		if (curBeat % 4 == 0)
		{
			curLight = FlxG.random.int(0, phillyLightsColors.length - 1, [curLight]);
			phillyWindow.color = phillyLightsColors[curLight];
			phillyWindow.alpha = 1;
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (phillyTrain.sound?.playing)
		{
			phillyTrain.sound.pause();
			PlayState.instance.subStateClosed.addOnce((sub) ->
			{
				if (phillyTrain.sound != null)
					phillyTrain.sound.resume();
			});
		}
		super.openSubState(SubState);
	}

	function doFlash()
	{
		var color:FlxColor = FlxColor.WHITE;
		if (!ClientPrefs.data.flashing)
			color.alphaFloat = 0.5;

		FlxG.camera.flash(color, 0.15, null, true);
	}
}
