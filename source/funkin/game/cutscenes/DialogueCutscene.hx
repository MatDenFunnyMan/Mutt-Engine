package funkin.game.cutscenes;

import flixel.FlxBasic;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;
import flixel.input.keyboard.FlxKey;
import funkin.data.DialogueData;

class DialogueCutscene extends FlxGroup
{
	public static inline final SHAKE_LINE:Float = -1;
	public static inline final SHAKE_SCENE:Float = -2;

	public var data:DialogueFileData;
	public var style:DialogueStyleData;
	public var name:String;
	public var sceneIndex(default, null):Int = 0;
	public var running(default, null):Bool = false;
	public var finished(default, null):Bool = false;

	public var onFinish:Bool->Void = null;
	public var onScene:Int->DialogueScene->Void = null;
	public var onCustom:String->DialogueScene->Void = null;
	public var colorResolver:String->Null<FlxColor> = null;
	public var registerObject:String->FlxBasic->Void = null;
	public var inputEnabled:Bool = true;
	public var playAudio:Bool = true;
	public var playVoices:Bool = true;

	public var backgrounds:Map<String, FlxSprite> = [];
	public var characters:Map<String, DialogueCharacterData> = [];
	public var portraits:Map<String, FlxSprite> = [];
	public var black:FlxSprite;
	public var box:FlxSprite;
	public var overlay:FlxSprite;
	public var nametag:FlxSprite;
	public var nameText:FlxText;
	public var text:FlxText;
	public var hint:FlxText;
	public var skipHint:FlxText;

	var cam:FlxCamera;
	var boxY:Float = 430;
	var defaultSpeed:Float = 0.05;
	var minVoiceGap:Float = 0.05;
	var voiceVolume:Float = 0.75;
	var skipKey:FlxKey = FlxKey.X;

	var canInteract:Bool = false;
	var autoSkip:Dynamic = false;
	var isTyping:Bool = false;
	var finalText:String = '';
	var charNum:Int = 0;
	var typeTimer:Float = 0;
	var speed:Float = 0.05;
	var centered:Bool = false;
	var voice:String = '';
	var voicePitch:Float = 1;
	var voiceStep:Int = 1;
	var voiceCount:Int = 0;
	var shakeAmount:Float = 0;
	var shakeLeft:Float = 0;
	var waitTimer:Float = -1;
	var waitingCustom:Bool = false;

	var track:FlxSound;
	var trackName:String = '';
	var trackVolume:Float = 0;
	var sfx:FlxSound;
	var sfxName:String = '';
	var sfxVolume:Float = 0;
	var pendingSfx:DialogueAudio = null;
	var sfxDelay:Float = -1;
	var sfxLife:Float = -1;
	var hintTween:FlxTween;
	var tweens:Array<FlxTween> = [];

	public function new(data:DialogueFileData, cam:FlxCamera, ?name:String = 'dialogue')
	{
		super();
		this.data = data;
		this.cam = cam;
		this.name = name;
		style = DialogueData.style(data.style);
		cameras = [cam];

		boxY = num(style.boxY, 430);
		defaultSpeed = num(style.speed, 0.05);
		minVoiceGap = num(style.minVoiceGap, 0.05);
		voiceVolume = num(style.voiceVolume, 0.75);
		var key:Null<FlxKey> = FlxKey.fromString(str(style.skipKey, 'X').toUpperCase());
		if(key != null && key != FlxKey.NONE) skipKey = key;

		var bgList:Array<DialogueBackground> = [];
		if(style.backgrounds != null) bgList = bgList.concat(style.backgrounds);
		if(data.backgrounds != null) bgList = bgList.concat(data.backgrounds);
		for (bg in bgList) addBackground(bg);

		for (scene in data.scenes)
			if(scene != null && scene.character != null && !characters.exists(scene.character))
				loadCharacter(scene.character);

		nametag = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		nametag.color = colorOf(str(style.nametagColor, '000000'), FlxColor.BLACK);
		add(nametag);

		box = makeImage(str(style.box, 'dialogue/fill'), 0, boxY);
		box.screenCenter(X);
		if(style.boxX != null) box.x = style.boxX;
		add(box);
		overlay = makeImage(str(style.overlay, 'dialogue/boxOverlay'), 0, boxY);
		overlay.x = box.x + (box.width - overlay.width) / 2;
		add(overlay);

		nameText = new FlxText(0, 0, 500, '');
		nameText.setFormat(Paths.font(str(style.nameFont, 'vcr.ttf')), Std.int(num(style.nameSize, 75)), FlxColor.WHITE, LEFT);
		add(nameText);

		text = new FlxText(0, 0, Std.int(num(style.textWidth, 1100)), '');
		text.setFormat(Paths.font(str(style.font, 'vcr.ttf')), Std.int(num(style.textSize, 40)), FlxColor.WHITE, LEFT);
		add(text);

		var hintOffset:Array<Float> = (style.hintOffset != null) ? style.hintOffset : [50, 200];
		hint = new FlxText(box.x + hintOffset[0], boxY + hintOffset[1], 1100, str(style.hint, 'PRESS SPACE TO FORWARD'));
		hint.setFormat(Paths.font(str(style.hintFont, 'vcr.ttf')), Std.int(num(style.hintSize, 20)), FlxColor.WHITE, RIGHT);
		add(hint);

		var skipPos:Array<Float> = (style.skipHintPosition != null) ? style.skipHintPosition : [1100, 40];
		skipHint = new FlxText(skipPos[0], skipPos[1], 800, str(style.skipHint, '(X to SKIP)'));
		skipHint.setFormat(Paths.font(str(style.skipHintFont, 'vcr.ttf')), Std.int(num(style.skipHintSize, 30)), FlxColor.WHITE, LEFT);
		add(skipHint);

		black = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		black.alpha = 0;
		add(black);

		var borderSize:Float = num(style.borderSize, 2);
		var borderColor:FlxColor = colorOf(str(style.borderColor, '000000'), FlxColor.BLACK);
		for (label in [nameText, text, hint, skipHint])
			label.setBorderStyle((borderSize > 0) ? OUTLINE : NONE, borderColor, borderSize);

		var antialias:Bool = data.antialiasing != false && ClientPrefs.data.antialiasing;
		for (member in members)
		{
			if(member == null) continue;
			var sprite:FlxSprite = cast member;
			sprite.scrollFactor.set();
			sprite.antialiasing = antialias;
		}

		hideDialogue();
		skipHint.visible = false;
		precacheAudio();
	}

	public function start()
	{
		if(running || finished) return;
		running = true;
		sceneIndex = 0;
		if(registerObject != null)
		{
			for (id => bg in backgrounds) registerObject('dialogue_$id', bg);
			for (id => port in portraits) registerObject('dialogue_portrait_$id', port);
			registerObject('dialogue_black', black);
			registerObject('dialogue_box', box);
			registerObject('dialogue_text', text);
		}
		skipHint.visible = true;
		var first:DialogueScene = data.scenes[0];
		if(data.music != null && data.music.length > 0 && (first == null || first.track == null))
			playTrack(data.music, 0.4, 1.5, 1);
		startScene();
	}

	function addBackground(bg:DialogueBackground)
	{
		if(bg == null || bg.id == null) return;
		var sprite:FlxSprite;
		if(bg.image != null && bg.image.length > 0)
		{
			sprite = makeImage(bg.image, 0, 0);
			if(bg.center != false) sprite.screenCenter();
		}
		else
		{
			sprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
			sprite.color = colorOf(str(bg.color, '000000'), FlxColor.BLACK);
		}
		sprite.alpha = num(bg.alpha, 1);
		var old:FlxSprite = backgrounds.get(bg.id);
		if(old != null)
		{
			remove(old, true);
			old.destroy();
		}
		backgrounds.set(bg.id, sprite);
		add(sprite);
	}

	function loadCharacter(id:String)
	{
		var info:DialogueCharacterData = DialogueData.character(id);
		characters.set(id, info);
		if(info == null) return;

		var port:FlxSprite = new FlxSprite();
		var atlas = Paths.fileExists('images/${info.portrait}.xml', TEXT) ? Paths.getSparrowAtlas(info.portrait) : null;
		if(atlas != null)
		{
			port.frames = atlas;
			if(info.animations != null)
				for (anim in info.animations)
					port.animation.addByPrefix(anim.name, anim.prefix, num(anim.fps, 24), anim.loop == true);
		}
		else
		{
			var graphic = Paths.image(info.portrait);
			if(graphic != null) port.loadGraphic(graphic);
			else port.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		}
		var scale:Array<Float> = (info.scale != null) ? info.scale : [1, 1];
		port.scale.set(scale[0], scale.length > 1 ? scale[1] : scale[0]);
		port.updateHitbox();
		var pos:Array<Float> = (info.position != null) ? info.position : [0, 0];
		port.setPosition(pos[0], pos[1]);
		port.flipX = info.flipX == true;
		port.antialiasing = ClientPrefs.data.antialiasing;
		port.visible = false;
		portraits.set(id, port);
		add(port);
	}

	function makeImage(key:String, x:Float, y:Float):FlxSprite
	{
		var sprite:FlxSprite = new FlxSprite(x, y);
		var graphic = Paths.image(key);
		if(graphic != null) sprite.loadGraphic(graphic);
		else sprite.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		sprite.antialiasing = ClientPrefs.data.antialiasing;
		return sprite;
	}

	function precacheAudio()
	{
		for (scene in data.scenes)
		{
			if(scene == null) continue;
			if(scene.track != null && scene.track.name != null && scene.track.name.length > 0) Paths.music(scene.track.name);
			if(scene.sfx != null && scene.sfx.name != null && scene.sfx.name.length > 0) Paths.sound(scene.sfx.name);
		}
		for (info in characters)
			if(info != null && info.voice != null && info.voice.length > 0) Paths.sound(info.voice);
		if(data.music != null && data.music.length > 0) Paths.music(data.music);
	}

	public function startScene(forceFade:Bool = false)
	{
		var scene:DialogueScene = data.scenes[sceneIndex];
		if(scene == null)
		{
			end(true, 1);
			return;
		}

		canInteract = false;
		autoSkip = false;
		waitTimer = -1;
		waitingCustom = false;
		hintOff();
		stopTextShake();
		sceneTrack(scene);
		sceneSound(scene);
		if(onScene != null) onScene(sceneIndex, scene);

		switch(str(scene.scene, 'normal'))
		{
			case 'free':
				waitingCustom = true;
				if(scene.duration != null) waitTimer = scene.duration;
				if(onCustom != null) onCustom(str(scene.custom, ''), scene);
				return;
			case 'ending':
				end(forceFade || scene.fade == true, num(scene.duration, 1));
				return;
			case 'single':
				singleScene(scene);
			case 'wait':
				if(scene.keepText != true) hideDialogue();
				waitTimer = num(scene.duration, 1);
			case 'fade' | 'fadein' | 'fadeout':
				fadeScene(scene);
			default:
				normalScene(scene);
		}
		if(scene.fx != null) sceneFX(scene.fx);
	}

	public function jumpTo(index:Int)
	{
		running = true;
		finished = false;
		skipHint.visible = true;
		sceneIndex = Std.int(FlxMath.bound(index, 0, data.scenes.length - 1));
		startScene();
	}

	public function advance()
	{
		if(!running) return;
		if(isTyping) finishTyping();
		else if(canInteract)
		{
			waitTimer = -1;
			nextScene();
		}
	}

	public function nextScene()
	{
		if(!running) return;
		sceneIndex++;
		startScene();
	}

	public function customDone()
	{
		if(waitingCustom) nextScene();
	}

	function setupText(scene:DialogueScene, size:Int, center:Bool)
	{
		autoSkip = scene.skipDialog;
		finalText = str(scene.text, '');
		speed = Math.max(0.001, num(scene.speed, defaultSpeed));
		charNum = 0;
		voiceCount = 0;
		typeTimer = 0;
		isTyping = true;
		centered = center;

		text.text = '';
		text.size = (scene.size != null) ? scene.size : size;
		var font:String = scene.font;
		if(font == null || font.length < 1)
		{
			var info:DialogueCharacterData = characters.get(scene.character);
			font = (info != null && info.font != null && info.font.length > 0) ? info.font : str(style.font, 'vcr.ttf');
		}
		text.font = Paths.font(font);
		text.alignment = center ? CENTER : LEFT;
		text.visible = true;
		skipHint.visible = true;
		placeText();

		var info:DialogueCharacterData = characters.get(scene.character);
		voice = (info != null && info.voice != null) ? info.voice : '';
		voicePitch = (scene.voicePitch != null) ? scene.voicePitch : ((info != null && info.voicePitch != null) ? info.voicePitch : 1);
		var step:Int = (scene.voiceStep != null) ? scene.voiceStep : ((info != null && info.voiceStep != null) ? info.voiceStep : 1);
		voiceStep = Std.int(Math.max(Math.max(1, step), Math.ceil(minVoiceGap / speed)));

		if(finalText.length < 1) finishTyping();
	}

	function placeText()
	{
		if(centered)
		{
			text.screenCenter();
			return;
		}
		var offset:Array<Float> = (style.textOffset != null) ? style.textOffset : [50, 45];
		text.setPosition(box.x + offset[0], box.y + offset[1]);
	}

	function finishTyping()
	{
		isTyping = false;
		text.text = finalText;
		placeText();
		if(shakeLeft == SHAKE_LINE) stopTextShake();

		if(autoSkip == true)
		{
			nextScene();
			return;
		}
		canInteract = true;
		hintOn();
		if(Std.isOfType(autoSkip, Float) || Std.isOfType(autoSkip, Int))
		{
			var delay:Float = autoSkip;
			if(delay > 0) waitTimer = delay;
		}
	}

	function typeChar()
	{
		charNum++;
		text.text = finalText.substr(0, charNum);
		if(centered) placeText();

		var char:String = finalText.charAt(charNum - 1);
		if(voice.length > 0 && char != ' ' && char != '\n')
		{
			if(voiceCount % voiceStep == 0) playVoice();
			voiceCount++;
		}
		if(charNum >= finalText.length) finishTyping();
	}

	function playVoice()
	{
		if(!playVoices) return;
		var snd:FlxSound = FlxG.sound.play(Paths.sound(voice), voiceVolume);
		#if FLX_PITCH
		if(snd != null) snd.pitch = voicePitch;
		#end
	}

	function singleScene(scene:DialogueScene)
	{
		showPortrait(null);
		hideUI();
		box.color = FlxColor.WHITE;
		setupText(scene, Std.int(num(style.singleTextSize, 40)), true);
	}

	function normalScene(scene:DialogueScene)
	{
		var id:String = scene.character;
		var info:DialogueCharacterData = characters.get(id);
		if(info == null)
		{
			singleScene(scene);
			return;
		}

		showPortrait(id);
		box.visible = overlay.visible = true;
		box.color = colorOf(info.boxColor, FlxColor.WHITE);
		setupText(scene, (info.textSize != null) ? info.textSize : Std.int(num(style.textSize, 40)), false);

		var tagPos:Array<Float> = (info.nametagPosition != null) ? info.nametagPosition : [50, -80];
		nametag.setGraphicSize(Std.int(num(info.nametagWidth, 300)), 90);
		nametag.updateHitbox();
		nametag.setPosition(box.x + tagPos[0], box.y + tagPos[1]);
		nametag.visible = true;

		var namePos:Array<Float> = (info.namePosition != null) ? info.namePosition : [70, -75];
		nameText.text = str(info.name, id.toUpperCase());
		nameText.color = colorOf((info.nameColor != null) ? info.nameColor : info.boxColor, FlxColor.WHITE);
		nameText.setPosition(box.x + namePos[0], box.y + namePos[1]);
		nameText.visible = true;

		var port:FlxSprite = portraits.get(id);
		var anim:String = (scene.portrait != null && scene.portrait.length > 0) ? scene.portrait : 'neutral';
		if(port != null && port.animation.exists(anim))
		{
			port.animation.play(anim, true);
			var offsets:Array<Float> = animOffsets(info, anim);
			port.offset.set(offsets[0], offsets[1]);
		}
	}

	static function animOffsets(info:DialogueCharacterData, anim:String):Array<Float>
	{
		if(info.animations != null)
			for (a in info.animations)
				if(a.name == anim && a.offsets != null && a.offsets.length > 1) return a.offsets;
		return [0, 0];
	}

	function fadeScene(scene:DialogueScene)
	{
		if(scene.keepText != true) hideUI();
		var alpha:Float = (scene.alpha != null) ? scene.alpha : (scene.scene == 'fadein' ? 0 : 1);
		var duration:Float = num(scene.duration, 1);
		var list:Array<String> = [];
		if(scene.target == null) list.push('black');
		else if(Std.isOfType(scene.target, Array)) for (t in (scene.target:Array<Dynamic>)) list.push(Std.string(t));
		else list.push(Std.string(scene.target));

		var sprites:Array<FlxSprite> = [];
		for (id in list)
		{
			var sprite:FlxSprite = (id == 'black') ? black : backgrounds.get(id);
			if(sprite != null) sprites.push(sprite);
		}
		if(sprites.length < 1)
		{
			nextScene();
			return;
		}
		for (i => sprite in sprites)
		{
			var last:Bool = (i == sprites.length - 1);
			addTween(FlxTween.tween(sprite, {alpha: alpha}, Math.max(0.001, duration), {onComplete: last ? (_) -> nextScene() : null}));
		}
	}

	function sceneFX(fx:Dynamic)
	{
		var fxName:String = null;
		var a:Dynamic = null;
		var b:Dynamic = null;
		if(Std.isOfType(fx, Array))
		{
			var list:Array<Dynamic> = fx;
			fxName = Std.string(list[0]);
			a = list[1];
			b = list[2];
		}
		else fxName = Std.string(fx);

		switch(fxName)
		{
			case 'shake':
				cam.shake((a != null) ? a : 0.015, (b != null) ? b : 0.4);
			case 'flash':
				cam.flash(colorOf((a != null) ? Std.string(a) : 'FFFFFF', FlxColor.WHITE), (b != null) ? b : 0.4, null, true);
			case 'textShake':
				shakeAmount = (a != null) ? a : 4;
				shakeLeft = (b == true) ? SHAKE_SCENE : ((b != null && b != false) ? b : SHAKE_LINE);
		}
	}

	function stopTextShake()
	{
		shakeAmount = 0;
		shakeLeft = 0;
		if(text != null) text.offset.set(0, 0);
	}

	function sceneTrack(scene:DialogueScene)
	{
		var t:DialogueAudio = scene.track;
		if(t == null || !playAudio) return;
		var trackKey:String = str(t.name, '');
		var volume:Float = num(t.volume, 0.4);
		var fadeTime:Float = num(t.fadeTime, 0);

		if(trackKey.length < 1 || t.fade == 'out') stopTrack(fadeTime);
		else if(trackKey == trackName)
		{
			if(volume != trackVolume)
			{
				fadeTrack(volume, (t.fade == 'in' && fadeTime > 0) ? fadeTime : 0.5);
				trackVolume = volume;
			}
			#if FLX_PITCH
			if(t.pitch != null && track != null) track.pitch = t.pitch;
			#end
		}
		else playTrack(trackKey, volume, (t.fade == 'in') ? fadeTime : 0, num(t.pitch, 1));
	}

	function playTrack(key:String, volume:Float, fadeTime:Float, pitch:Float)
	{
		killTrack();
		trackName = key;
		trackVolume = volume;
		track = new FlxSound().loadEmbedded(Paths.music(key), true);
		FlxG.sound.list.add(track);
		track.volume = (fadeTime > 0) ? 0 : volume;
		#if FLX_PITCH
		track.pitch = pitch;
		#end
		track.play();
		if(fadeTime > 0) fadeTrack(volume, fadeTime);
	}

	function fadeTrack(to:Float, time:Float)
	{
		if(track == null) return;
		FlxTween.cancelTweensOf(track);
		if(time > 0) addTween(FlxTween.tween(track, {volume: to}, time));
		else track.volume = to;
	}

	function stopTrack(time:Float)
	{
		if(trackName.length < 1) return;
		fadeTrack(0, (time > 0) ? time : 0.5);
		trackName = '';
		trackVolume = 0;
	}

	function killTrack()
	{
		if(track == null) return;
		FlxTween.cancelTweensOf(track);
		track.stop();
		FlxG.sound.list.remove(track, true);
		track.destroy();
		track = null;
	}

	function sceneSound(scene:DialogueScene)
	{
		var s:DialogueAudio = scene.sfx;
		if(s == null || !playAudio) return;
		sfxDelay = -1;
		pendingSfx = null;

		var key:String = str(s.name, '');
		var volume:Float = num(s.volume, 1);
		if(key.length < 1 || s.fade == 'out') stopSfx(s.fade == 'out' ? num(s.fadeTime, 0.5) : 0);
		else if(key == sfxName && sfx != null && sfx.playing)
		{
			if(volume != sfxVolume)
			{
				FlxTween.cancelTweensOf(sfx);
				addTween(FlxTween.tween(sfx, {volume: volume}, 0.5));
				sfxVolume = volume;
			}
			#if FLX_PITCH
			if(s.pitch != null) sfx.pitch = s.pitch;
			#end
		}
		else if(s.delay != null && s.delay > 0)
		{
			pendingSfx = s;
			sfxDelay = s.delay;
		}
		else startSfx(s);
	}

	function startSfx(s:DialogueAudio)
	{
		if(s == null) return;
		stopSfx(0);
		sfxName = str(s.name, '');
		sfxVolume = num(s.volume, 1);
		sfx = new FlxSound().loadEmbedded(Paths.sound(sfxName));
		FlxG.sound.list.add(sfx);
		#if FLX_PITCH
		sfx.pitch = num(s.pitch, 1);
		#end
		if(s.fade == 'in')
		{
			sfx.volume = 0;
			addTween(FlxTween.tween(sfx, {volume: sfxVolume}, num(s.fadeTime, 0.5)));
		}
		else sfx.volume = sfxVolume;
		sfx.play();
		sfxLife = (s.life != null && s.life > 0) ? s.life : -1;
	}

	function stopSfx(time:Float)
	{
		sfxDelay = -1;
		sfxLife = -1;
		pendingSfx = null;
		sfxName = '';
		sfxVolume = 0;
		if(sfx == null) return;
		var old:FlxSound = sfx;
		sfx = null;
		FlxTween.cancelTweensOf(old);
		if(time > 0)
		{
			addTween(FlxTween.tween(old, {volume: 0}, time, {onComplete: (_) -> {
				old.stop();
				FlxG.sound.list.remove(old, true);
				old.destroy();
			}}));
		}
		else
		{
			old.stop();
			FlxG.sound.list.remove(old, true);
			old.destroy();
		}
	}

	function showPortrait(id:String)
	{
		for (key => port in portraits) port.visible = (key == id);
	}

	function hintOn()
	{
		hint.visible = true;
		hint.alpha = 0.5;
		if(hintTween != null) hintTween.cancel();
		hintTween = FlxTween.tween(hint, {alpha: 1}, 0.6, {type: PINGPONG});
	}

	function hintOff()
	{
		if(hintTween != null) hintTween.cancel();
		hintTween = null;
		if(hint != null) hint.visible = false;
	}

	function hideUI()
	{
		hintOff();
		for (sprite in [nametag, box, overlay, nameText, text, skipHint]) sprite.visible = false;
	}

	public function hideDialogue()
	{
		showPortrait(null);
		hideUI();
		box.color = FlxColor.WHITE;
	}

	public function end(fade:Bool, duration:Float)
	{
		canInteract = false;
		isTyping = false;
		waitTimer = -1;
		waitingCustom = false;
		stopSfx(0.25);
		stopTextShake();
		hintOff();

		if(fade)
		{
			stopTrack(duration);
			black.alpha = 0;
			addTween(FlxTween.tween(black, {alpha: 1}, Math.max(0.001, duration), {onComplete: (_) -> finish(true)}));
		}
		else
		{
			stopTrack(0.25);
			hideDialogue();
			finish(false);
		}
	}

	function finish(faded:Bool)
	{
		if(finished) return;
		finished = true;
		running = false;
		hideDialogue();
		if(onFinish != null) onFinish(faded);
	}

	public function skipAll()
	{
		isTyping = false;
		hintOff();
		for (i => scene in data.scenes)
		{
			if(scene != null && scene.scene == 'ending' && i >= sceneIndex)
			{
				sceneIndex = i;
				startScene(true);
				return;
			}
		}
		end(true, 1);
	}

	public function hideEverything()
	{
		hideDialogue();
		for (bg in backgrounds) bg.alpha = 0;
		black.alpha = 0;
	}

	function addTween(tween:FlxTween):FlxTween
	{
		tweens.push(tween);
		return tween;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(!running) return;

		if(isTyping)
		{
			typeTimer += elapsed;
			while(isTyping && typeTimer >= speed)
			{
				typeTimer -= speed;
				typeChar();
			}
		}

		if(shakeAmount > 0)
		{
			if(shakeLeft > 0)
			{
				shakeLeft -= elapsed;
				if(shakeLeft <= 0) stopTextShake();
			}
			if(shakeAmount > 0) text.offset.set(FlxG.random.float(-shakeAmount, shakeAmount), FlxG.random.float(-shakeAmount, shakeAmount));
		}

		if(sfxDelay > 0)
		{
			sfxDelay -= elapsed;
			if(sfxDelay <= 0) startSfx(pendingSfx);
		}
		if(sfxLife > 0)
		{
			sfxLife -= elapsed;
			if(sfxLife <= 0) stopSfx(0.5);
		}
		if(waitTimer > 0)
		{
			waitTimer -= elapsed;
			if(waitTimer <= 0)
			{
				waitTimer = -1;
				nextScene();
				return;
			}
		}

		if(!inputEnabled || !running) return;
		if(FlxG.keys.anyJustPressed([skipKey])) skipAll();
		else if(FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ENTER)
		{
			if(autoSkip == true) return;
			if(isTyping) finishTyping();
			else if(canInteract)
			{
				waitTimer = -1;
				nextScene();
			}
		}
	}

	var characterColors:Map<String, Null<FlxColor>> = [];
	function colorOf(value:String, fallback:FlxColor):FlxColor
	{
		if(value == null || value.length < 1) return fallback;
		if(colorResolver != null)
		{
			var resolved:Null<FlxColor> = colorResolver(value);
			if(resolved != null) return resolved;
		}
		if(!characterColors.exists(value))
		{
			var file:Dynamic = value.startsWith('#') ? null : DialogueData.readJson('characters/$value');
			var rgb:Array<Int> = (file != null) ? file.healthbar_colors : null;
			characterColors.set(value, (rgb != null && rgb.length > 2) ? FlxColor.fromRGB(rgb[0], rgb[1], rgb[2]) : null);
		}
		var fromCharacter:Null<FlxColor> = characterColors.get(value);
		if(fromCharacter != null) return fromCharacter;
		return CoolUtil.colorFromString(value);
	}

	static inline function num(value:Null<Float>, fallback:Float):Float
		return (value != null && !Math.isNaN(value)) ? value : fallback;

	static inline function str(value:String, fallback:String):String
		return (value != null && value.length > 0) ? value : fallback;

	override function destroy()
	{
		for (tween in tweens) if(tween != null) tween.cancel();
		tweens = [];
		if(hintTween != null) hintTween.cancel();
		killTrack();
		stopSfx(0);
		super.destroy();
	}
}
