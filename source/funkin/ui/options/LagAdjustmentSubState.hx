package funkin.ui.options;

import openfl.events.KeyboardEvent;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.effects.FlxFlicker;
import funkin.data.Song.SwagSong;
import funkin.game.notes.Note;
import funkin.game.notes.StrumNote;
import funkin.game.notes.NoteSplash;
import funkin.game.states.PauseSubState;

typedef LatencyArrow =
{
	var sprite:FlxSprite;
	var beat:Float;
}

typedef LatencyNote =
{
	var note:Note;
	var time:Float;
	var direction:Int;
}

typedef LatencyPress =
{
	var direction:Int;
	var time:Float;
}

class LagAdjustmentSubState extends MusicBeatSubstate
{
	static inline final BPM:Float = 100;
	static final MS_PER_BEAT:Float = 60000 / BPM;
	static inline final MUSIC:String = 'offsetsLoop/offsetsLoop';
	static inline final DRUMS:String = 'offsetsLoop/drumsLoop';
	static inline final OFFSET_MIN:Int = -1500;
	static inline final OFFSET_MAX:Int = 1500;
	static inline final PIXELS_PER_MS:Float = 0.45;
	static inline final CALIBRATION_SPEED:Float = 2;
	static inline final TEST_SPEED:Float = 1;
	static inline final TEST_LEAD_BEATS:Float = 3;
	static inline final HIT_WINDOW:Float = 160;
	static inline final RESYNC_LIMIT:Float = 50;
	static inline final CALIBRATION_HITS:Int = 30;
	static inline final ARROW_HITS:Int = 8;
	static inline final MAX_INCONSISTENCY:Float = 40;
	static inline final ARROW_HIT_RANGE:Float = 80;
	static inline final ARROW_FADE_MS:Float = 180;
	static inline final GREAT_RANGE:Float = 45;
	static inline final MISSED_ALPHA:Float = 0.5;
	static inline final HOLD_DELAY:Float = 0.3;
	static inline final CHANGE_RATE:Float = 0.08;
	static inline final ITEM_SPACING:Float = 120;
	static inline final ITEM_GAP:Float = 20;
	static inline final VALUE_Y_OFFSET:Float = -52;
	static inline final MUSIC_FADE:Float = 0.5;
	static final NOTE_KEYS:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];

	static var previousVolume:Float = 1;

	var blackRect:FlxSprite;
	var receptor:FlxSprite;
	var jumpInText:FlxText;
	var countText:FlxText;
	var items:Array<Alphabet> = [];
	var valueText:Alphabet;
	var curSelected:Int = 0;
	var menuBusy:Bool = false;

	var arrowGroup:FlxTypedGroup<FlxSprite>;
	var arrows:Array<LatencyArrow> = [];
	var strums:FlxTypedGroup<StrumNote>;
	var notes:FlxTypedGroup<Note>;
	var splashes:FlxTypedGroup<NoteSplash>;
	var testNotes:Array<LatencyNote> = [];

	var drums:FlxSound;
	var musicReady:Bool = false;
	var closed:Bool = false;
	var songPosition:Float = 0;
	var loopCount:Int = 0;
	var lastMusicTime:Float = 0;

	var mode:Int = 0;
	var calibrating:Bool = false;
	var canExit:Bool = true;
	var savedOffset:Int = 0;
	var tempOffset:Int = 0;
	var appliedOffsetLerp:Float = 0;
	var lastOffset:Float = 0;
	var offsetLerpTime:Float = 1;
	var lerped:Float = 0;
	var offsetLerp:Float = 0;
	var scaleModifier:Float = 1;
	var arrowBeat:Float = 0;
	var lastDirection:Int = 0;
	var gotMad:Bool = false;
	var differences:Array<Float> = [];
	var pressQueue:Array<LatencyPress> = [];
	var releaseQueue:Array<Int> = [];
	var heldKeys:Map<Int, Bool> = new Map();
	var holdDelay:Float = HOLD_DELAY;
	var changeTimer:Float = 0;

	var savedStageUI:String;
	var savedSong:SwagSong;

	public function new()
	{
		super();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Lag Adjustment", null);
		#end

		savedStageUI = PlayState.stageUI;
		savedSong = PlayState.SONG;
		PlayState.stageUI = 'normal';
		PlayState.SONG = null;
		Note.globalRgbShaders = [];

		blackRect = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackRect.scale.set(FlxG.width + 50, FlxG.height + 50);
		blackRect.updateHitbox();
		blackRect.screenCenter();
		blackRect.scrollFactor.set();
		blackRect.alpha = 0;
		add(blackRect);

		receptor = new FlxSprite().loadGraphic(Paths.image('latencyReceptor'));
		receptor.antialiasing = ClientPrefs.data.antialiasing;
		receptor.scrollFactor.set();
		receptor.setPosition((FlxG.width - receptor.frameWidth) / 2, (FlxG.height - receptor.frameHeight) / 2);
		receptor.scale.set(0, 0);
		receptor.alpha = 0;
		add(receptor);

		arrowGroup = new FlxTypedGroup<FlxSprite>();
		add(arrowGroup);

		strums = new FlxTypedGroup<StrumNote>();
		add(strums);
		notes = new FlxTypedGroup<Note>();
		add(notes);
		splashes = new FlxTypedGroup<NoteSplash>();
		add(splashes);

		var strumY:Float = ClientPrefs.data.downScroll ? FlxG.height - 150 : 50;
		for (i in 0...NOTE_KEYS.length)
		{
			var strum:StrumNote = new StrumNote(PlayState.STRUM_X_MIDDLESCROLL, strumY, i, 1);
			strum.downScroll = ClientPrefs.data.downScroll;
			strum.scrollFactor.set();
			strum.playerPosition();
			strum.alpha = 0;
			strums.add(strum);
		}

		var splash:NoteSplash = new NoteSplash();
		splash.alpha = 0.0001;
		splashes.add(splash);

		jumpInText = makeText(150);
		countText = makeText(600);

		valueText = new Alphabet(0, 0, '', false);
		valueText.scrollFactor.set();
		add(valueText);
		for (label in [
			Language.getPhrase('lag_offset_global', 'Offset (Global)'),
			Language.getPhrase('lag_reset_offset', 'Reset Offset'),
			Language.getPhrase('lag_offset_calibration', 'Offset Calibration'),
			Language.getPhrase('lag_test', 'Test')
		])
		{
			var item:Alphabet = new Alphabet(0, 0, label, true);
			item.scrollFactor.set();
			items.push(item);
			add(item);
		}
		refreshValue();
		changeSelection();
		layout();

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		startMusic();
	}

	function makeText(y:Float):FlxText
	{
		var text:FlxText = new FlxText(0, y, 0, '', 32);
		text.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		text.borderSize = 4;
		text.scrollFactor.set();
		text.alpha = 0;
		add(text);
		return text;
	}

	function getGlobalOffset():Int
		return -ClientPrefs.data.noteOffset;

	function setGlobalOffset(value:Int)
		ClientPrefs.data.noteOffset = -Std.int(FlxMath.bound(value, OFFSET_MIN, OFFSET_MAX));

	function refreshValue()
		valueText.text = Std.string(getGlobalOffset());

	function startMusic()
	{
		previousVolume = FlxG.sound.music != null ? FlxG.sound.music.volume : 1;
		if(FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.fadeOut(MUSIC_FADE, 0, (_) -> playLoops());
		else
			playLoops();
	}

	function playLoops()
	{
		if(closed) return;
		FlxG.sound.playMusic(Paths.music(MUSIC), 0, true);
		drums = new FlxSound().loadEmbedded(Paths.music(DRUMS), true);
		FlxG.sound.list.add(drums);
		drums.volume = 0;
		drums.play(true);
		FlxG.sound.music.fadeIn(1, 0, 1);
		songPosition = 0;
		loopCount = 0;
		lastMusicTime = 0;
		musicReady = true;
	}

	function fadeOutLoops()
	{
		var drumSound:FlxSound = drums;
		drums = null;
		if(drumSound != null)
		{
			drumSound.fadeOut(MUSIC_FADE, 0, (_) -> {
				drumSound.stop();
				FlxG.sound.list.remove(drumSound, true);
				drumSound.destroy();
			});
		}

		if(FlxG.sound.music == null) return;
		if(musicReady) FlxG.sound.music.fadeOut(MUSIC_FADE, 0, (_) -> restoreMusic());
		else FlxG.sound.music.fadeIn(MUSIC_FADE, FlxG.sound.music.volume, previousVolume);
	}

	static function restoreMusic()
	{
		if(!Std.isOfType(FlxG.state, OptionsState)) return;
		if(!OptionsState.onPlayState) FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		else if(PauseSubState.currentSong != null) FlxG.sound.playMusic(Paths.music(PauseSubState.currentSong), 0);
		else
		{
			FlxG.sound.music.stop();
			return;
		}
		FlxG.sound.music.fadeIn(MUSIC_FADE, 0, previousVolume);
	}

	function musicTime():Float
		return loopCount * FlxG.sound.music.length + FlxG.sound.music.time;

	function updateClock(elapsed:Float)
	{
		if(!musicReady || FlxG.sound.music == null) return;

		if(FlxG.sound.music.time < lastMusicTime - FlxG.sound.music.length / 2) loopCount++;
		lastMusicTime = FlxG.sound.music.time;

		songPosition += elapsed * 1000;
		var target:Float = musicTime();
		if(Math.abs(target - songPosition) > RESYNC_LIMIT) songPosition = target;
		if(drums != null && Math.abs(drums.time - FlxG.sound.music.time) > RESYNC_LIMIT) drums.time = FlxG.sound.music.time;
	}

	function onKeyDown(event:KeyboardEvent)
	{
		if(mode != 1 || !musicReady) return;
		var key:FlxKey = event.keyCode;
		if(heldKeys.exists(key) || isBound('back', key)) return;
		heldKeys.set(key, true);
		pressQueue.push({direction: noteDirection(key), time: musicTime()});
	}

	function onKeyUp(event:KeyboardEvent)
	{
		var key:FlxKey = event.keyCode;
		heldKeys.remove(key);
		var direction:Int = noteDirection(key);
		if(direction > -1) releaseQueue.push(direction);
	}

	function isBound(control:String, key:FlxKey):Bool
	{
		var binds:Array<FlxKey> = ClientPrefs.keyBinds.get(control);
		return binds != null && binds.contains(key);
	}

	function noteDirection(key:FlxKey):Int
	{
		for (direction => control in NOTE_KEYS) if(isBound(control, key)) return direction;
		return -1;
	}

	function gamepadInput(justPressed:Bool)
	{
		if(mode != 1 || !musicReady || FlxG.gamepads.numActiveGamepads < 1) return;
		for (direction => control in NOTE_KEYS)
		{
			var buttons:Array<FlxGamepadInputID> = ClientPrefs.gamepadBinds.get(control);
			if(buttons == null) continue;
			for (button in buttons)
			{
				if(justPressed && FlxG.gamepads.anyJustPressed(button)) pressQueue.push({direction: direction, time: musicTime()});
				else if(!justPressed && FlxG.gamepads.anyJustReleased(button)) releaseQueue.push(direction);
			}
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		updateClock(elapsed);
		gamepadInput(true);
		gamepadInput(false);
		var beat:Float = songPosition / MS_PER_BEAT;

		if(mode == 1 && controls.BACK)
			exitCalibration(true);
		else if(mode == 1 && calibrating)
			updateCalibration(elapsed, beat);
		else if(mode == 1)
			updateTest(beat);
		else
			fadeArrows(elapsed);

		if(mode != 1)
		{
			pressQueue = [];
			releaseQueue = [];
		}

		positionNotes();
		updateTransitions(elapsed);
		layout();

		if(mode == 0 && !closed) updateMenu(elapsed);
	}

	function updateMenu(elapsed:Float)
	{
		if(menuBusy) return;

		if(controls.UI_UP_P) changeSelection(-1);
		if(controls.UI_DOWN_P) changeSelection(1);
		if(curSelected == 0) updateValue(elapsed);

		if(controls.ACCEPT) accept();
		else if(canExit && controls.BACK) leave();
	}

	function updateValue(elapsed:Float)
	{
		holdDelay -= elapsed;
		if(holdDelay <= 0) changeTimer -= elapsed;

		var decrease:Bool = controls.UI_LEFT_P;
		var increase:Bool = controls.UI_RIGHT_P;
		if(decrease || increase)
		{
			holdDelay = HOLD_DELAY;
			changeTimer = 0;
		}

		if(holdDelay <= 0 && changeTimer <= 0)
		{
			if(controls.UI_LEFT)
			{
				decrease = true;
				changeTimer = CHANGE_RATE;
			}
			else if(controls.UI_RIGHT)
			{
				increase = true;
				changeTimer = CHANGE_RATE;
			}
		}

		if(decrease || increase)
		{
			setGlobalOffset(getGlobalOffset() + (increase ? 1 : -1));
			refreshValue();
		}
	}

	function changeSelection(change:Int = 0)
	{
		if(change != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, items.length - 1);
		for (i => item in items) item.alpha = (i == curSelected) ? 1 : 0.6;
	}

	function accept()
	{
		if(curSelected == 0) return;

		var action:Void->Void = switch(curSelected)
		{
			case 1: resetOffset;
			case 2: startCalibration;
			default: startTest;
		}
		menuBusy = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		FlxFlicker.flicker(items[curSelected], 1, 0.06, true, false, (_) -> {
			menuBusy = false;
			if(!closed) action();
		});
	}

	function leave()
	{
		closed = true;
		canExit = false;
		FlxG.sound.play(Paths.sound('cancelMenu'));
		fadeOutLoops();
		close();
	}

	function resetOffset()
	{
		setGlobalOffset(0);
		refreshValue();
	}

	function startCalibration()
	{
		if(!musicReady) return;
		clearTestNotes();
		jumpInText.text = Language.getPhrase('lag_press_beat', 'Press any key to the beat!');
		jumpInText.y = 100;
		countText.text = Language.getPhrase('lag_current_offset', 'Current Offset: {1}ms', [0]);

		calibrating = true;
		fadeInDrums();
		canExit = false;
		differences = [];
		offsetLerp = 0;
		savedOffset = getGlobalOffset();
		setGlobalOffset(0);
		mode = 1;
		tempOffset = 0;
		appliedOffsetLerp = 0;
		lastOffset = 0;
		offsetLerpTime = 1;
		arrowBeat = Math.floor(songPosition / MS_PER_BEAT) + 4;
		receptor.angle = 0;
		gotMad = false;
		pressQueue = [];
	}

	function startTest()
	{
		if(!musicReady) return;
		clearTestNotes();
		calibrating = false;
		mode = 1;
		songPosition = musicTime();
		fadeInDrums();

		var beat:Float = songPosition / MS_PER_BEAT;
		var floored:Int = Math.floor(beat);
		arrowBeat = floored - (floored % 4) + 4;
		if(arrowBeat - beat < 4) arrowBeat += 4;
		lastDirection = 0;

		jumpInText.text = Language.getPhrase('lag_hit_notes', 'Hit the notes as they come in!');
		jumpInText.y = ClientPrefs.data.downScroll ? FlxG.height - 425 : 350;
		canExit = false;
		differences = [];
		pressQueue = [];
	}

	function fadeInDrums()
	{
		if(drums == null) return;
		drums.time = FlxG.sound.music.time;
		drums.fadeIn(1, 0, 1);
	}

	function exitCalibration(cancel:Bool)
	{
		mode = -1;
		tempOffset = 0;
		if(cancel)
		{
			if(calibrating) setGlobalOffset(savedOffset);
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		else FlxG.sound.play(Paths.sound('confirmMenu'));
		refreshValue();
		if(drums != null) drums.fadeOut(1, 0);
		pressQueue = [];
		releaseQueue = [];
		for (strum in strums) strum.playAnim('static');
	}

	function addDifference(ms:Float)
	{
		differences.push(ms);
		if(differences.length % 4 == 0 && calibrating)
		{
			tempOffset = Std.int(getAverage());
			lastOffset = appliedOffsetLerp;
			offsetLerpTime = 0;
		}
	}

	function getAverage():Float
	{
		if(differences.length == 0) return 0;
		var total:Float = 0;
		for (difference in differences) total += difference;
		return total / differences.length;
	}

	function getConsistency():Float
	{
		if(differences.length == 0) return 0;
		var average:Float = getAverage();
		var variance:Float = 0;
		for (difference in differences) variance += Math.pow(difference - average, 2);
		return Math.sqrt(variance / differences.length);
	}

	function updateCalibration(elapsed:Float, beat:Float)
	{
		offsetLerpTime = Math.min(1, offsetLerpTime + elapsed * 2);
		appliedOffsetLerp = FlxMath.lerp(lastOffset, tempOffset, offsetLerpTime);
		countText.text = Language.getPhrase('lag_current_offset', 'Current Offset: {1}ms', [Std.int(appliedOffsetLerp)]);

		var lastArrowBeat:Float = -1;
		for (arrow in arrows.copy())
		{
			var time:Float = arrow.beat * MS_PER_BEAT - appliedOffsetLerp;
			arrow.sprite.x = (FlxG.width - arrow.sprite.width) / 2;
			arrow.sprite.y = FlxG.height / 2 + PIXELS_PER_MS * CALIBRATION_SPEED * (time - songPosition) - arrow.sprite.height / 2;
			if(time - songPosition < -ARROW_FADE_MS) arrow.sprite.alpha -= elapsed * 5;

			if(arrow.beat == lastArrowBeat || arrow.sprite.alpha <= 0) removeArrow(arrow);
			else lastArrowBeat = arrow.beat;
		}

		while(beat >= arrowBeat - 1)
		{
			arrowBeat = (arrowBeat - (arrowBeat % 2)) + 2;
			createArrow(arrowBeat);
		}

		while(pressQueue.length > 0 && mode == 1)
			calibrationHit(pressQueue.shift().time);
	}

	function calibrationHit(time:Float)
	{
		var beat:Float = time / MS_PER_BEAT;
		var ms:Float = (Math.round(beat) - beat) * MS_PER_BEAT;

		var arrow:LatencyArrow = closestArrow(beat);
		if(arrow != null && Math.abs((arrow.beat - beat) * MS_PER_BEAT - tempOffset) <= ARROW_HIT_RANGE) removeArrow(arrow);

		if(getConsistency() > MAX_INCONSISTENCY && differences.length > ARROW_HITS)
		{
			jumpInText.text = Language.getPhrase('lag_consistent', 'Try to be a little more consistent with your timing!');
			differences = [];
			tempOffset = 0;
			appliedOffsetLerp = 0;
			gotMad = true;
			return;
		}

		addDifference(ms);

		if(differences.length >= CALIBRATION_HITS)
		{
			jumpInText.text = Language.getPhrase('lag_complete', 'Calibration complete!');
			setGlobalOffset(tempOffset);
			exitCalibration(false);
			return;
		}

		if(!gotMad)
		{
			jumpInText.text = Math.abs(ms - tempOffset) < GREAT_RANGE ? Language.getPhrase('lag_great', 'Great job') : Language.getPhrase('lag_nice', 'Nice job');
			jumpInText.text += differences.length < ARROW_HITS ? Language.getPhrase('lag_keep_going', ', keep going!') : '!';
		}
		jumpInText.text += '\n${differences.length}/$CALIBRATION_HITS';

		gotMad = false;
		scaleModifier = 0.75;
	}

	function createArrow(beat:Float)
	{
		var sprite:FlxSprite = arrowGroup.recycle(FlxSprite);
		sprite.loadGraphic(Paths.image('latencyArrow'));
		sprite.antialiasing = ClientPrefs.data.antialiasing;
		sprite.scrollFactor.set();
		sprite.alpha = 1;
		sprite.setPosition((FlxG.width - sprite.width) / 2, FlxG.height + sprite.height);
		arrows.push({sprite: sprite, beat: beat});
	}

	function removeArrow(arrow:LatencyArrow)
	{
		arrow.sprite.kill();
		arrows.remove(arrow);
	}

	function closestArrow(beat:Float):LatencyArrow
	{
		var closest:LatencyArrow = null;
		for (arrow in arrows)
			if(closest == null || Math.abs(arrow.beat - beat) < Math.abs(closest.beat - beat)) closest = arrow;
		return closest;
	}

	function fadeArrows(elapsed:Float)
	{
		for (arrow in arrows.copy())
		{
			arrow.sprite.alpha -= elapsed * 5;
			if(arrow.sprite.alpha <= 0) removeArrow(arrow);
		}
	}

	function updateTest(beat:Float)
	{
		while(beat >= arrowBeat - TEST_LEAD_BEATS)
		{
			arrowBeat++;
			addTestNote(arrowBeat, lastDirection);
			if(Math.floor(arrowBeat % 8) == 0) addTestNote(arrowBeat, 2);
			lastDirection = (lastDirection + 1) % NOTE_KEYS.length;
		}

		while(pressQueue.length > 0)
		{
			var press:LatencyPress = pressQueue.shift();
			if(press.direction < 0) continue;

			var target:LatencyNote = null;
			for (test in testNotes)
				if(test.direction == press.direction && Math.abs(test.time - press.time) <= HIT_WINDOW && (target == null || test.time < target.time))
					target = test;

			var strum:StrumNote = strums.members[press.direction];
			if(target == null) strum.playAnim('pressed', true);
			else
			{
				hitTestNote(target, press.time);
				strum.playAnim('confirm', true);
			}
		}

		while(releaseQueue.length > 0)
			strums.members[releaseQueue.shift()].playAnim('static');
	}

	function addTestNote(beat:Float, direction:Int)
	{
		var time:Float = beat * MS_PER_BEAT + ClientPrefs.data.noteOffset;
		var note:Note = new Note(time, direction, null, false, true, this);
		note.mustPress = true;
		note.scrollFactor.set();
		notes.add(note);
		testNotes.push({note: note, time: time, direction: direction});
	}

	function hitTestNote(test:LatencyNote, pressTime:Float)
	{
		var difference:Int = Std.int(test.time - pressTime);
		addDifference(difference);

		if(difference == 0)
		{
			jumpInText.text = Language.getPhrase('lag_perfect', 'Perfect!') + '\n';
			var strum:StrumNote = strums.members[test.direction];
			var splash:NoteSplash = splashes.recycle(NoteSplash);
			splash.babyArrow = strum;
			splash.spawnSplashNote(strum.x, strum.y, test.direction, test.note);
		}
		else if(difference > 0)
			jumpInText.text = Language.getPhrase('lag_early', 'Early!') + '\n${difference}ms';
		else
			jumpInText.text = Language.getPhrase('lag_late', 'Late!') + '\n${difference}ms';

		jumpInText.text += '\n' + Language.getPhrase('lag_average', 'Avg: {1}ms', [Std.int(getAverage())]);
		removeTestNote(test);
	}

	function removeTestNote(test:LatencyNote)
	{
		testNotes.remove(test);
		notes.remove(test.note, true);
		test.note.destroy();
	}

	function clearTestNotes()
	{
		for (test in testNotes.copy()) removeTestNote(test);
	}

	function positionNotes()
	{
		var visibility:Float = FlxEase.cubeInOut(offsetLerp);
		for (test in testNotes.copy())
		{
			var strum:StrumNote = strums.members[test.direction];
			var distance:Float = PIXELS_PER_MS * TEST_SPEED * (test.time - songPosition);
			test.note.x = strum.x + test.note.offsetX;
			test.note.y = strum.y + test.note.offsetY + (strum.downScroll ? -distance : distance);
			test.note.alpha = visibility * (test.time - songPosition < -HIT_WINDOW ? MISSED_ALPHA : 1);

			var gone:Bool = strum.downScroll ? test.note.y > FlxG.height : test.note.y < -test.note.height;
			if(gone) removeTestNote(test);
		}
	}

	function updateTransitions(elapsed:Float)
	{
		lerped = Math.min(1, lerped + elapsed / 2);

		if(mode == 1) offsetLerp = Math.min(1, offsetLerp + elapsed / 2);
		else if(mode == -1)
		{
			offsetLerp -= elapsed / 3;
			if(offsetLerp <= 0)
			{
				offsetLerp = 0;
				mode = 0;
				canExit = true;
				calibrating = false;
				clearTestNotes();
			}
		}

		if(scaleModifier < 1) scaleModifier = Math.min(1, scaleModifier + elapsed / 2);
	}

	function layout()
	{
		var shown:Float = FlxEase.cubeInOut(offsetLerp);
		blackRect.alpha = FlxMath.lerp(0, 0.5, FlxEase.cubeInOut(lerped));

		jumpInText.x = (FlxG.width - jumpInText.width) / 2;
		countText.x = (FlxG.width - countText.width) / 2;
		jumpInText.alpha = shown;

		if(calibrating)
		{
			receptor.alpha = shown;
			countText.alpha = shown;
		}
		else for (strum in strums) strum.alpha = shown;
		receptor.scale.set(shown * scaleModifier, shown * scaleModifier);

		var yLerp:Float = FlxMath.lerp(-480, 100, FlxEase.cubeInOut(lerped));
		var xLerp:Float = FlxMath.lerp(0, FlxG.width, shown);
		for (i => item in items)
		{
			var y:Float = yLerp + ITEM_SPACING * i + 30;
			if(i == 0)
			{
				var total:Float = valueText.width + item.width + ITEM_GAP;
				valueText.setPosition(xLerp + (FlxG.width - total) / 2, y + VALUE_Y_OFFSET);
				item.setPosition(valueText.x + valueText.width + ITEM_GAP, y);
			}
			else item.setPosition(xLerp + (FlxG.width - item.width) / 2, y);
		}
	}

	override function destroy()
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		if(mode == 1 && calibrating) setGlobalOffset(savedOffset);
		if(!closed)
		{
			closed = true;
			fadeOutLoops();
		}
		PlayState.stageUI = savedStageUI;
		PlayState.SONG = savedSong;
		Note.globalRgbShaders = [];
		super.destroy();
	}
}
