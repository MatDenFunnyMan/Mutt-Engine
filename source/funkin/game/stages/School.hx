package funkin.game.stages;

import funkin.game.stages.objects.*;
import funkin.game.states.GameOverSubstate;
import funkin.game.cutscenes.DialogueBox;

import openfl.utils.Assets as OpenFlAssets;

class School extends BaseStage
{
	var bgGirls:BackgroundGirls;
	override function create()
	{
		var _song = PlayState.SONG;
		if(_song.gameOverSound == null || _song.gameOverSound.trim().length < 1) GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
		if(_song.gameOverLoop == null || _song.gameOverLoop.trim().length < 1) GameOverSubstate.loopSoundName = 'gameOver-pixel';
		if(_song.gameOverEnd == null || _song.gameOverEnd.trim().length < 1) GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
		if(_song.gameOverChar == null || _song.gameOverChar.trim().length < 1) GameOverSubstate.characterName = 'bf-pixel-dead';

		setDefaultGF('gf-pixel');

		switch (songName)
		{
			case 'senpai':
				FlxG.sound.playMusic(Paths.music('Lunchbox'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
			case 'roses':
				FlxG.sound.play(Paths.sound('ANGRY_TEXT_BOX'));
		}
		if(isStoryMode && !seenCutscene)
		{
			if(songName == 'roses') FlxG.sound.play(Paths.sound('ANGRY'));
			initDoof();
			setStartCallback(schoolIntro);
		}
	}

	override function createPost()
	{
		if(!ClientPrefs.data.lowQuality)
		{
			bgGirls = new BackgroundGirls(-100, 190);
			bgGirls.scrollFactor.set(0.9, 0.9);
			addBehindGF(bgGirls);
		}
	}

	override function beatHit()
	{
		if(bgGirls != null) bgGirls.dance();
	}

	// For events
	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "BG Freaks Expression":
				if(bgGirls != null) bgGirls.swapDanceType();
		}
	}

	var doof:DialogueBox = null;
	function initDoof()
	{
		var file:String = Paths.txt('$songName/${songName}Dialogue_${ClientPrefs.data.language}'); //Checks for vanilla/Senpai dialogue
		#if MODS_ALLOWED
		if (!FileSystem.exists(file))
		#else
		if (!OpenFlAssets.exists(file))
		#end
		{
			file = Paths.txt('$songName/${songName}Dialogue');
		}

		#if MODS_ALLOWED
		if (!FileSystem.exists(file))
		#else
		if (!OpenFlAssets.exists(file))
		#end
		{
			startCountdown();
			return;
		}

		doof = new DialogueBox(false, CoolUtil.coolTextFile(file));
		doof.cameras = [camHUD];
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		doof.nextDialogueThing = PlayState.instance.startNextDialogue;
		doof.skipDialogueThing = PlayState.instance.skipDialogue;
	}
	
	function schoolIntro():Void
	{
		inCutscene = true;
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		if(songName == 'senpai') add(black);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			black.alpha -= 0.15;

			if (black.alpha <= 0)
			{
				if (doof != null)
					add(doof);
				else
					startCountdown();

				remove(black);
				black.destroy();
			}
			else tmr.reset(0.3);
		});
	}
}