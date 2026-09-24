package funkin.game.cutscenes;

import funkin.game.cutscenes.PixelDialogueBox.PixelDialogueFile;

class SchoolDoof
{
	var dialogue:PixelDialogueFile;
	public var onLine:Int->Void = null;

	public function new(songName:String)
	{
		var candidates:Array<String> = [
			Paths.json('songs/$songName/${songName}Dialogue_${ClientPrefs.data.language}'),
			Paths.json('songs/$songName/${songName}Dialogue')
		];
		#if MODS_ALLOWED
		candidates.insert(0, Paths.modsJson('songs/$songName/${songName}Dialogue'));
		#end
		for (path in candidates)
		{
			dialogue = PixelDialogueBox.parse(path);
			if(dialogue != null && dialogue.dialogue != null && dialogue.dialogue.length > 0) break;
			dialogue = null;
		}
	}

	public function doSimpleDialogue()
	{
		var game:PlayState = PlayState.instance;
		if(dialogue == null)
		{
			game.startCountdown();
			return;
		}

		game.inCutscene = true;
		var box:PixelDialogueBox = new PixelDialogueBox(dialogue);
		box.scrollFactor.set();
		box.cameras = [game.camHUD];
		box.finishThing = () -> game.startCountdown();
		box.nextDialogueThing = game.startNextDialogue;
		box.skipDialogueThing = game.skipDialogue;
		box.onLine = onLine;
		game.add(box);
	}

	public function doSchoolIntro()
	{
		var game:PlayState = PlayState.instance;
		game.inCutscene = true;
		var black:FlxSprite = CoolUtil.makeSolid(new FlxSprite(-100, -100), FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		if(dialogue != null) game.add(black);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			black.alpha -= 0.15;
			if(black.alpha <= 0)
			{
				game.remove(black);
				black.destroy();
				doSimpleDialogue();
			}
			else tmr.reset(0.3);
		});
	}

	public function doAngryIntro()
	{
		FlxG.sound.play(Paths.sound('ANGRY'));
		doSimpleDialogue();
	}
}
