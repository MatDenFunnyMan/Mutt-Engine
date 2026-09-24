package funkin.game.stages.objects;

#if funkin.vis
import funkin.vis.dsp.SpectralAnalyzer;
#end

class ABotPixel extends FlxSpriteGroup
{
	final VIZ_MAX = 7;
	final VIZ_POS_X:Array<Float> = [0, 7 * 6, 8 * 6, 9 * 6, 10 * 6, 6 * 6, 7 * 6];
	final VIZ_POS_Y:Array<Float> = [0, -2 * 6, -1 * 6, 0, 0, 1 * 6, 2 * 6];

	public var bg:FlxSprite;
	public var vizSprites:Array<FlxSprite> = [];
	public var eyes:FlxSprite;
	public var speakerTop:FlxSprite;
	public var speaker:FlxSprite;

	#if funkin.vis
	var analyzer:SpectralAnalyzer;
	var analysis:funkin.audio.AnalysisSource;
	#end

	public var snd(default, set):FlxSound;
	function set_snd(changed:FlxSound)
	{
		snd = changed;
		#if funkin.vis
		initAnalyzer();
		#end
		return snd;
	}

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		speakerTop = makeBopper(-65, -10, 'abot/pixel/aBotPixelSpeaker');

		bg = new FlxSprite(90, 20).loadGraphic(Paths.image('abot/pixel/aBotPixelBack'));
		bg.scale.set(6, 6);
		bg.antialiasing = false;
		bg.updateHitbox();
		add(bg);

		var vizX:Float = 0;
		var vizY:Float = 0;
		var vizFrames = Paths.getSparrowAtlas('abot/pixel/aBotVizPixel');
		for (i in 1...VIZ_MAX + 1)
		{
			vizX += VIZ_POS_X[i - 1];
			vizY += VIZ_POS_Y[i - 1];
			var viz:FlxSprite = new FlxSprite(vizX + 140, vizY + 74);
			viz.frames = vizFrames;
			viz.animation.addByPrefix('VIZ', 'viz$i', 0);
			viz.animation.play('VIZ', true);
			viz.animation.curAnim.finish();
			viz.antialiasing = false;
			viz.scale.set(6, 6);
			vizSprites.push(viz);
			viz.updateHitbox();
			viz.centerOffsets();
			add(viz);
		}

		eyes = new FlxSprite(-60, 80);
		eyes.frames = Paths.getSparrowAtlas('abot/pixel/abotHead');
		eyes.scale.set(6, 6);
		eyes.animation.addByPrefix('lookleft', 'toleft', 24, false);
		eyes.animation.addByPrefix('lookright', 'toright', 24, false);
		eyes.animation.play('lookright', true);
		eyes.animation.frameIndex = eyes.animation.curAnim.numFrames - 1;
		eyes.antialiasing = false;
		eyes.updateHitbox();
		add(eyes);

		speaker = makeBopper(65, -10, 'abot/pixel/aBotPixelBody');
	}

	function makeBopper(x:Float, y:Float, image:String):FlxSprite
	{
		var spr = new FlxSprite(x, y);
		spr.frames = Paths.getSparrowAtlas(image);
		spr.scale.set(6, 6);
		spr.animation.addByPrefix('anim', 'bop', 24, false);
		spr.animation.play('anim', true);
		spr.animation.curAnim.curFrame = spr.animation.curAnim.numFrames - 1;
		spr.antialiasing = false;
		spr.updateHitbox();
		add(spr);
		return spr;
	}

	#if funkin.vis
	var levels:Array<Bar>;
	var levelMax:Int = 0;
	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		checkAnalyzer();
		if(analyzer == null) return;

		levels = analyzer.getLevels(levels);
		var oldLevelMax = levelMax;
		levelMax = 0;
		for (i in 0...Std.int(Math.min(vizSprites.length, levels.length)))
		{
			var animFrame:Int = Math.round(levels[i].value * 5);
			animFrame = Std.int(Math.abs(FlxMath.bound(animFrame, 0, 5) - 5));
			vizSprites[i].animation.curAnim.curFrame = animFrame;
			levelMax = Std.int(Math.max(levelMax, 5 - animFrame));
		}

		if(levelMax >= 4 && oldLevelMax <= levelMax && (levelMax >= 5 || speakerTop.animation.curAnim.curFrame >= 3))
			beatHit();
	}

	public function initAnalyzer()
	{
		analyzer = null;
		analysis = new funkin.audio.AnalysisSource(snd);
		checkAnalyzer();
	}

	function checkAnalyzer()
	{
		if(analyzer != null || analysis == null) return;
		var source:lime.media.AudioSource = analysis.poll();
		if(source == null) return;

		analysis = null;
		analyzer = new SpectralAnalyzer(source, 7, 0.1, 40);
		#if desktop
		analyzer.fftN = 256;
		#end
	}
	#end

	public function beatHit()
	{
		speakerTop.animation.play('anim', true);
	}

	var lookingAtRight:Bool = true;
	public function lookLeft()
	{
		if(lookingAtRight) eyes.animation.play('lookleft', true);
		lookingAtRight = false;
	}
	public function lookRight()
	{
		if(!lookingAtRight) eyes.animation.play('lookright', true);
		lookingAtRight = true;
	}
}
