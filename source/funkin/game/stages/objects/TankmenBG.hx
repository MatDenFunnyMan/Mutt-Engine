package funkin.game.stages.objects;

import flixel.graphics.frames.FlxAtlasFrames;

class TankmenBG extends FlxSprite
{
	public static var animationNotes:Array<Dynamic> = [];
	private var tankSpeed:Float;
	private var endingOffset:Float;
	private var goingRight:Bool;
	public var strumTime:Float;
	var shotType:Int = 1;
	var runOffset:FlxPoint = FlxPoint.get();

	static final SHOT_OFFSETS:Array<Array<Float>> = [[180, 138, 359, 138], [340, 200, 376, 200]];

	public function new(x:Float, y:Float, facingRight:Bool)
	{
		tankSpeed = 0.7;
		goingRight = false;
		strumTime = 0;
		goingRight = facingRight;
		super(x, y);

		frames = Paths.getSparrowAtlas('tankmanKilled1');
		animation.addByPrefix('run', 'tankman running', 24, true);
		shotType = FlxG.random.int(1, 2);
		animation.addByPrefix('shot', 'John Shot ' + shotType, 24, false);
		animation.play('run');
		animation.curAnim.curFrame = FlxG.random.int(0, animation.curAnim.frames.length - 1);
		antialiasing = ClientPrefs.data.antialiasing;

		scale.set(0.8, 0.8);
		updateHitbox();
	}

	public function resetShit(x:Float, y:Float, goingRight:Bool):Void
	{
		this.x = x;
		this.y = y;
		this.goingRight = goingRight;
		endingOffset = FlxG.random.float(50, 200);
		tankSpeed = FlxG.random.float(0.6, 1);
		flipX = goingRight;
	}

	override function destroy()
	{
		runOffset.put();
		super.destroy();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(animation.curAnim.name == "run")
		{
			var speed:Float = (Conductor.songPosition - strumTime) * tankSpeed;
			if(goingRight)
				x = (0.02 * FlxG.width - endingOffset) + speed;
			else
				x = (0.74 * FlxG.width + endingOffset) - speed;
		}
		else if(animation.curAnim.finished)
		{
			kill();
		}

		if(Conductor.songPosition > strumTime && animation.curAnim.name == "run")
		{
			runOffset.set(offset.x, offset.y);
			animation.play('shot');
			var shotOffset:Array<Float> = SHOT_OFFSETS[shotType - 1];
			offset.set(runOffset.x + (flipX ? shotOffset[2] : shotOffset[0]) * scale.x, runOffset.y + (flipX ? shotOffset[3] : shotOffset[1]) * scale.y);
		}
	}
}