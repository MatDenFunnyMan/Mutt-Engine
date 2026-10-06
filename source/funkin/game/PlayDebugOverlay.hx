package funkin.game;

import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxStringUtil;
import funkin.game.states.PlayState;

typedef PlayDebugState = {
	var enabled:Bool;
	var hud:Bool;
	var botplay:Bool;
	var camera:Bool;
	var characters:Bool;
	var song:Bool;
}

class PlayDebugOverlay extends FlxGroup
{
	public static var saved:PlayDebugState = null;

	public static inline final FREE_CAM_SPEED:Float = 500;
	public static inline final FREE_CAM_FAST:Float = 3;
	public static inline final FREE_CAM_MIN_ZOOM:Float = 0.1;
	public static inline final FREE_CAM_MAX_ZOOM:Float = 5;

	public var enabled(default, null):Bool = false;
	public var freeCam(default, null):Bool = false;
	public var frozen(default, null):Bool = false;

	var game:PlayState;
	var titleText:FlxText;
	var statusText:FlxText;
	var cameraText:FlxText;
	var charactersText:FlxText;
	var songText:FlxText;
	var noticeText:FlxText;
	var noticeTween:FlxTween;

	var showCamera:Bool = false;
	var showCharacters:Bool = false;
	var showSong:Bool = false;
	var pulseTime:Float = 0;

	var freeScroll:FlxPoint = FlxPoint.get();
	var freeZoom:Float = 1;
	var gameScroll:FlxPoint = FlxPoint.get();
	var gameZoom:Float = 1;
	var freeCamApplied:Bool = false;
	var freezeState:PlayDebugFreezeSubState;

	public function new(game:PlayState, camera:FlxCamera)
	{
		super();
		this.game = game;

		titleText = makeText(camera, 28, RIGHT, 300);
		titleText.text = 'DEBUG MODE';
		titleText.setPosition(FlxG.width - titleText.width - 12, 10);

		statusText = makeText(camera, 18, RIGHT, 300);
		statusText.setPosition(FlxG.width - statusText.width - 12, 42);

		cameraText = makeText(camera, 14, LEFT, 320);
		cameraText.x = 12;

		charactersText = makeText(camera, 16, LEFT, 420);
		charactersText.borderSize = 2;
		charactersText.x = FlxG.width - charactersText.width - 12;

		songText = makeText(camera, 14, RIGHT, 320);
		songText.x = FlxG.width - songText.width - 12;

		noticeText = makeText(camera, 24, CENTER, FlxG.width);
		noticeText.y = FlxG.height * 0.3;
	}

	function makeText(camera:FlxCamera, size:Int, align:FlxTextAlign, width:Float):FlxText
	{
		var text:FlxText = new FlxText(0, 0, width, '', size);
		text.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.borderSize = 1.5;
		text.scrollFactor.set();
		text.cameras = [camera];
		text.visible = false;
		add(text);
		return text;
	}

	public function setEnabled(value:Bool)
	{
		enabled = value;
		pulseTime = 0;
		titleText.visible = value;
		if(!value)
		{
			setFreeCam(false, false);
			setFrozen(false, false);
			game.camHUD.visible = true;
			showCamera = showCharacters = showSong = false;
		}
		refreshPanels();
		refreshStatus();
	}

	public function restore(state:PlayDebugState)
	{
		if(!state.enabled) return;
		setEnabled(true);
		game.camHUD.visible = state.hud;
		if(game.cpuControlled != state.botplay) setBotplay(state.botplay, false);
		showCamera = state.camera;
		showCharacters = state.characters;
		showSong = state.song;
		refreshPanels();
	}

	public function saveState():PlayDebugState
	{
		return {
			enabled: enabled,
			hud: game.camHUD.visible,
			botplay: game.cpuControlled,
			camera: showCamera,
			characters: showCharacters,
			song: showSong
		};
	}

	public function handleInput()
	{
		if(!enabled) return;

		if(FlxG.keys.pressed.CONTROL)
		{
			if(FlxG.keys.justPressed.B) setBotplay(!game.cpuControlled, true);
			if(FlxG.keys.justPressed.F) setFreeCam(!freeCam, true);
			if(FlxG.keys.justPressed.SPACE) setFrozen(!frozen, true);
			if(FlxG.keys.justPressed.R) game.debugSoftReset();
			return;
		}

		if(FlxG.keys.justPressed.H) game.camHUD.visible = !game.camHUD.visible;
		if(FlxG.keys.justPressed.C)
		{
			showCamera = !showCamera;
			refreshPanels();
		}
		if(FlxG.keys.justPressed.P)
		{
			showCharacters = !showCharacters;
			refreshPanels();
		}
		if(FlxG.keys.justPressed.I)
		{
			showSong = !showSong;
			refreshPanels();
		}
		if(freeCam && FlxG.keys.justPressed.R) resetFreeCam();
	}

	function setBotplay(value:Bool, notify:Bool)
	{
		game.cpuControlled = value;
		game.botplayTxt.visible = value;
		game.setOnScripts('botPlay', value);
		if(value) game.debugBotplayUsed = true;

		for (strum in game.playerStrums)
		{
			strum.playAnim('static');
			strum.resetAnim = 0;
		}

		if(notify) showNotice(value ? 'Botplay Enabled' : 'Botplay Disabled');
	}

	function setFrozen(value:Bool, notify:Bool)
	{
		if(frozen == value) return;

		if(value)
		{
			if(game.subState != null) return;
			frozen = true;
			FlxG.camera.followLerp = 0;
			game.persistentUpdate = false;
			game.paused = true;
			freezeState = new PlayDebugFreezeSubState(this);
			game.openSubState(freezeState);
		}
		else
		{
			frozen = false;
			if(freezeState != null) freezeState.close();
			freezeState = null;
		}

		if(notify) showNotice(value ? 'Song Stopped' : 'Song Resumed');
		refreshStatus();
	}

	function setFreeCam(value:Bool, notify:Bool)
	{
		if(freeCam == value) return;
		freeCam = value;

		if(value)
		{
			resetFreeCam();
			FlxG.signals.preUpdate.add(restoreGameCam);
			FlxG.signals.preDraw.add(applyFreeCam);
		}
		else removeFreeCam();

		if(notify) showNotice(value ? 'Free Cam Enabled' : 'Free Cam Disabled');
		refreshStatus();
	}

	function resetFreeCam()
	{
		var cam:FlxCamera = game.camGame;
		freeScroll.copyFrom(freeCamApplied ? gameScroll : cam.scroll);
		freeZoom = freeCamApplied ? gameZoom : cam.zoom;
	}

	function applyFreeCam()
	{
		var cam:FlxCamera = game.camGame;
		if(cam == null || (game.subState != null && game.subState != freezeState)) return;
		gameScroll.copyFrom(cam.scroll);
		gameZoom = cam.zoom;
		cam.scroll.copyFrom(freeScroll);
		cam.zoom = freeZoom;
		freeCamApplied = true;
	}

	function restoreGameCam()
	{
		if(!freeCamApplied) return;
		var cam:FlxCamera = game.camGame;
		if(cam != null)
		{
			cam.scroll.copyFrom(gameScroll);
			cam.zoom = gameZoom;
		}
		freeCamApplied = false;
	}

	function removeFreeCam()
	{
		FlxG.signals.preUpdate.remove(restoreGameCam);
		FlxG.signals.preDraw.remove(applyFreeCam);
		restoreGameCam();
	}

	function moveFreeCam(elapsed:Float)
	{
		var speed:Float = FREE_CAM_SPEED * elapsed / freeZoom;
		if(FlxG.keys.pressed.SHIFT) speed *= FREE_CAM_FAST;

		if(FlxG.keys.pressed.LEFT) freeScroll.x -= speed;
		if(FlxG.keys.pressed.RIGHT) freeScroll.x += speed;
		if(FlxG.keys.pressed.UP) freeScroll.y -= speed;
		if(FlxG.keys.pressed.DOWN) freeScroll.y += speed;

		var zoomSpeed:Float = elapsed * (FlxG.keys.pressed.SHIFT ? FREE_CAM_FAST : 1);
		if(FlxG.keys.pressed.Q) freeZoom -= freeZoom * zoomSpeed;
		if(FlxG.keys.pressed.E) freeZoom += freeZoom * zoomSpeed;
		freeZoom = FlxMath.bound(freeZoom, FREE_CAM_MIN_ZOOM, FREE_CAM_MAX_ZOOM);
	}

	public function blocksKey(key:FlxKey):Bool
	{
		if(!freeCam) return false;
		return key == LEFT || key == RIGHT || key == UP || key == DOWN || key == Q || key == E || key == R;
	}

	function showNotice(message:String)
	{
		if(noticeTween != null) noticeTween.cancel();
		noticeText.text = message;
		noticeText.visible = true;
		noticeText.alpha = 1;
		noticeTween = FlxTween.tween(noticeText, {alpha: 0}, 0.5, {startDelay: 1, onComplete: function(_)
		{
			noticeText.visible = false;
			noticeTween = null;
		}});
	}

	function refreshStatus()
	{
		var parts:Array<String> = [];
		if(frozen) parts.push('STOPPED');
		if(freeCam) parts.push('FREE CAM');
		statusText.text = parts.join('  ');
		statusText.visible = enabled && parts.length > 0;
	}

	function refreshPanels()
	{
		cameraText.visible = enabled && showCamera;
		charactersText.visible = enabled && showCharacters;
		songText.visible = enabled && showSong;
		updatePanels();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(!enabled) return;

		pulseTime += elapsed;
		titleText.alpha = 0.6 + 0.4 * Math.sin(pulseTime * Math.PI * 0.75);
		if(noticeTween != null) noticeTween.active = true;
		if(freeCam) moveFreeCam(elapsed);
		updatePanels();
	}

	function updatePanels()
	{
		if(cameraText.visible)
		{
			cameraText.text = cameraInfo();
			cameraText.y = (FlxG.height - cameraText.height) / 2;
		}
		if(charactersText.visible)
		{
			charactersText.text = charactersInfo();
			charactersText.y = Math.max(70, (FlxG.height - charactersText.height) / 2);
		}
		if(songText.visible)
		{
			songText.text = songInfo();
			songText.y = FlxG.height - songText.height - 12;
		}
	}

	function cameraInfo():String
	{
		var cam:FlxCamera = game.camGame;
		var scroll:FlxPoint = freeCamApplied ? gameScroll : cam.scroll;
		var zoom:Float = freeCamApplied ? gameZoom : cam.zoom;
		var lines:Array<String> = ['CAMERA'];
		if(game.camFollow != null) lines.push('Follow X: ${round(game.camFollow.x)}  Y: ${round(game.camFollow.y)}');
		lines.push('Scroll X: ${round(scroll.x)}  Y: ${round(scroll.y)}');
		lines.push('Zoom: ${round(zoom, 3)}  (Default: ${round(game.defaultCamZoom, 3)})');
		lines.push('Speed: ${round(game.cameraSpeed, 2)}  (Stage: ${round(game.stageCameraSpeed, 2)})');
		lines.push('Locked: ${game.camFollowLocked}');
		if(freeCam)
		{
			lines.push('');
			lines.push('FREE CAM');
			lines.push('Scroll X: ${round(freeScroll.x)}  Y: ${round(freeScroll.y)}');
			lines.push('Zoom: ${round(freeZoom, 3)}');
		}
		return lines.join('\n');
	}

	function charactersInfo():String
	{
		var blocks:Array<String> = [];
		for (entry in [{label: 'PLAYER', char: game.boyfriend}, {label: 'OPPONENT', char: game.dad}, {label: 'GIRLFRIEND', char: game.gf}])
			if(entry.char != null) blocks.push(characterInfo(entry.label, entry.char));
		return blocks.join('\n\n');
	}

	function characterInfo(label:String, char:Character):String
	{
		var frame:String = '-';
		if(!char.isAnimationNull())
		{
			if(char.isAnimateAtlas) frame = '${char.atlas.anim.curFrame}/${char.atlas.anim.length}';
			else frame = '${char.animation.curAnim.curFrame + 1}/${char.animation.curAnim.numFrames}';
		}

		var lines:Array<String> = [
			'$label: ${char.curCharacter}',
			'X: ${round(char.x)}  Y: ${round(char.y)}  Alpha: ${round(char.alpha, 2)}',
			'Visible: ${char.visible}  Flip X: ${char.flipX}',
			'Scale: ${round(char.scale.x, 2)}, ${round(char.scale.y, 2)}  Angle: ${round(char.angle)}',
			'Anim: ${char.getAnimationName()}  Frame: $frame',
			'Offset: ${round(char.offset.x)}, ${round(char.offset.y)}  Position: ${char.positionArray[0]}, ${char.positionArray[1]}',
			'Camera: ${char.cameraPosition[0]}, ${char.cameraPosition[1]}  Icon: ${char.healthIcon}',
			'Sing Duration: ${char.singDuration}  Hold Timer: ${round(char.holdTimer, 2)}',
			'Dance Every: ${char.danceEveryNumBeats}  Idle Suffix: ${char.idleSuffix.length > 0 ? char.idleSuffix : '-'}',
			'Player: ${char.isPlayer}  Stunned: ${char.stunned}',
			'Special: ${char.specialAnim}  Atlas: ${char.isAnimateAtlas}'
		];
		return lines.join('\n');
	}

	function songInfo():String
	{
		var step:Int = @:privateAccess game.curStep;
		var beat:Int = @:privateAccess game.curBeat;
		var section:Int = @:privateAccess game.curSection;
		var position:Float = Math.max(0, Conductor.songPosition);
		var length:Float = (FlxG.sound.music != null) ? FlxG.sound.music.length : 0;
		return [
			'SONG: ${PlayState.SONG.song}',
			'Step: $step  Beat: $beat  Section: $section',
			'BPM: ${round(Conductor.bpm, 2)}',
			'Time: ${formatTime(position)} / ${formatTime(length)}'
		].join('\n');
	}

	static function formatTime(ms:Float):String
	{
		var millis:Int = Std.int(ms % 1000);
		return FlxStringUtil.formatTime(Math.floor(ms / 1000), false) + '.' + StringTools.lpad(Std.string(millis), '0', 3);
	}

	static function round(value:Float, decimals:Int = 1):Float
		return CoolUtil.floorDecimal(value, decimals);

	override function destroy()
	{
		removeFreeCam();
		freeScroll.put();
		gameScroll.put();
		super.destroy();
	}
}

class PlayDebugFreezeSubState extends FlxSubState
{
	var overlay:PlayDebugOverlay;

	public function new(overlay:PlayDebugOverlay)
	{
		super();
		this.overlay = overlay;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(FlxG.keys.justPressed.ENTER && FlxG.keys.pressed.CONTROL && FlxG.keys.pressed.SHIFT)
		{
			overlay.setEnabled(false);
			return;
		}

		overlay.update(elapsed);
		overlay.handleInput();
	}
}
