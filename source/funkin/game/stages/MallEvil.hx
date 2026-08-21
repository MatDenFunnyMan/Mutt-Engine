package funkin.game.stages;

import funkin.game.stages.objects.*;

class MallEvil extends BaseStage
{
	override function create()
	{
		setDefaultGF('gf-christmas');
		
		//Winter Horrorland cutscene
		if (isStoryMode && !seenCutscene)
		{
			switch(songName)
			{
				case 'winter-horrorland':
					setStartCallback(winterHorrorlandCutscene);
			}
		}
	}

	function winterHorrorlandCutscene()
	{
		camHUD.visible = false;
		inCutscene = true;

		FlxG.sound.play(Paths.sound('Lights_Turn_On'));
		FlxG.camera.zoom = 1.5;
		FlxG.camera.focusOn(new FlxPoint(400, -2050));

		// blackout at the start
		var blackScreen:FlxSprite = new FlxSprite().makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
		blackScreen.scrollFactor.set();
		add(blackScreen);

		FlxTween.tween(blackScreen, {alpha: 0}, 0.7, {
			ease: FlxEase.linear,
			onComplete: function(twn:FlxTween) {
				remove(blackScreen);
			}
		});

		// zoom out
		new FlxTimer().start(0.8, function(tmr:FlxTimer)
		{
			camHUD.visible = true;
			FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 2.5, {
				ease: FlxEase.quadInOut,
				onComplete: function(twn:FlxTween)
				{
					startCountdown();
				}
			});
		});
	}
}