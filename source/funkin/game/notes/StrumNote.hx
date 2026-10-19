package funkin.game.notes;

import funkin.graphics.PsychAnimationController;

import funkin.graphics.shaders.RGBPalette;
import funkin.graphics.shaders.RGBPalette.RGBShaderReference;
import funkin.data.NotePackData;

class StrumNote extends FlxSprite
{
	public var rgbShader:RGBShaderReference;
	public var resetAnim:Float = 0;
	public var holdCover:HoldCover;
	private var noteData:Int = 0;
	public var direction:Float = 90;
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;
	private var player:Int;
	
	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	public var useRGBShader:Bool = true;
	public var originalR:FlxColor = 0xFFFFFFFF;
	public var originalG:FlxColor = 0xFFFFFFFF;
	public var originalB:FlxColor = 0xFFFFFFFF;
	public var lastQuantR:FlxColor = 0xFFFFFFFF;
	public var lastQuantG:FlxColor = 0xFFFFFFFF;
	public var lastQuantB:FlxColor = 0xFFFFFFFF;
	public var hasQuantColor:Bool = false;

	public var packOpponent:Bool = false;
	public var packPart(default, null):NotePackPart = null;

	public static var TINT_GLOW:Float = 0.3;
	public var tintColor(default, set):FlxColor = FlxColor.WHITE;
	public var tintStrength(default, set):Float = 0;
	public var baseTintColor:FlxColor = FlxColor.WHITE;
	public var baseTintStrength:Float = 0;
	public var tintTweenId:Int = 0;
	var tintApplied:Bool = false;

	function set_tintColor(value:FlxColor):FlxColor
	{
		tintColor = value;
		updateColorTransform();
		return value;
	}

	function set_tintStrength(value:Float):Float
	{
		tintStrength = Math.max(0, Math.min(1, value));
		updateColorTransform();
		return tintStrength;
	}

	public function setTint(color:FlxColor, strength:Float)
	{
		@:bypassAccessor tintColor = color;
		tintStrength = strength;
	}

	public function applyBaseTint()
	{
		var tint:NotePackTint = NotePack.tintFor(packOpponent);
		baseTintColor = (tint != null) ? CoolUtil.colorFromString(tint.color) : FlxColor.WHITE;
		baseTintStrength = (tint != null) ? tint.strength : 0;
		setTint(baseTintColor, baseTintStrength);
	}

	override function updateColorTransform():Void
	{
		super.updateColorTransform();
		if(colorTransform == null) return;

		if(tintStrength <= 0)
		{
			if(tintApplied)
			{
				colorTransform.redOffset = colorTransform.greenOffset = colorTransform.blueOffset = 0;
				tintApplied = false;
			}
			return;
		}

		colorTransform.redMultiplier *= 1 + tintStrength * (tintColor.redFloat - 1);
		colorTransform.greenMultiplier *= 1 + tintStrength * (tintColor.greenFloat - 1);
		colorTransform.blueMultiplier *= 1 + tintStrength * (tintColor.blueFloat - 1);
		colorTransform.redOffset = tintStrength * tintColor.red * TINT_GLOW;
		colorTransform.greenOffset = tintStrength * tintColor.green * TINT_GLOW;
		colorTransform.blueOffset = tintStrength * tintColor.blue * TINT_GLOW;
		useColorTransform = true;
		tintApplied = true;
	}

	public function new(x:Float, y:Float, leData:Int, player:Int, ?opponentSide:Null<Bool>) {
		packOpponent = (opponentSide != null) ? opponentSide : (player < 1);
		animation = new PsychAnimationController(this);

		var ownPalette:RGBPalette = new RGBPalette();
		rgbShader = new RGBShaderReference(this, ownPalette);
		rgbShader.enabled = false;
		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;
		
		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[leData];
		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[leData];
		
		if(leData <= arr.length)
		{
			originalR = arr[0];
			originalG = arr[1];
			originalB = arr[2];
			rgbShader.parent.r = arr[0];
			rgbShader.parent.g = arr[1];
			rgbShader.parent.b = arr[2];
		}

		noteData = leData;
		this.player = player;
		this.noteData = leData;
		this.ID = noteData;
		super(x, y);

		var skin:String = null;
		var skinPostfix:String = PlayState.isPixelStage ? '' : Note.getNoteSkinPostfix();
		var chartSkin:String = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
		var chartHasSkin:Bool = (chartSkin != null && chartSkin.length > 0);
		
		if(ClientPrefs.data.useChartNoteSkins && chartHasSkin)
		{
			skin = chartSkin;
			var customSkin:String = skin + skinPostfix;
			if(Paths.fileExists('images/$customSkin.png', IMAGE))
				skin = customSkin;
		}
		else
		{
			var personalSkin:String = Note.defaultNoteSkin + skinPostfix;
			if(Paths.fileExists('images/$personalSkin.png', IMAGE))
				skin = personalSkin;
			else
			{
				var legacySkin:String = Note.defaultNoteSkin + '-' + ClientPrefs.data.noteSkin.trim().toLowerCase().replace(' ', '_');
				if(Paths.fileExists('images/$legacySkin.png', IMAGE))
					skin = legacySkin;
				else
					skin = Note.defaultNoteSkin;
			}
		}

		texture = skin;
		scrollFactor.set();
		playAnim('static');
		applyBaseTint();
	}

	public function reloadNote()
	{
		var lastAnim:String = null;
		if(animation.curAnim != null) lastAnim = animation.curAnim.name;

		packPart = NotePack.partFor('strums', packOpponent);
		if(packPart != null && loadPackStrum())
		{
			if(lastAnim != null) playAnim(lastAnim, true);
			return;
		}
		packPart = null;

		if(PlayState.isPixelStage)
		{
			loadGraphic(Paths.image('pixelUI/' + texture));
			width = width / 4;
			height = height / 5;
			loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));

			antialiasing = false;
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));

			animation.add('green', [6]);
			animation.add('red', [7]);
			animation.add('blue', [5]);
			animation.add('purple', [4]);
			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.add('static', [0]);
					animation.add('pressed', [4, 8], 12, false);
					animation.add('confirm', [12, 16], 24, false);
				case 1:
					animation.add('static', [1]);
					animation.add('pressed', [5, 9], 12, false);
					animation.add('confirm', [13, 17], 24, false);
				case 2:
					animation.add('static', [2]);
					animation.add('pressed', [6, 10], 12, false);
					animation.add('confirm', [14, 18], 12, false);
				case 3:
					animation.add('static', [3]);
					animation.add('pressed', [7, 11], 12, false);
					animation.add('confirm', [15, 19], 24, false);
			}
		}
		else
		{
			frames = Paths.getSparrowAtlas(texture);
			animation.addByPrefix('green', 'arrowUP');
			animation.addByPrefix('blue', 'arrowDOWN');
			animation.addByPrefix('purple', 'arrowLEFT');
			animation.addByPrefix('red', 'arrowRIGHT');

			antialiasing = ClientPrefs.data.antialiasing;
			setGraphicSize(Std.int(width * 0.7));

			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.addByPrefix('static', 'arrowLEFT');
					animation.addByPrefix('pressed', 'left press', 24, false);
					animation.addByPrefix('confirm', 'left confirm', 24, false);
				case 1:
					animation.addByPrefix('static', 'arrowDOWN');
					animation.addByPrefix('pressed', 'down press', 24, false);
					animation.addByPrefix('confirm', 'down confirm', 24, false);
				case 2:
					animation.addByPrefix('static', 'arrowUP');
					animation.addByPrefix('pressed', 'up press', 24, false);
					animation.addByPrefix('confirm', 'up confirm', 24, false);
				case 3:
					animation.addByPrefix('static', 'arrowRIGHT');
					animation.addByPrefix('pressed', 'right press', 24, false);
					animation.addByPrefix('confirm', 'right confirm', 24, false);
			}
		}
		updateHitbox();

		if(lastAnim != null)
		{
			playAnim(lastAnim, true);
		}
	}

	function loadPackStrum():Bool
	{
		var gridded:Bool = NotePack.isGridded(packPart);
		if(!NotePack.loadImage(this, packPart.image, gridded ? packPart.grid : null)) return false;

		@:privateAccess animation.clearAnimations();
		var direction:Int = Std.int(Math.abs(noteData) % 4);
		for (name in ['static', 'pressed', 'confirm'])
			NotePack.addAnimation(this, name, NotePackData.anim(packPart, direction, name), gridded);

		antialiasing = NotePack.antialiasingOf(packPart);
		var size:Float = (packPart.scale != null) ? packPart.scale : (gridded ? PlayState.daPixelZoom : 0.7);
		setGraphicSize(Std.int(width * size));
		useRGBShader = packPart.rgb != false && !(PlayState.SONG != null && PlayState.SONG.disableNoteRGB);
		updateHitbox();
		return true;
	}

	public function refreshPack()
		reloadNote();

	public function playerPosition()
	{
		x += Note.swagWidth * noteData;
		x += 50;
		x += ((FlxG.width / 2) * player);
	}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		if(animation.curAnim != null)
		{
			centerOffsets();
			centerOrigin();
			if(packPart != null)
			{
				if(packPart.offsets != null && packPart.offsets.length > 1)
				{
					offset.x += packPart.offsets[0];
					offset.y += packPart.offsets[1];
				}
				var packAnim:NotePackAnim = NotePackData.anim(packPart, Std.int(Math.abs(noteData) % 4), animation.curAnim.name);
				if(packAnim != null && packAnim.offsets != null && packAnim.offsets.length > 1)
				{
					offset.x += packAnim.offsets[0];
					offset.y += packAnim.offsets[1];
				}
			}
		}
		if(animation.curAnim != null)
		{
			var isStatic:Bool = animation.curAnim.name == 'static';
			if(hasQuantColor && !isStatic)
			{
				rgbShader.parent.r = lastQuantR;
				rgbShader.parent.g = lastQuantG;
				rgbShader.parent.b = lastQuantB;
				rgbShader.enabled = true;
			}
			else if(!isStatic)
			{
				rgbShader.parent.r = originalR;
				rgbShader.parent.g = originalG;
				rgbShader.parent.b = originalB;
				rgbShader.enabled = useRGBShader;
			}
			else
			{
				rgbShader.parent.r = originalR;
				rgbShader.parent.g = originalG;
				rgbShader.parent.b = originalB;
				rgbShader.enabled = false;
			}
		}
	}
}
