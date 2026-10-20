package funkin.editors;

import haxe.Json;
import haxe.io.Path;

import funkin.ui.TypedAlphabet;

import funkin.game.cutscenes.DialogueBoxPsych;
import funkin.game.cutscenes.DialogueCharacter;
import funkin.editors.content.Prompt;
import funkin.editors.content.FileDialogHandler;

class DialogueEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	static final TIP_TEXT_LINE:String = 'A/D - Change line | W/S - Change expression | O - Remove line | P - Add line\nSpace - Replay line | H - Toggle speech bubble | Ctrl+S - Save\nJKLI - Move camera (Shift = 4x) | Q/E - Zoom out/in | R - Reset camera';
	static final TIP_TEXT_OFFSET:String = 'WASD - Looping animation offset (Red) | Arrow Keys - Idle/Finished offset (Blue)\nShift - 10x faster | H - Toggle ghosts | Ctrl+S - Save\nJKLI - Move camera (Shift = 4x) | Q/E - Zoom out/in | R - Reset camera';
	static final DEFAULT_TEXT:String = 'coolswag';
	static final DEFAULT_SPEED:Float = 0.05;
	static final DEFAULT_BUBBLETYPE:String = 'normal';

	var camGame:FlxCamera;
	var camHUD:FlxCamera;

	var character:DialogueCharacter;
	var ghostLoop:DialogueCharacter;
	var ghostIdle:DialogueCharacter;
	var box:FlxSprite;
	var daText:TypedAlphabet;

	var selectedText:FlxText;
	var animText:FlxText;
	var tipText:FlxText;
	var offsetLoopText:FlxText;
	var offsetIdleText:FlxText;
	var messageText:FlxText;

	var dialogueFile:DialogueFile = null;
	var editedPortraits:Map<String, DialogueCharacterFile> = [];
	var fileDialog:FileDialogHandler = new FileDialogHandler();
	var unsavedProgress:Bool = false;

	var curSelected:Int = 0;
	var curAnim:Int = 0;
	var curSelectedAnim:String = null;
	var currentGhosts:Int = 0;
	var lastTab:String = 'Dialogue Line';
	var transitioning:Bool = false;

	override function create() {
		persistentUpdate = persistentDraw = true;
		camGame = initPsychCamera();
		camGame.bgColor = FlxColor.fromHSL(0, 0, 0.5);
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		dialogueFile = {dialogue: [copyDefaultLine()]};

		character = new DialogueCharacter();
		add(character);
		ghostLoop = createGhost(FlxColor.RED);
		ghostIdle = createGhost(FlxColor.BLUE);

		box = new FlxSprite(70, 370);
		box.antialiasing = ClientPrefs.data.antialiasing;
		box.frames = Paths.getSparrowAtlas('speech_bubble');
		box.animation.addByPrefix('normal', 'speech bubble normal', 24);
		box.animation.addByPrefix('angry', 'AHH speech bubble', 24);
		box.animation.addByPrefix('center', 'speech bubble middle', 24);
		box.animation.addByPrefix('center-angry', 'AHH Speech Bubble middle', 24);
		box.animation.play('normal', true);
		box.setGraphicSize(Std.int(box.width * 0.9));
		box.updateHitbox();
		add(box);

		daText = new TypedAlphabet(DialogueBoxPsych.DEFAULT_TEXT_X, DialogueBoxPsych.DEFAULT_TEXT_Y, DEFAULT_TEXT);
		daText.setScale(0.7);
		add(daText);

		selectedText = makeHudText(10, 10, 24);
		animText = makeHudText(10, 38, 24);
		tipText = makeHudText(10, 70, 14);
		tipText.text = TIP_TEXT_LINE;
		offsetLoopText = makeHudText(10, 10, 32);
		offsetIdleText = makeHudText(10, 46, 32);
		offsetLoopText.visible = offsetIdleText.visible = false;
		messageText = makeHudText(10, 0, 16);
		messageText.alpha = 0;

		addEditorBox();
		add(fileDialog);
		FlxG.mouse.visible = true;

		changeText();

		if(FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.fadeOut(0.6, 0);
		EditorHelper.scheduleEditorMusic(10);
		super.create();
	}

	function createGhost(color:FlxColor):DialogueCharacter {
		var ghost:DialogueCharacter = new DialogueCharacter();
		ghost.alpha = 0;
		ghost.color = color;
		ghost.isGhost = true;
		ghost.jsonFile = character.jsonFile;
		add(ghost);
		return ghost;
	}

	function makeHudText(x:Float, y:Float, size:Int):FlxText {
		var text:FlxText = new FlxText(x, y, 980, '', size);
		text.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.scrollFactor.set();
		text.cameras = [camHUD];
		add(text);
		return text;
	}

	var UI_box:PsychUIBox;
	function addEditorBox() {
		UI_box = new PsychUIBox(FlxG.width - 260, 10, 250, 290, ['Dialogue Line', 'Portrait', 'Animations']);
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];
		addDialogueLineUI();
		addPortraitUI();
		addAnimationsUI();
		UI_box.selectedName = 'Dialogue Line';
		add(UI_box);

		var loadButton:PsychUIButton = new PsychUIButton(UI_box.x, UI_box.y + 298, 'Load Dialogue', loadDialogue, 120);
		loadButton.cameras = [camHUD];
		add(loadButton);

		var saveButton:PsychUIButton = new PsychUIButton(UI_box.x + 130, loadButton.y, 'Save', saveDialogue, 120);
		saveButton.cameras = [camHUD];
		add(saveButton);

		var musicCheckBox:PsychUICheckBox = EditorHelper.createEditorMusicCheckBox(UI_box.x, loadButton.y + 30, 120);
		musicCheckBox.cameras = [camHUD];
		add(musicCheckBox);
	}

	var portraitInputText:PsychUIInputText;
	var lineInputText:PsychUIInputText;
	var angryCheckbox:PsychUICheckBox;
	var speedStepper:PsychUINumericStepper;
	var soundInputText:PsychUIInputText;
	function addDialogueLineUI() {
		var tab_group = UI_box.getTab('Dialogue Line').menu;

		portraitInputText = new PsychUIInputText(10, 20, 100, DialogueCharacter.DEFAULT_CHARACTER, 8);
		speedStepper = new PsychUINumericStepper(10, portraitInputText.y + 40, 0.005, DEFAULT_SPEED, 0, 0.5, 3);

		angryCheckbox = new PsychUICheckBox(speedStepper.x + 120, speedStepper.y, "Angry Textbox", 200);
		angryCheckbox.onClick = function()
		{
			updateTextBox();
			dialogueFile.dialogue[curSelected].boxState = (angryCheckbox.checked ? 'angry' : 'normal');
		};

		soundInputText = new PsychUIInputText(10, speedStepper.y + 40, 150, '', 8);
		lineInputText = new PsychUIInputText(10, soundInputText.y + 35, 230, DEFAULT_TEXT, 8);
		lineInputText.onPressEnter = function(e)
		{
			if(e.shiftKey)
			{
				lineInputText.text += '\n';
				lineInputText.caretIndex++;
			}
			else PsychUIInputText.focusOn = null;
		};

		tab_group.add(new FlxText(10, portraitInputText.y - 18, 0, 'Portrait:'));
		tab_group.add(new FlxText(10, speedStepper.y - 18, 0, 'Interval/Speed (ms):'));
		tab_group.add(new FlxText(10, soundInputText.y - 18, 0, 'Sound file name:'));
		tab_group.add(new FlxText(10, lineInputText.y - 18, 0, 'Text (Shift+Enter = new line):'));
		tab_group.add(portraitInputText);
		tab_group.add(angryCheckbox);
		tab_group.add(speedStepper);
		tab_group.add(soundInputText);
		tab_group.add(lineInputText);
	}

	var portraitFileText:FlxText;
	var imageInputText:PsychUIInputText;
	var positionDropDown:PsychUIDropDownMenu;
	var xStepper:PsychUINumericStepper;
	var yStepper:PsychUINumericStepper;
	var scaleStepper:PsychUINumericStepper;
	var noAntialiasingCheckbox:PsychUICheckBox;
	function addPortraitUI() {
		var tab_group = UI_box.getTab('Portrait').menu;

		portraitFileText = new FlxText(10, 8, 230, '');
		imageInputText = new PsychUIInputText(10, 58, 150, '', 8);
		xStepper = new PsychUINumericStepper(10, 150, 10, 0, -2000, 2000, 0);
		yStepper = new PsychUINumericStepper(90, xStepper.y, 10, 0, -2000, 2000, 0);
		scaleStepper = new PsychUINumericStepper(10, xStepper.y + 45, 0.05, 1, 0.1, 10, 2);

		noAntialiasingCheckbox = new PsychUICheckBox(90, scaleStepper.y, "No Antialiasing", 100);
		noAntialiasingCheckbox.onClick = function() editPortrait(function(file) file.no_antialiasing = noAntialiasingCheckbox.checked);

		var loadPortraitButton:PsychUIButton = new PsychUIButton(10, scaleStepper.y + 35, 'Load Portrait', loadPortrait, 110);

		positionDropDown = new PsychUIDropDownMenu(10, 103, ['left', 'center', 'right'], function(id:Int, pos:String) {
			editPortrait(function(file) file.dialogue_pos = pos);
		});

		tab_group.add(new FlxText(10, imageInputText.y - 18, 0, 'Image (images/dialogue/):'));
		tab_group.add(new FlxText(10, positionDropDown.y - 18, 0, 'Position:'));
		tab_group.add(new FlxText(10, xStepper.y - 18, 0, 'Position Offset:'));
		tab_group.add(new FlxText(10, scaleStepper.y - 18, 0, 'Scale:'));
		tab_group.add(portraitFileText);
		tab_group.add(imageInputText);
		tab_group.add(xStepper);
		tab_group.add(yStepper);
		tab_group.add(scaleStepper);
		tab_group.add(noAntialiasingCheckbox);
		tab_group.add(loadPortraitButton);
		tab_group.add(positionDropDown);
	}

	var animationDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var loopInputText:PsychUIInputText;
	var idleInputText:PsychUIInputText;
	function addAnimationsUI() {
		var tab_group = UI_box.getTab('Animations').menu;

		animationDropDown = new PsychUIDropDownMenu(10, 30, [''], function(id:Int, animation:String) {
			if(!character.dialogueAnimations.exists(animation)) return;
			selectGhostAnim(animation);
			var animShit:DialogueAnimArray = character.dialogueAnimations.get(animation);
			animationInputText.text = animShit.anim;
			loopInputText.text = animShit.loop_name;
			idleInputText.text = animShit.idle_name;
		});

		animationInputText = new PsychUIInputText(15, 85, 100, '', 8);
		loopInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		idleInputText = new PsychUIInputText(loopInputText.x, loopInputText.y + 40, 150, '', 8);

		var addUpdateButton:PsychUIButton = new PsychUIButton(10, idleInputText.y + 30, "Add/Update", function() {
			var theAnim:String = animationInputText.text.trim();
			if(theAnim.length < 1) return;

			if(character.dialogueAnimations.exists(theAnim))
			{
				for (animArray in character.jsonFile.animations)
				{
					if(animArray.anim.trim() == theAnim)
					{
						animArray.loop_name = loopInputText.text;
						animArray.idle_name = idleInputText.text;
						break;
					}
				}
			}
			else
			{
				character.jsonFile.animations.push({
					anim: theAnim,
					loop_name: loopInputText.text,
					loop_offsets: [0, 0],
					idle_name: idleInputText.text,
					idle_offsets: [0, 0]
				});
			}
			markPortraitEdited();
			reloadAllAnimations();
			reloadAnimationsDropDown();
			animationDropDown.selectedLabel = theAnim;
			selectGhostAnim(theAnim);
		});

		var removeButton:PsychUIButton = new PsychUIButton(100, addUpdateButton.y, "Remove", function() {
			for (animArray in character.jsonFile.animations)
			{
				if(animArray != null && animArray.anim.trim() == animationInputText.text.trim())
				{
					character.jsonFile.animations.remove(animArray);
					markPortraitEdited();
					reloadAllAnimations();
					reloadAnimationsDropDown();
					if(character.jsonFile.animations.length > 0) selectGhostAnim(character.jsonFile.animations[0].anim);
					animationInputText.text = '';
					loopInputText.text = '';
					idleInputText.text = '';
					break;
				}
			}
		});

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, 'Animations:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, 'Animation name:'));
		tab_group.add(new FlxText(loopInputText.x, loopInputText.y - 18, 0, 'Loop anim (XML):'));
		tab_group.add(new FlxText(idleInputText.x, idleInputText.y - 18, 0, 'Idle anim (XML):'));
		tab_group.add(animationInputText);
		tab_group.add(loopInputText);
		tab_group.add(idleInputText);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(animationDropDown);
	}

	function reloadAnimationsDropDown() {
		var list:Array<String> = [for (anim in character.jsonFile.animations) anim.anim];
		if(list.length < 1) list = [''];
		animationDropDown.list = list;
	}

	function copyDefaultLine():DialogueLine {
		return {
			portrait: DialogueCharacter.DEFAULT_CHARACTER,
			expression: 'talk',
			text: DEFAULT_TEXT,
			boxState: DEFAULT_BUBBLETYPE,
			speed: DEFAULT_SPEED,
			sound: ''
		};
	}

	function portraitName():String {
		var name:String = dialogueFile.dialogue[curSelected].portrait;
		return (name == null || name.trim().length < 1) ? DialogueCharacter.DEFAULT_CHARACTER : name.trim();
	}

	function portraitExists(name:String):Bool
		return editedPortraits.exists(name) || Paths.fileExists('images/dialogue/$name.json', TEXT);

	function loadPortraitFile(name:String) {
		if(editedPortraits.exists(name)) character.jsonFile = editedPortraits.get(name);
		else character.reloadCharacterJson(name);
		if(character.jsonFile.animations == null) character.jsonFile.animations = [];
		if(character.jsonFile.position == null) character.jsonFile.position = [0, 0];

		reloadCharacter();
		reloadAnimationsDropDown();
		fillPortraitFields();
	}

	function fillPortraitFields() {
		var name:String = portraitName();
		portraitFileText.text = 'File: images/dialogue/$name.json';
		if(!portraitExists(name)) portraitFileText.text += '\n(not found: editing a copy of ${DialogueCharacter.DEFAULT_CHARACTER})';

		imageInputText.text = character.jsonFile.image;
		positionDropDown.selectedLabel = character.jsonFile.dialogue_pos;
		xStepper.value = character.jsonFile.position[0];
		yStepper.value = character.jsonFile.position[1];
		scaleStepper.value = character.jsonFile.scale;
		noAntialiasingCheckbox.checked = (character.jsonFile.no_antialiasing == true);
	}

	function markPortraitEdited() {
		editedPortraits.set(portraitName(), character.jsonFile);
		unsavedProgress = true;
	}

	function editPortrait(change:DialogueCharacterFile->Void) {
		change(character.jsonFile);
		markPortraitEdited();
		reloadCharacter();
		updateTextBox();
		fillPortraitFields();
	}

	function reloadAllAnimations() {
		for (char in [character, ghostLoop, ghostIdle])
		{
			char.jsonFile = character.jsonFile;
			char.reloadAnimations();
		}
	}

	function reloadCharacter() {
		var image:String = 'dialogue/' + character.jsonFile.image;
		var hasImage:Bool = Paths.fileExists('images/$image.png', IMAGE);
		for (char in [character, ghostLoop, ghostIdle])
		{
			if(hasImage) char.frames = Paths.getSparrowAtlas(image);
			char.jsonFile = character.jsonFile;
			char.reloadAnimations();
			char.setGraphicSize(Std.int(char.frameWidth * DialogueCharacter.DEFAULT_SCALE * character.jsonFile.scale));
			char.updateHitbox();
			char.antialiasing = ClientPrefs.data.antialiasing && character.jsonFile.no_antialiasing != true;
		}

		character.x = DialogueBoxPsych.LEFT_CHAR_X;
		character.y = DialogueBoxPsych.DEFAULT_CHAR_Y;
		switch(character.jsonFile.dialogue_pos)
		{
			case 'right':
				character.x = FlxG.width - character.width + DialogueBoxPsych.RIGHT_CHAR_X;
			case 'center':
				character.x = FlxG.width / 2 - character.width / 2;
		}
		character.x += character.jsonFile.position[0];
		character.y += character.jsonFile.position[1];
		ghostLoop.setPosition(character.x, character.y);
		ghostIdle.setPosition(character.x, character.y);

		var anims:Array<DialogueAnimArray> = character.jsonFile.animations;
		if(anims.length > 0)
		{
			if(curSelectedAnim == null || !character.dialogueAnimations.exists(curSelectedAnim)) curSelectedAnim = anims[0].anim;
			selectGhostAnim(curSelectedAnim);
		}
		playExpression();

		#if DISCORD_ALLOWED
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		DiscordClient.changePresence("Dialogue Editor", "Editting: " + portraitName());
		#end
	}

	function selectGhostAnim(anim:String) {
		if(!character.dialogueAnimations.exists(anim)) return;
		curSelectedAnim = anim;
		ghostLoop.playAnim(anim);
		ghostIdle.playAnim(anim, true);
		var animShit:DialogueAnimArray = character.dialogueAnimations.get(anim);
		offsetLoopText.text = 'Loop: ' + animShit.loop_offsets;
		offsetIdleText.text = 'Idle: ' + animShit.idle_offsets;
	}

	function playExpression() {
		var anims:Array<DialogueAnimArray> = character.jsonFile.animations;
		if(anims == null || anims.length < 1)
		{
			animText.text = 'ERROR! NO ANIMATIONS FOUND';
			return;
		}
		if(curAnim < 0 || curAnim >= anims.length) curAnim = 0;

		var animToPlay:String = anims[curAnim].anim;
		if(character.dialogueAnimations.exists(animToPlay)) character.playAnim(animToPlay, daText.finishedText);
		characterAnimSpeed();
		animText.text = 'Animation: $animToPlay (${curAnim + 1} / ${anims.length}) - Press W or S to scroll';
	}

	function updateTextBox() {
		box.flipX = false;
		var isAngry:Bool = angryCheckbox.checked;
		var anim:String = isAngry ? 'angry' : 'normal';

		switch(character.jsonFile.dialogue_pos) {
			case 'left':
				box.flipX = true;
			case 'center':
				anim = isAngry ? 'center-angry' : 'center';
		}
		box.animation.play(anim, true);
		DialogueBoxPsych.updateBoxOffsets(box);
	}

	function reloadText(skipDialogue:Bool) {
		var textToType:String = lineInputText.text;
		if(textToType == null || textToType.length < 1) textToType = ' ';

		daText.text = textToType;

		if(skipDialogue)
			daText.finishText();
		else if(daText.delay > 0)
			playExpression();

		daText.y = DialogueBoxPsych.DEFAULT_TEXT_Y;
		if(daText.rows > 2) daText.y -= DialogueBoxPsych.LONG_TEXT_ADD;
	}

	function characterAnimSpeed() {
		if(character.animation.curAnim == null) return;

		var rate:Float = 24 - (((speedStepper.value - 0.05) / 5) * 480);
		character.animation.curAnim.frameRate = FlxMath.bound(rate, 12, 48);
	}

	function changeText(add:Int = 0) {
		curSelected = FlxMath.wrap(curSelected + add, 0, dialogueFile.dialogue.length - 1);

		var curDialogue:DialogueLine = dialogueFile.dialogue[curSelected];
		if(curDialogue.sound == null) curDialogue.sound = '';
		portraitInputText.text = curDialogue.portrait;
		lineInputText.text = curDialogue.text;
		angryCheckbox.checked = (curDialogue.boxState == 'angry');
		speedStepper.value = curDialogue.speed;
		soundInputText.text = curDialogue.sound;

		daText.delay = speedStepper.value;
		daText.sound = (curDialogue.sound.trim() == '') ? 'dialogue' : curDialogue.sound;

		curAnim = 0;
		loadPortraitFile(portraitName());
		for (num => animData in character.jsonFile.animations)
		{
			if(animData != null && animData.anim == curDialogue.expression)
			{
				curAnim = num;
				break;
			}
		}

		reloadText(false);
		updateTextBox();
		playExpression();

		selectedText.text = 'Line: (${curSelected + 1} / ${dialogueFile.dialogue.length}) - Press A or D to scroll';
	}

	public function UIEvent(id:String, sender:Dynamic) {
		if(id == PsychUICheckBox.CLICK_EVENT)
			unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT && (sender is PsychUIInputText))
		{
			if(sender == portraitInputText)
			{
				dialogueFile.dialogue[curSelected].portrait = portraitInputText.text;
				curAnim = 0;
				loadPortraitFile(portraitName());
				reloadText(false);
				updateTextBox();
				unsavedProgress = true;
			}
			else if(sender == lineInputText)
			{
				dialogueFile.dialogue[curSelected].text = lineInputText.text;
				reloadText(true);
				unsavedProgress = true;
			}
			else if(sender == soundInputText)
			{
				daText.finishText();
				dialogueFile.dialogue[curSelected].sound = soundInputText.text;
				daText.sound = soundInputText.text;
				if(daText.sound == null) daText.sound = '';
				unsavedProgress = true;
			}
			else if(sender == imageInputText)
			{
				var image:String = imageInputText.text.trim();
				if(Paths.fileExists('images/dialogue/$image.png', IMAGE))
					editPortrait(function(file) file.image = image);
			}
		}
		else if(id == PsychUINumericStepper.CHANGE_EVENT)
		{
			if(sender == speedStepper)
			{
				var speed:Float = speedStepper.value;
				if(Math.isNaN(speed) || speed < 0.001) speed = 0.0;
				dialogueFile.dialogue[curSelected].speed = speed;
				daText.delay = speed;
				reloadText(false);
				unsavedProgress = true;
			}
			else if(sender == xStepper) editPortrait(function(file) file.position[0] = xStepper.value);
			else if(sender == yStepper) editPortrait(function(file) file.position[1] = yStepper.value);
			else if(sender == scaleStepper) editPortrait(function(file) file.scale = scaleStepper.value);
		}
	}

	override function update(elapsed:Float) {
		if(transitioning)
		{
			super.update(elapsed);
			return;
		}

		if(FlxG.mouse.justPressed || FlxG.mouse.justPressedRight)
			FlxG.sound.play(Paths.sound('chartingSounds/ClickDown'), 0.75);
		if(FlxG.mouse.justReleased || FlxG.mouse.justReleasedRight)
			FlxG.sound.play(Paths.sound('chartingSounds/ClickUp'), 0.75);

		if(character.animation.curAnim != null)
		{
			if(daText.finishedText)
			{
				if(character.animationIsLoop() && character.animation.curAnim.finished)
					character.playAnim(character.animation.curAnim.name, true);
			}
			else if(character.animation.curAnim.finished)
				character.animation.curAnim.restart();
		}

		if(PsychUIInputText.focusOn == null)
		{
			ClientPrefs.toggleVolumeKeys(true);
			if(FlxG.keys.pressed.CONTROL)
			{
				if(FlxG.keys.justPressed.S) saveDialogue();
			}
			else if(FlxG.keys.justPressed.ESCAPE)
			{
				exitEditor();
				super.update(elapsed);
				return;
			}
			else
			{
				updateCamera(elapsed);
				if(UI_box.selectedName != lastTab) switchTabView(UI_box.selectedName);
				if(UI_box.selectedName == 'Animations') updateOffsetKeys();
				else updateLineKeys();
			}
		}
		else ClientPrefs.toggleVolumeKeys(false);

		ghostLoop.setPosition(character.x, character.y);
		ghostIdle.setPosition(character.x, character.y);
		super.update(elapsed);
	}

	function updateCamera(elapsed:Float) {
		var speed:Float = FlxG.keys.pressed.SHIFT ? 1200 : 300;
		if(FlxG.keys.pressed.J) camGame.scroll.x -= speed * elapsed;
		if(FlxG.keys.pressed.L) camGame.scroll.x += speed * elapsed;
		if(FlxG.keys.pressed.I) camGame.scroll.y -= speed * elapsed;
		if(FlxG.keys.pressed.K) camGame.scroll.y += speed * elapsed;

		if(FlxG.keys.pressed.Q && camGame.zoom > 0.1) camGame.zoom = Math.max(0.1, camGame.zoom - elapsed * camGame.zoom);
		if(FlxG.keys.pressed.E && camGame.zoom < 1) camGame.zoom = Math.min(1, camGame.zoom + elapsed * camGame.zoom);
		if(FlxG.keys.justPressed.R)
		{
			camGame.zoom = 1;
			camGame.scroll.set();
			box.visible = daText.visible = true;
		}
	}

	function switchTabView(tab:String) {
		var offsets:Bool = (tab == 'Animations');
		character.alpha = box.alpha = daText.alpha = offsets ? 0 : 1;
		ghostLoop.visible = ghostIdle.visible = true;
		ghostLoop.alpha = ghostIdle.alpha = offsets ? 0.6 : 0;
		offsetLoopText.visible = offsetIdleText.visible = offsets;
		selectedText.visible = animText.visible = !offsets;
		tipText.text = offsets ? TIP_TEXT_OFFSET : TIP_TEXT_LINE;
		currentGhosts = 0;
		if(offsets && curSelectedAnim != null) selectGhostAnim(curSelectedAnim);
		else if(!offsets)
		{
			updateTextBox();
			reloadText(false);
		}
		lastTab = tab;
	}

	function updateLineKeys() {
		if(FlxG.keys.justPressed.SPACE) reloadText(false);
		if(FlxG.keys.justPressed.H) box.visible = daText.visible = !box.visible;

		var anims:Array<DialogueAnimArray> = character.jsonFile.animations;
		var animMove:Int = (FlxG.keys.justPressed.S ? 1 : 0) - (FlxG.keys.justPressed.W ? 1 : 0);
		if(animMove != 0 && anims.length > 0)
		{
			curAnim = FlxMath.wrap(curAnim + animMove, 0, anims.length - 1);
			dialogueFile.dialogue[curSelected].expression = anims[curAnim].anim;
			unsavedProgress = true;
			playExpression();
		}

		var lineMove:Int = (FlxG.keys.justPressed.D ? 1 : 0) - (FlxG.keys.justPressed.A ? 1 : 0);
		if(lineMove != 0) changeText(lineMove);

		if(FlxG.keys.justPressed.O)
		{
			dialogueFile.dialogue.remove(dialogueFile.dialogue[curSelected]);
			if(dialogueFile.dialogue.length < 1) dialogueFile.dialogue = [copyDefaultLine()];
			unsavedProgress = true;
			changeText();
		}
		else if(FlxG.keys.justPressed.P)
		{
			dialogueFile.dialogue.insert(curSelected + 1, copyDefaultLine());
			unsavedProgress = true;
			changeText(1);
		}
	}

	function updateOffsetKeys() {
		if(FlxG.keys.justPressed.H)
		{
			currentGhosts = (currentGhosts + 1) % 3;
			ghostLoop.visible = (currentGhosts != 1);
			ghostIdle.visible = (currentGhosts != 2);
			ghostLoop.alpha = (currentGhosts == 2 ? 1 : 0.6);
			ghostIdle.alpha = (currentGhosts == 1 ? 1 : 0.6);
		}

		if(curSelectedAnim == null || !character.dialogueAnimations.exists(curSelectedAnim)) return;

		var add:Int = FlxG.keys.pressed.SHIFT ? 10 : 1;
		var animShit:DialogueAnimArray = character.dialogueAnimations.get(curSelectedAnim);
		var loopX:Int = (FlxG.keys.justPressed.A ? add : 0) - (FlxG.keys.justPressed.D ? add : 0);
		var loopY:Int = (FlxG.keys.justPressed.W ? add : 0) - (FlxG.keys.justPressed.S ? add : 0);
		var idleX:Int = (FlxG.keys.justPressed.LEFT ? add : 0) - (FlxG.keys.justPressed.RIGHT ? add : 0);
		var idleY:Int = (FlxG.keys.justPressed.UP ? add : 0) - (FlxG.keys.justPressed.DOWN ? add : 0);
		if(loopX == 0 && loopY == 0 && idleX == 0 && idleY == 0) return;

		animShit.loop_offsets[0] += loopX;
		animShit.loop_offsets[1] += loopY;
		animShit.idle_offsets[0] += idleX;
		animShit.idle_offsets[1] += idleY;
		markPortraitEdited();
		offsetLoopText.text = 'Loop: ' + animShit.loop_offsets;
		offsetIdleText.text = 'Idle: ' + animShit.idle_offsets;
		ghostLoop.offset.set(animShit.loop_offsets[0], animShit.loop_offsets[1]);
		ghostIdle.offset.set(animShit.idle_offsets[0], animShit.idle_offsets[1]);
	}

	function exitEditor() {
		if(!unsavedProgress)
		{
			@:privateAccess EditorHelper.cancelEditorMusicTimer();
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			transitioning = true;
			EditorHelper.returnToPreviousState();
		}
		else openSubState(new ExitConfirmationPrompt(function() {
			@:privateAccess EditorHelper.cancelEditorMusicTimer();
			transitioning = true;
		}));
	}

	function showMessage(text:String, ?error:Bool = false) {
		messageText.text = text;
		messageText.y = FlxG.height - messageText.height - 8;
		messageText.color = error ? FlxColor.RED : FlxColor.WHITE;
		messageText.alpha = 1;
		FlxTween.cancelTweensOf(messageText);
		FlxTween.tween(messageText, {alpha: 0}, 1, {startDelay: 2});
	}

	function loadDialogue() {
		if(!fileDialog.completed) return;
		fileDialog.open('dialogue.json', 'Load Dialogue', null, function() {
			try
			{
				var loaded:DialogueFile = cast Json.parse(fileDialog.data);
				if(loaded.dialogue != null && loaded.dialogue.length > 0)
				{
					dialogueFile = loaded;
					curSelected = 0;
					changeText();
					unsavedProgress = false;
					showMessage('Loaded: ' + Path.withoutDirectory(fileDialog.path));
					return;
				}
			}
			catch(e:Dynamic) {}
			showMessage('ERROR: Not a valid dialogue file.', true);
		});
	}

	function loadPortrait() {
		if(!fileDialog.completed) return;
		fileDialog.open(null, 'Load Portrait', null, function() {
			try
			{
				var loaded:DialogueCharacterFile = cast Json.parse(fileDialog.data);
				if(loaded.dialogue_pos != null)
				{
					var name:String = Path.withoutExtension(Path.withoutDirectory(fileDialog.path));
					editedPortraits.set(name, loaded);
					dialogueFile.dialogue[curSelected].portrait = name;
					portraitInputText.text = name;
					unsavedProgress = true;
					curAnim = 0;
					loadPortraitFile(name);
					reloadText(false);
					updateTextBox();
					showMessage('Loaded portrait: $name');
					return;
				}
			}
			catch(e:Dynamic) {}
			showMessage('ERROR: Not a valid portrait file.', true);
		});
	}

	function saveDialogue() {
		if(!fileDialog.completed) return;
		fileDialog.save('dialogue.json', Json.stringify(dialogueFile, '\t'), function() {
			var count:Int = Lambda.count(editedPortraits);
			var saved:Int = savePortraits(fileDialog.path);
			if(saved < count)
			{
				showMessage('ERROR: Dialogue saved, but ${count - saved} portrait(s) not saved.', true);
				return;
			}
			unsavedProgress = false;
			var message:String = 'Saved: ' + Path.withoutDirectory(fileDialog.path);
			if(saved > 0) message += ' + $saved portrait' + (saved == 1 ? '' : 's');
			showMessage(message);
		}, null, function() showMessage('ERROR: Dialogue not saved.', true));
	}

	function savePortraits(dialoguePath:String):Int {
		#if sys
		if(dialoguePath == null || dialoguePath.length < 1) return 0;
		var normalized:String = dialoguePath.replace('\\', '/');
		var dataIndex:Int = normalized.lastIndexOf('/data/');
		var folder:String = (dataIndex > -1) ? normalized.substr(0, dataIndex) + '/images/dialogue' : Path.directory(normalized);

		var saved:Int = 0;
		for (name in [for (key in editedPortraits.keys()) key])
		{
			try
			{
				if(!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
				File.saveContent('$folder/$name.json', Json.stringify(editedPortraits.get(name), '\t'));
				editedPortraits.remove(name);
				saved++;
			}
			catch(e:Dynamic) trace('Couldn\'t save portrait "$name": $e');
		}
		return saved;
		#else
		return 0;
		#end
	}
}
