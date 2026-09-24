package funkin.game.cutscenes;

import haxe.Json;
import flixel.addons.text.FlxTypeText;

typedef PixelDialogueFile =
{
	var dialogue:Array<PixelDialogueLine>;
	@:optional var style:String;
}

typedef PixelDialogueLine =
{
	var portrait:Null<String>;
	var expression:Null<String>;
	var text:Null<String>;
	var boxState:Null<String>;
	var speed:Null<Float>;
	@:optional var sound:Null<String>;
}

enum PixelBoxState
{
	OPEN_INIT;
	OPEN;
	IDLE;
	WAIT;
	CLOSE_FINISH;
}

class PixelDialogueBox extends FlxSpriteGroup
{
	static final LEFT_CHAR_X:Float = -60;
	static final RIGHT_CHAR_X:Float = -100;
	static final DEFAULT_CHAR_Y:Float = 60;
	static final TEXT_X:Float = 206;
	static final TEXT_Y:Float = 470;
	static final OFFSET_X:Float = -100;
	static final SCROLL_SPEED:Float = 400;
	static final ALPHA_FADE_SCALE:Float = 3;
	static final UPDATE_THRESHOLD:Float = 0.05;
	static final CLOSE_SOUND:String = 'clickText';

	public var finishThing:Void->Void;
	public var nextDialogueThing:Void->Void = null;
	public var skipDialogueThing:Void->Void = null;
	public var onLine:Int->Void = null;

	var dialogueList:PixelDialogueFile;
	var bgFade:FlxSprite;
	var box:FlxSprite;
	var swagDialogue:FlxTypeText;
	var skipText:FlxText;
	var arrayCharacters:Array<DialogueCharacter> = [];

	var currentText:Int = 0;
	var lastCharacter:Int = -1;
	var lastBoxType:String = '';
	var lastState:PixelBoxState = null;
	var lastSound:String = '';
	var lineDone:Bool = false;
	var dialogueEnded:Bool = false;
	var ignoreThisFrame:Bool = true;
	var cumulatedElapsed:Float = 0;
	var offsetY:Float = FlxG.height - 700;
	var centerOffset:Float = (FlxG.width - FlxG.initialWidth) / 2;

	public static function parse(path:String):PixelDialogueFile
	{
		#if MODS_ALLOWED
		if(FileSystem.exists(path)) return cast Json.parse(File.getContent(path));
		#else
		if(openfl.utils.Assets.exists(path)) return cast Json.parse(openfl.utils.Assets.getText(path));
		#end
		return null;
	}

	public function new(dialogueList:PixelDialogueFile)
	{
		super();
		this.dialogueList = dialogueList;

		Paths.sound(CLOSE_SOUND);

		bgFade = CoolUtil.makeSolid(new FlxSprite(-500, -500), FlxG.width * 2, FlxG.height * 2, 0xBFB3DFD8);
		bgFade.scrollFactor.set();
		bgFade.alpha = 0;
		add(bgFade);

		spawnCharacters();

		box = new FlxSprite(537 + centerOffset, 347);
		box.antialiasing = false;
		box.frames = Paths.getSparrowAtlas('pixelUI/dialogueBox-new');
		box.scrollFactor.set();
		box.animation.addByNames('normal', ['Text Box Speaking0001'], 24, false);
		box.animation.addByPrefix('normalOpen', 'Text Box Appear', 24, false);
		box.animation.addByPrefix('normalWait', 'Text Box wait to click0', 24, true);
		box.animation.addByPrefix('angryOpen', 'SENPAI ANGRY IMPACT SPEECH0', 24, false);
		box.animation.addByPrefix('normalClick', 'Text Box CLICK', 24, false);
		box.animation.play('normalOpen', true);
		box.visible = false;
		box.setGraphicSize(Std.int(box.width * 6 * 0.9));
		box.updateHitbox();
		add(box);

		swagDialogue = new FlxTypeText(TEXT_X + centerOffset, TEXT_Y, Std.int(FlxG.width * 0.6), '', 32);
		swagDialogue.font = Paths.font('pixel-latin.ttf');
		swagDialogue.color = 0xFF3F2021;
		swagDialogue.borderStyle = SHADOW;
		swagDialogue.borderColor = 0xFFD89494;
		swagDialogue.shadowOffset.set(2, 2);
		swagDialogue.completeCallback = () -> lineDone = true;
		setSound('pixelText');
		add(swagDialogue);

		skipText = new FlxText(FlxG.width - 320, FlxG.height - 30, 300, Language.getPhrase('dialogue_skip', 'Press BACK to Skip'), 16);
		skipText.setFormat(null, 16, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		skipText.borderSize = 2;
		add(skipText);

		FlxTween.tween(bgFade, {alpha: 0.5}, 1);
		startNextDialog(true);
	}

	function spawnCharacters()
	{
		var added:Array<String> = [];
		for (line in dialogueList.dialogue)
		{
			if(line == null || added.contains(line.portrait)) continue;
			added.push(line.portrait);

			var x:Float = LEFT_CHAR_X + centerOffset;
			var y:Float = DEFAULT_CHAR_Y;
			var char:DialogueCharacter = new DialogueCharacter(x + OFFSET_X, y, line.portrait);
			char.setGraphicSize(Std.int(char.width * DialogueCharacter.DEFAULT_SCALE * char.jsonFile.scale));
			char.updateHitbox();
			char.scrollFactor.set();
			char.alpha = 0.00001;
			add(char);

			var saveY:Bool = false;
			switch(char.jsonFile.dialogue_pos)
			{
				case 'center':
					char.x = FlxG.width / 2 - char.width / 2;
					y = char.y;
					char.y = offsetY + 50;
					saveY = true;
				case 'right':
					x = FlxG.width - char.width + RIGHT_CHAR_X - centerOffset;
					char.x = x - OFFSET_X;
			}
			x += char.jsonFile.position[0];
			y += char.jsonFile.position[1];
			char.x += char.jsonFile.position[0];
			char.y += char.jsonFile.position[1];
			char.startingPos = saveY ? y : x;
			arrayCharacters.push(char);
		}
	}

	function setSound(name:String)
	{
		if(lastSound == name) return;
		lastSound = name;
		swagDialogue.sounds = [FlxG.sound.load(Paths.sound(name), 0.6)];
	}

	function playBoxAnim(state:PixelBoxState, boxType:String)
	{
		if(lastState == state && state != OPEN_INIT) return;
		lastState = state;
		switch(state)
		{
			case OPEN_INIT:
				box.centerOffsets();
				box.updateHitbox();
				if(boxType == 'angry')
				{
					box.offset.set(50, 65);
					box.animation.play('angryOpen', true);
				}
				else
				{
					box.offset.set(10, 0);
					box.animation.play('normalOpen', true);
				}
			case CLOSE_FINISH:
				box.animation.play('normalOpen', true, true);
			case IDLE:
				box.centerOffsets();
				box.updateHitbox();
				box.offset.set(10, 0);
				box.animation.play('normal', true);
			case WAIT:
				box.centerOffsets();
				box.updateHitbox();
				box.offset.set(10, 0);
				box.animation.play('normalWait', true);
			case OPEN:
		}
	}

	override function update(elapsedReal:Float)
	{
		if(ignoreThisFrame)
		{
			ignoreThisFrame = false;
			super.update(elapsedReal);
			return;
		}

		var elapsed:Float = 0;
		cumulatedElapsed += elapsedReal;
		if(cumulatedElapsed > UPDATE_THRESHOLD)
		{
			elapsed = cumulatedElapsed;
			cumulatedElapsed = 0;
		}

		if(!dialogueEnded)
		{
			var back:Bool = Controls.instance.BACK;
			if(back)
			{
				FlxG.sound.play(Paths.sound(CLOSE_SOUND));
				skipDialogue();
			}
			else if(Controls.instance.ACCEPT && box.visible && box.animation.finishCallback == null)
			{
				FlxG.sound.play(Paths.sound(CLOSE_SOUND));
				if(!lineDone)
				{
					swagDialogue.skip();
					lineDone = true;
					playBoxAnim(WAIT, lastBoxType);
					if(skipDialogueThing != null) skipDialogueThing();
				}
				else if(currentText >= dialogueList.dialogue.length)
					skipDialogue();
				else
				{
					box.animation.play('normalClick');
					lastState = null;
					box.animation.finishCallback = function(_)
					{
						box.animation.finishCallback = null;
						startNextDialog(false);
					};
				}
			}
			else if(lineDone)
			{
				var char:DialogueCharacter = arrayCharacters[lastCharacter];
				if(char != null && char.animation.curAnim != null && char.animationIsLoop() && char.animation.finished)
					char.playAnim(char.animation.curAnim.name, true);
				if(box.animation.finishCallback == null) playBoxAnim(WAIT, lastBoxType);
			}
			else
			{
				var char:DialogueCharacter = arrayCharacters[lastCharacter];
				if(char != null && char.animation.curAnim != null && char.animation.finished)
					char.animation.curAnim.restart();
			}

			if(lastCharacter != -1)
			{
				for (i in 0...arrayCharacters.length)
				{
					var char = arrayCharacters[i];
					if(char == null) continue;
					var isCur:Bool = (i == lastCharacter);
					var dir:Float = isCur ? 1 : -1;
					switch(char.jsonFile.dialogue_pos)
					{
						case 'left':
							char.x += dir * SCROLL_SPEED * elapsed;
							if(isCur && char.x > char.startingPos) char.x = char.startingPos;
							if(!isCur && char.x < char.startingPos + OFFSET_X) char.x = char.startingPos + OFFSET_X;
						case 'center':
							char.y -= dir * SCROLL_SPEED * elapsed;
							if(isCur && char.y < char.startingPos) char.y = char.startingPos;
							if(!isCur && char.y > char.startingPos + offsetY) char.y = char.startingPos + offsetY;
						case 'right':
							char.x -= dir * SCROLL_SPEED * elapsed;
							if(isCur && char.x < char.startingPos) char.x = char.startingPos;
							if(!isCur && char.x > char.startingPos - OFFSET_X) char.x = char.startingPos - OFFSET_X;
					}
					char.alpha = FlxMath.bound(char.alpha + dir * ALPHA_FADE_SCALE * 3 * elapsed, 0.00001, 1);
				}
			}
		}
		else
		{
			if(box != null && box.animation.curAnim != null && box.animation.curAnim.curFrame <= 0)
			{
				remove(box);
				box.destroy();
				box = null;
			}

			if(bgFade != null)
			{
				bgFade.alpha -= 0.5 * elapsedReal;
				if(bgFade.alpha <= 0)
				{
					remove(bgFade);
					bgFade.destroy();
					bgFade = null;
				}
			}

			for (char in arrayCharacters)
			{
				if(char == null) continue;
				switch(char.jsonFile.dialogue_pos)
				{
					case 'left': char.x -= SCROLL_SPEED * elapsed;
					case 'center': char.y += SCROLL_SPEED * elapsed;
					case 'right': char.x += SCROLL_SPEED * elapsed;
				}
				char.alpha -= ALPHA_FADE_SCALE * elapsed * 10;
			}

			if(box == null && bgFade == null)
			{
				for (char in arrayCharacters)
				{
					remove(char);
					char.destroy();
				}
				arrayCharacters = [];
				kill();
				if(finishThing != null) finishThing();
				return;
			}
		}
		super.update(elapsedReal);
	}

	function skipDialogue()
	{
		dialogueEnded = true;
		if(box != null) box.animation.finishCallback = null;
		playBoxAnim(CLOSE_FINISH, lastBoxType);
		if(swagDialogue != null)
		{
			remove(swagDialogue);
			swagDialogue.destroy();
			swagDialogue = null;
		}
		skipText.visible = false;
		if(FlxG.sound.music != null) FlxG.sound.music.fadeOut(1, 0, (_) -> FlxG.sound.music.stop());
	}

	function startNextDialog(init:Bool)
	{
		var line:PixelDialogueLine = dialogueList.dialogue[currentText];
		if(line.text == null || line.text.length < 1) line.text = ' ';
		if(line.boxState == null) line.boxState = 'normal';
		if(line.speed == null || Math.isNaN(line.speed)) line.speed = 0.05;

		var boxType:String = (line.boxState == 'angry') ? 'angry' : 'normal';

		var character:Int = 0;
		for (i in 0...arrayCharacters.length)
		{
			if(arrayCharacters[i].curCharacter == line.portrait)
			{
				character = i;
				break;
			}
		}

		box.visible = true;
		if(init) playBoxAnim(OPEN_INIT, boxType);
		else if(character == lastCharacter) playBoxAnim(IDLE, boxType);
		lastCharacter = character;
		lastBoxType = boxType;

		setSound((line.sound == null || line.sound.trim().length < 1) ? 'dialogue' : line.sound);
		swagDialogue.resetText(line.text);
		swagDialogue.delay = line.speed;
		lineDone = false;
		swagDialogue.start(null, true);

		var char:DialogueCharacter = arrayCharacters[character];
		if(char != null)
		{
			char.playAnim(line.expression, false);
			if(char.animation.curAnim != null)
				char.animation.curAnim.frameRate = FlxMath.bound(24 - (((line.speed - 0.05) / 5) * 480), 12, 48);
		}
		currentText++;

		if(onLine != null) onLine(currentText);
		if(nextDialogueThing != null) nextDialogueThing();
	}
}
