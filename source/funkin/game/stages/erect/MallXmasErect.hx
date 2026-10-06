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

class MallXmasErect extends BaseStage
{
	var upperBoppers:BGSprite;
	var bottomBoppers:MallCrowd;
	var santa:BGSprite;

	var erectSanta:animate.FlxAnimate;
	var erectParents:animate.FlxAnimate;

	override function create()
	{
		var _song = PlayState.SONG;

		var bg:BGSprite = new BGSprite('christmas/erect/bgWalls', -726, -566, 0.2, 0.2);
		bg.setGraphicSize(Std.int(bg.width * 0.9));
		bg.updateHitbox();
		add(bg);

		if(!ClientPrefs.data.lowQuality) {
			upperBoppers = new BGSprite('christmas/erect/upperBop', -374, -98, 0.28, 0.28, ['upperBop']);
			upperBoppers.setGraphicSize(Std.int(upperBoppers.width * 0.85));
			upperBoppers.updateHitbox();
			add(upperBoppers);

			var bgEscalator:BGSprite = new BGSprite('christmas/erect/bgEscalator', -909, -204, 0.3, 0.3);
			bgEscalator.setGraphicSize(Std.int(bgEscalator.width * 0.9));
			bgEscalator.updateHitbox();
			add(bgEscalator);
		}

		var tree:BGSprite = new BGSprite('christmas/erect/christmasTree', 370, -250, 0.40, 0.40);
		add(tree);

		var fog = new BGSprite("christmas/erect/white",-1000,100,0.85,0.85);
		fog.scale.set(0.9,0.9);
		add(fog);

		bottomBoppers = new MallCrowd(-300, 140,'christmas/erect/bottomBop',"bottomBop");
		add(bottomBoppers);

		var fgSnow:BGSprite = new BGSprite('christmas/erect/fgSnow', -880, 700);
		add(fgSnow);

		setDefaultGF('gf-christmas');

		if(songName == "eggnog-erect" || songName == "eggnog-(pico-mix)"){
			erectSanta = makeCutsceneAtlas(-1318, 138.5, "christmas/santa_speaks_assets", "santa whole scene");
			erectParents = makeCutsceneAtlas(-624.5, 39, "christmas/parents_shoot_assets", "parents whole scene");
			Paths.sound('santa_emotion');
			Paths.sound('santa_shot_n_falls');
			game.preloadSubtitles('santa-emotions');
			setEndCallback(eggnogEndCutscene);
		}
	}
	override function createPost() {
		super.createPost();
		santa = new BGSprite('christmas/santa', -840, 150, 1, 1, ['santa idle in fear']);
		add(santa);
		if(ClientPrefs.data.shaders){
			var colorShader = new AdjustColorShader();
			colorShader.hue = 5;
			colorShader.saturation = 20;

			boyfriend.shader = colorShader;
			gf.shader = colorShader;
			dad.shader = colorShader;
			santa.shader = colorShader;
			if(erectSanta != null){
				erectSanta.shader = santa.shader;
				erectParents.shader = santa.shader;
			}
			PicoCapableStage.instance?.applyABotShader(colorShader);
		}

		@:privateAccess
		if(PicoCapableStage.NENE_LIST.contains(PlayState.SONG.gfVersion)) GameOverSubstate.characterName = 'pico-christmas-dead';
	}
	override function countdownTick(count:Countdown, num:Int) everyoneDance();
	override function beatHit() {
		super.beatHit();
		everyoneDance();
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "Hey!":
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						return;
				}
				bottomBoppers.animation.play('hey', true);
				bottomBoppers.heyTimer = flValue2;
		}
	}

	function everyoneDance()
	{
		if(!ClientPrefs.data.lowQuality)
			upperBoppers.dance(true);

		bottomBoppers.dance(true);
		santa.dance(true);
	}

	var cutsceneCamera:flixel.FlxObject;

	function eggnogEndCutscene()
	{
		remove(santa);
		dad.visible = false;
		canPause = false;
		game.endingSong = true;
		add(erectParents);
		add(erectSanta);

		erectSanta.anim.play("scene", true);
		erectParents.anim.play("scene", true);
		santaSound = FlxG.sound.play(Paths.sound("santa_emotion"));
		game.playSubtitles('santa-emotions', santaSound);

		inCutscene = true;
		game.camZooming = false;
		FlxTween.cancelTweensOf(camGame);
		camGame.follow(null);
		cutsceneCamera = new flixel.FlxObject(camGame.scroll.x + camGame.width / 2, camGame.scroll.y + camGame.height / 2);
		FlxTween.tween(camHUD, {alpha: 0}, 1);

		moveCutsceneCamera(-100, 400, 2.8, FlxEase.expoOut);
		FlxTween.tween(camGame, {zoom: 0.73}, 2, {ease: FlxEase.quadInOut});

		new FlxTimer().start(2.8, function(tmr)
		{
			moveCutsceneCamera(-250, 400, 9, FlxEase.quartInOut);
			FlxTween.tween(camGame, {zoom: 0.79}, 9, {ease: FlxEase.quadInOut});
		});

		if(ClientPrefs.data.naughtyness)
			new FlxTimer().start(11.375, (_) -> FlxG.sound.play(Paths.sound('santa_shot_n_falls')));
		else
			FlxG.signals.preDraw.add(censorShot);

		endTimers.push(new FlxTimer().start(12.83, function(tmr)
		{
			camGame.shake(0.005, 0.2);
			moveCutsceneCamera(-240, 480, 5, FlxEase.expoOut);
		}));

		endTimers.push(new FlxTimer().start(15, function(tmr)
		{
			camOther.fade(0xFF000000, 1, false, null, true);
		}));

		endTimers.push(new FlxTimer().start(16, function(tmr)
		{
			endSong();
		}));
	}

	static inline final SHOT_FRAME:Int = 271;
	static inline final SHOT_HEARD_MS:Float = 50;
	static inline final BLACK_SCREEN_TIME:Float = 1;

	var santaSound:FlxSound;
	var shotSound:FlxSound;
	var endTimers:Array<FlxTimer> = [];
	var blackScreen:Bool = false;

	function censorShot()
	{
		var frame:Int = erectParents.anim.curAnim != null ? erectParents.anim.curAnim.curFrame : 0;
		if(shotSound == null && frame >= SHOT_FRAME - 1) shotSound = FlxG.sound.play(Paths.sound('santa_shot_n_falls'));
		if(!blackScreen && frame >= SHOT_FRAME) cutToBlack();
		if(shotSound != null && shotSound.time >= SHOT_HEARD_MS)
		{
			shotSound.stop();
			FlxG.signals.preDraw.remove(censorShot);
		}
	}

	function cutToBlack()
	{
		blackScreen = true;
		for (timer in endTimers) timer.cancel();
		if(santaSound != null) santaSound.stop();
		game.stopSubtitles();

		var black:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		black.scale.set(FlxG.width * 2, FlxG.height * 2);
		black.updateHitbox();
		black.screenCenter();
		black.scrollFactor.set();
		black.cameras = [camOther];
		add(black);

		new FlxTimer().start(BLACK_SCREEN_TIME, (_) -> endSong());
	}

	function moveCutsceneCamera(x:Float, y:Float, duration:Float, ease:Float->Float)
	{
		FlxTween.cancelTweensOf(cutsceneCamera);
		FlxTween.tween(cutsceneCamera, {x: x, y: y}, duration, {ease: ease});
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (cutsceneCamera != null) camGame.focusOn(flixel.math.FlxPoint.weak(cutsceneCamera.x, cutsceneCamera.y));
	}

	function makeCutsceneAtlas(x:Float, y:Float, path:String, symbol:String):animate.FlxAnimate
	{
		var atlas:animate.FlxAnimate = new animate.FlxAnimate(x, y);
		atlas.frames = Paths.getAnimateAtlasFrames(path);
		atlas.useRenderTexture = true;
		funkin.util.AtlasUtil.ModernAtlasUtil.addAnimation(atlas, 'scene', symbol, null, 24, false);
		atlas.antialiasing = ClientPrefs.data.antialiasing;
		return atlas;
	}

	override function destroy()
	{
		FlxG.signals.preDraw.remove(censorShot);
		super.destroy();
	}
}
