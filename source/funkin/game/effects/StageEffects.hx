package funkin.game.effects;

import flixel.FlxBasic;
import funkin.scripting.LuaUtils;
import flixel.tweens.FlxEase.EaseFunction;
import funkin.graphics.shaders.SilhouetteShader;

class TintState
{
	public var red:Float = 0;
	public var green:Float = 0;
	public var blue:Float = 0;
	public var amount:Float = 0;

	public function new() {}
}

class StageEffects extends FlxBasic
{
	public var silhouetteBackground:FlxSprite;
	public var flashBackground:FlxSprite;

	var game:PlayState;
	var silhouetteColor:Null<FlxColor> = null;
	var silhouetteColors:Map<String, FlxColor> = [];
	var characterAlphaFrom:Float = 1;
	var characterAlphaTo:Float = 1;
	var characterAlpha:Float = 1;
	var silhouetteDetails:Bool = false;
	var detailShaders:Map<FlxSprite, SilhouetteShader> = [];
	var savedShaders:Map<FlxSprite, Dynamic> = [];
	var silhouetteAmount:Float = 0;
	var silhouetteHud:Bool = false;
	var silhouetteProgress:Float = 1;
	var silhouetteFrom:Map<FlxSprite, TintState> = [];
	var silhouetteTween:FlxTween;
	var backgroundFromColor:FlxColor = FlxColor.BLACK;
	var backgroundFromAlpha:Float = 0;
	var backgroundToColor:FlxColor = FlxColor.BLACK;
	var backgroundToAlpha:Float = 0;

	var flashAmount:Float = 0;
	var flashCharacterColor:Null<FlxColor> = null;
	var flashTween:FlxTween;

	var touched:Array<FlxSprite> = [];

	public function new(game:PlayState)
	{
		super();
		this.game = game;

		silhouetteBackground = makeBackground();
		flashBackground = makeBackground();
		placeBackgrounds();

		FlxG.signals.preDraw.add(applyTints);
	}

	function placeBackgrounds()
	{
		game.remove(flashBackground, true);
		game.remove(silhouetteBackground, true);
		var layer:Int = game.members.indexOf(LuaUtils.getLowestCharacterGroup());
		if(layer < 0) layer = game.members.length;
		for (trail in game.ghostTrails)
		{
			var trailLayer:Int = game.members.indexOf(trail);
			if(trailLayer > -1 && trailLayer < layer) layer = trailLayer;
		}
		game.insert(layer, flashBackground);
		game.insert(layer, silhouetteBackground);
	}

	function makeBackground():FlxSprite
	{
		var sprite:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		sprite.setGraphicSize(FlxG.width * 4, FlxG.height * 4);
		sprite.updateHitbox();
		sprite.screenCenter();
		sprite.scrollFactor.set();
		sprite.alpha = 0;
		sprite.visible = false;
		sprite.cameras = [game.camGame];
		return sprite;
	}

	public function setSilhouette(enabled:Bool, characterColor:Null<FlxColor>, characterColors:Map<String, FlxColor>, backgroundColor:FlxColor, strength:Float, backgroundAlpha:Float, charactersAlpha:Float, duration:Float, ease:EaseFunction, hud:Bool, details:Bool = false)
	{
		placeBackgrounds();
		var newHud:Bool = enabled ? hud : silhouetteHud;
		for (sprite in targets(silhouetteHud || newHud))
			silhouetteFrom.set(sprite, silhouetteNow(sprite));

		backgroundFromColor = silhouetteBackground.color;
		backgroundFromAlpha = silhouetteBackground.alpha;
		characterAlphaFrom = characterAlpha;
		if(enabled)
		{
			silhouetteColor = characterColor;
			silhouetteColors = (characterColors != null) ? characterColors : [];
			silhouetteDetails = details;
			silhouetteAmount = FlxMath.bound(strength, 0, 1);
			backgroundToColor = backgroundColor;
			backgroundToAlpha = FlxMath.bound(backgroundAlpha, 0, 1);
			characterAlphaTo = FlxMath.bound(charactersAlpha, 0, 1);
		}
		else
		{
			silhouetteAmount = 0;
			backgroundToAlpha = 0;
			characterAlphaTo = 1;
			if(backgroundFromAlpha <= 0) backgroundFromColor = backgroundToColor;
		}
		silhouetteHud = newHud;

		if(silhouetteTween != null) silhouetteTween.cancel();
		silhouetteTween = null;
		if(duration <= 0)
		{
			setSilhouetteProgress(1);
			return;
		}

		setSilhouetteProgress(0);
		silhouetteTween = FlxTween.num(0, 1, duration / game.playbackRate, {ease: ease, onComplete: function(_) silhouetteTween = null}, setSilhouetteProgress);
	}

	function setSilhouetteProgress(progress:Float)
	{
		silhouetteProgress = progress;
		silhouetteBackground.color = FlxColor.interpolate(backgroundFromColor, backgroundToColor, progress);
		silhouetteBackground.alpha = FlxMath.lerp(backgroundFromAlpha, backgroundToAlpha, progress);
		silhouetteBackground.visible = silhouetteBackground.alpha > 0;
		characterAlpha = FlxMath.lerp(characterAlphaFrom, characterAlphaTo, progress);
	}

	public function backgroundFlash(color:FlxColor, duration:Float, characterColor:Null<FlxColor>, ease:EaseFunction)
	{
		placeBackgrounds();
		if(flashTween != null) flashTween.cancel();
		flashTween = null;
		flashBackground.color = color;
		flashCharacterColor = characterColor;
		if(duration <= 0) duration = 1;
		setFlashAmount(1);
		flashTween = FlxTween.num(1, 0, duration / game.playbackRate, {ease: ease, onComplete: function(_) flashTween = null}, setFlashAmount);
	}

	function setFlashAmount(amount:Float)
	{
		flashAmount = amount;
		flashBackground.alpha = amount;
		flashBackground.visible = amount > 0;
	}

	function silhouetteTarget(sprite:FlxSprite):TintState
	{
		var state:TintState = new TintState();
		state.amount = silhouetteAmount;
		var color:FlxColor = targetColor(sprite);
		state.red = color.red * silhouetteAmount;
		state.green = color.green * silhouetteAmount;
		state.blue = color.blue * silhouetteAmount;
		return state;
	}

	function targetColor(sprite:FlxSprite):FlxColor
	{
		var key:String = spriteKey(sprite);
		if(key != null && silhouetteColors.exists(key)) return silhouetteColors.get(key);
		if(silhouetteColor != null) return silhouetteColor;
		var char:Character = Std.isOfType(sprite, Character) ? cast sprite : characterFromKey(key);
		if(char != null)
		{
			var colors:Array<Int> = char.healthColorArray;
			if(colors != null && colors.length > 2) return FlxColor.fromRGB(colors[0], colors[1], colors[2]);
		}
		return FlxColor.BLACK;
	}

	function spriteKey(sprite:FlxSprite):String
	{
		if(sprite == game.iconP1) return 'bf';
		if(sprite == game.iconP2) return 'dad';
		if(game.healthBar != null)
		{
			if(sprite == game.healthBar.leftBar) return 'dad';
			if(sprite == game.healthBar.rightBar) return 'bf';
		}
		return Std.isOfType(sprite, Character) ? game.characterKey(cast sprite) : null;
	}

	function characterFromKey(key:String):Character
	{
		return switch(key)
		{
			case 'bf': game.boyfriend;
			case 'dad': game.dad;
			default: null;
		}
	}

	function silhouetteNow(sprite:FlxSprite):TintState
	{
		var target:TintState = silhouetteTarget(sprite);
		var from:TintState = silhouetteFrom.get(sprite);
		if(from == null || silhouetteProgress >= 1) return target;

		var state:TintState = new TintState();
		state.red = FlxMath.lerp(from.red, target.red, silhouetteProgress);
		state.green = FlxMath.lerp(from.green, target.green, silhouetteProgress);
		state.blue = FlxMath.lerp(from.blue, target.blue, silhouetteProgress);
		state.amount = FlxMath.lerp(from.amount, target.amount, silhouetteProgress);
		return state;
	}

	function targets(hud:Bool):Array<FlxSprite>
	{
		var list:Array<FlxSprite> = [];
		for (char in [game.boyfriend, game.dad, game.gf]) if(char != null) list.push(char);
		for (char in game.extraCharacters) if(char != null) list.push(char);
		if(hud)
		{
			if(game.iconP1 != null) list.push(game.iconP1);
			if(game.iconP2 != null) list.push(game.iconP2);
			if(game.healthBar != null)
				for (sprite in [game.healthBar.leftBar, game.healthBar.rightBar]) if(sprite != null) list.push(sprite);
		}
		return list;
	}

	function isIdle():Bool
	{
		if(silhouetteTween != null || flashTween != null) return false;
		return silhouetteAmount <= 0 && flashAmount <= 0 && characterAlpha >= 1;
	}

	function applyTints()
	{
		if(!exists || game == null) return;
		if(isIdle())
		{
			if(touched.length > 0)
			{
				for (sprite in touched) restoreSprite(sprite);
				touched = [];
				silhouetteFrom.clear();
			}
			return;
		}

		var list:Array<FlxSprite> = targets(silhouetteHud);
		for (sprite in touched) if(!list.contains(sprite)) restoreSprite(sprite);
		touched = list;

		for (sprite in list)
		{
			var tint:TintState = silhouetteNow(sprite);
			var useShader:Bool = silhouetteDetails && tint.amount > 0;
			var keep:Float = useShader ? 1 : 1 - tint.amount;
			var red:Float = useShader ? 0 : tint.red;
			var green:Float = useShader ? 0 : tint.green;
			var blue:Float = useShader ? 0 : tint.blue;
			if(flashAmount > 0 && flashCharacterColor != null && Std.isOfType(sprite, Character))
			{
				var rest:Float = 1 - flashAmount;
				keep *= rest;
				red = red * rest + flashCharacterColor.red * flashAmount;
				green = green * rest + flashCharacterColor.green * flashAmount;
				blue = blue * rest + flashCharacterColor.blue * flashAmount;
			}
			apply(sprite, keep, red, green, blue, Std.isOfType(sprite, Character) ? characterAlpha : 1);
			if(useShader) setDetailShader(sprite, tint);
			else clearDetailShader(sprite);
		}
	}

	function setDetailShader(sprite:FlxSprite, tint:TintState)
	{
		var shader:SilhouetteShader = detailShaders.get(sprite);
		if(shader == null)
		{
			shader = new SilhouetteShader();
			detailShaders.set(sprite, shader);
			savedShaders.set(sprite, sprite.shader);
		}
		if(sprite.shader != shader) sprite.shader = shader;
		var color:FlxColor = FlxColor.fromRGB(Math.round(tint.red / tint.amount), Math.round(tint.green / tint.amount), Math.round(tint.blue / tint.amount));
		shader.setColor(color, tint.amount);
	}

	function clearDetailShader(sprite:FlxSprite)
	{
		if(!detailShaders.exists(sprite)) return;
		if(sprite.shader == detailShaders.get(sprite)) sprite.shader = savedShaders.get(sprite);
		detailShaders.remove(sprite);
		savedShaders.remove(sprite);
	}

	function restoreSprite(sprite:FlxSprite)
	{
		if(sprite == null) return;
		clearDetailShader(sprite);
		restore(sprite);
	}

	static function apply(sprite:FlxSprite, keep:Float, red:Float, green:Float, blue:Float, alpha:Float)
	{
		var transform = sprite.colorTransform;
		if(transform == null) return;
		if(Std.isOfType(sprite, Character)) cast(sprite, Character).forceRenderTexture = true;
		transform.redMultiplier = sprite.color.redFloat * keep;
		transform.greenMultiplier = sprite.color.greenFloat * keep;
		transform.blueMultiplier = sprite.color.blueFloat * keep;
		transform.alphaMultiplier = sprite.alpha * alpha;
		transform.redOffset = red;
		transform.greenOffset = green;
		transform.blueOffset = blue;
		@:privateAccess sprite.useColorTransform = true;
		sprite.dirty = true;
	}

	static function restore(sprite:FlxSprite)
	{
		if(sprite == null) return;
		if(Std.isOfType(sprite, Character)) cast(sprite, Character).forceRenderTexture = false;
		if(sprite.colorTransform == null) return;
		sprite.colorTransform.redOffset = sprite.colorTransform.greenOffset = sprite.colorTransform.blueOffset = 0;
		@:privateAccess sprite.updateColorTransform();
	}

	override function destroy()
	{
		FlxG.signals.preDraw.remove(applyTints);
		if(silhouetteTween != null) silhouetteTween.cancel();
		if(flashTween != null) flashTween.cancel();
		for (sprite in touched) restoreSprite(sprite);
		touched = null;
		silhouetteFrom = null;
		game = null;
		super.destroy();
	}
}
