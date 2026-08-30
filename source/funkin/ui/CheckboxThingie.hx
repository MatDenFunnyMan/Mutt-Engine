package funkin.ui;

class CheckboxThingie extends FlxSprite
{
	public var sprTracker:FlxSprite;
	public var daValue(default, set):Bool;
	public var copyAlpha:Bool = true;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var scaleMult(default, null):Float = 1;
	public function new(x:Float = 0, y:Float = 0, ?checked = false, ?scaleMult:Float = 1) {
		super(x, y);

		this.scaleMult = scaleMult;

		frames = Paths.getSparrowAtlas('checkboxanim');
		animation.addByPrefix("unchecked", "checkbox0", 24, false);
		animation.addByPrefix("unchecking", "checkbox anim reverse", 24, false);
		animation.addByPrefix("checking", "checkbox anim0", 24, false);
		animation.addByPrefix("checked", "checkbox finish", 24, false);

		antialiasing = ClientPrefs.data.antialiasing;
		setGraphicSize(Std.int(0.9 * scaleMult * width));
		updateHitbox();

		animationFinished(checked ? 'checking' : 'unchecking');
		animation.finishCallback = animationFinished;
		daValue = checked;
	}

	override function update(elapsed:Float) {
		if (sprTracker != null) {
			setPosition(sprTracker.x - 130 + offsetX, sprTracker.y + 30 + offsetY);
			if(copyAlpha) {
				alpha = sprTracker.alpha;
			}
		}
		super.update(elapsed);
	}

	private function set_daValue(check:Bool):Bool {
		if(check) {
			if(animation.curAnim.name != 'checked' && animation.curAnim.name != 'checking') {
				animation.play('checking', true);
				setOffset(34, 25);
			}
		} else if(animation.curAnim.name != 'unchecked' && animation.curAnim.name != 'unchecking') {
			animation.play("unchecking", true);
			setOffset(25, 28);
		}
		return check;
	}

	inline function setOffset(x:Float, y:Float)
		offset.set(x * scaleMult, y * scaleMult);

	private function animationFinished(name:String)
	{
		switch(name)
		{
			case 'checking':
				animation.play('checked', true);
				setOffset(3, 12);

			case 'unchecking':
				animation.play('unchecked', true);
				setOffset(0, 2);
		}
	}
}