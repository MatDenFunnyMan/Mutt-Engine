package funkin.game.notes;

import funkin.graphics.PsychAnimationController;
import funkin.graphics.shaders.RGBPalette;
import flixel.system.FlxAssets.FlxShader;
import funkin.data.NotePackData;

typedef RGB = {
	r:Null<Int>,
	g:Null<Int>,
	b:Null<Int>
}

typedef NoteSplashAnim = {
	name:String,
	noteData:Int,
	prefix:String,
	indices:Array<Int>,
	offsets:Array<Float>,
	fps:Array<Int>
}

typedef NoteSplashConfig = {
	animations:Map<String, NoteSplashAnim>,
	scale:Float,
	allowRGB:Bool,
	allowPixel:Bool,
	rgb:Array<Null<RGB>>
}

class NoteSplash extends FlxSprite
{
	public var rgbShader:PixelSplashShaderRef;
	public var texture:String;
	public var config(default, set):NoteSplashConfig;
	public var babyArrow:StrumNote;
	public var noteData:Int = 0;

	public var baseAlpha:Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var inEditor:Bool = false;

	var spawned:Bool = false;
	var noteDataMap:Map<Int, String> = new Map();

	public static var defaultNoteSplash(default, never):String = "noteSplashes/noteSplashes";
	public static var pixelNoteSplash(default, never):String = "pixelUI/pixelNoteSplash";
	static final PIXEL_SPLASH_SCALE:Float = 3.5;
	static final PIXEL_SPLASH_ALPHA:Float = 1;
	static final PIXEL_SPLASH_OFFSETS:Array<Float> = [-140.8, -135];

	static function pixelOverride(splash:String):String
	{
		if (PlayState.isPixelStage && splash == defaultNoteSplash && Paths.fileExists('images/$pixelNoteSplash.png', IMAGE))
			return pixelNoteSplash;
		return splash;
	}
	public static var configs:Map<String, NoteSplashConfig> = new Map();

	public function new(?x:Float = 0, ?y:Float = 0, ?splash:String)
	{
		super(x, y);

		animation = new PsychAnimationController(this);

		rgbShader = new PixelSplashShaderRef();
		shader = rgbShader.shader;

		loadSplash(splash);
	}

	public var maxAnims(default, set):Int = 0;
	public function loadSplash(?splash:String)
	{
		config = null;
		maxAnims = 0;
		loadedPack = null;

		if((splash == null || splash.length == 0) && !inEditor)
		{
			var packPart:NotePackPart = NotePack.partFor('splashes', false);
			if(packPart != null)
			{
				if(packPart.animations != null && loadPackSplash(packPart)) return;
				splash = packPart.image;
			}
		}

		if(splash == null || splash.length == 0)
		{
			var splashPostfix:String = getSplashSkinPostfix();
			var chartSplash:String = PlayState.SONG != null ? PlayState.SONG.splashSkin : null;
			var chartHasSplash:Bool = (chartSplash != null && chartSplash.length > 0);
			
			if(ClientPrefs.data.useChartNoteSkins && chartHasSplash)
			{
				splash = chartSplash;
			}
			else
			{
				var personalSplash:String = defaultNoteSplash + splashPostfix;
				if(Paths.fileExists('images/$personalSplash.png', IMAGE))
					splash = personalSplash;
				else
					splash = defaultNoteSplash;
			}
		}

		splash = pixelOverride(splash);
		texture = splash;
		if (Paths.fileExists('images/$texture.png', IMAGE))
			frames = Paths.getSparrowAtlas(texture);

		if (frames != null && texture == pixelNoteSplash)
		{
			var path:String = 'images/$texture';
			if (!configs.exists(path))
			{
				var pixelConfig:NoteSplashConfig = createConfig();
				pixelConfig.allowRGB = false;
				pixelConfig.allowPixel = false;
				for (animNum in 0...3)
					for (i => col in ['purple', 'blue', 'green', 'orange'])
					{
						var name:String = animNum > 0 ? Note.colArray[i] + (animNum + 1) : Note.colArray[i];
						addAnimationToConfig(pixelConfig, PIXEL_SPLASH_SCALE, name, '$col${animNum + 1}', [31, 35], PIXEL_SPLASH_OFFSETS.copy(), [], i + animNum * 4);
					}
				configs.set(path, pixelConfig);
			}
			this.config = configs.get(path);
			maxAnims = 3;
			return;
		}

		if (frames == null)
		{
			texture = 'noteSplashes/noteSplashes' + getSplashSkinPostfix();
			if (Paths.fileExists('images/$texture.png', IMAGE))
				frames = Paths.getSparrowAtlas(texture);
		}
		
		if (frames == null)
		{
			texture = defaultNoteSplash;
			if (Paths.fileExists('images/$texture.png', IMAGE))
				frames = Paths.getSparrowAtlas(texture);
		}
		
		if (frames == null)
		{
			visible = false;
			return;
		}

		var path:String = 'images/$texture';
		if (configs.exists(path))
		{
			this.config = configs.get(path);
			for (anim in this.config.animations)
			{
				if (anim.noteData % 4 == 0)
					maxAnims++;
			}
			return;
		}
		else if (Paths.fileExists('$path.json', TEXT))
		{
			var config:Dynamic = haxe.Json.parse(Paths.getTextFromFile('$path.json'));
			if (config != null)
			{
				var tempConfig:NoteSplashConfig = {
					animations: new Map(),
					scale: config.scale,
					allowRGB: config.allowRGB,
					allowPixel: config.allowPixel,
					rgb: config.rgb
				}

				for (i in Reflect.fields(config.animations))
				{
					var anim:NoteSplashAnim = Reflect.field(config.animations, i);
					tempConfig.animations.set(i, anim);
					if (anim.noteData % 4 == 0)
						maxAnims++;
				}

				this.config = tempConfig;
				configs.set(path, this.config);
				return;
			}
		}

		// Splashes with no json
		var tempConfig:NoteSplashConfig = createConfig();
		var anim:String = 'note splash';
		var fps:Array<Null<Int>> = [22, 26];
		var offsets:Array<Array<Float>> = [[0, 0]];
		if (Paths.fileExists('$path.txt', TEXT)) // Backwards compatibility with 0.7 splash txts
		{
			var configFile:Array<String> = CoolUtil.listFromString(Paths.getTextFromFile('$path.txt'));
			if (configFile.length > 0)
			{
				anim = configFile[0];
				if (configFile.length > 1)
				{
					var framerates:Array<String> = configFile[1].split(' ');
					fps = [Std.parseInt(framerates[0]), Std.parseInt(framerates[1])];
					if (fps[0] == null) fps[0] = 22;
					if (fps[1] == null) fps[1] = 26;

					if (configFile.length > 2)
					{
						offsets = [];
						for (i in 2...configFile.length)
						{
							if (configFile[i].trim() != '')
							{
								var animOffs:Array<String> = configFile[i].split(' ');
								var x:Float = Std.parseFloat(animOffs[0]);
								var y:Float = Std.parseFloat(animOffs[1]);
								if (Math.isNaN(x)) x = 0;
								if (Math.isNaN(y)) y = 0;
								offsets.push([x, y]);
							}
						}
					}
				}
			}
		}

		var failedToFind:Bool = false;
		while (true)
		{
			for (v in Note.colArray)
			{
				if (!checkForAnim('$anim $v ${maxAnims+1}'))
				{
					failedToFind = true;
					break;
				}
			}
			if (failedToFind) break;
			maxAnims++;
		}

		for (animNum in 0...maxAnims)
		{
			for (i => col in Note.colArray)
			{
				var data:Int = i % Note.colArray.length + (animNum * Note.colArray.length);
				var name:String = animNum > 0 ? '$col' + (animNum + 1) : col;
				var offset:Array<Float> = offsets[FlxMath.wrap(data, 0, Std.int(offsets.length-1))];
				addAnimationToConfig(tempConfig, 1, name, '$anim $col ${animNum + 1}', fps, offset, [], data);
			}
		}

		this.config = tempConfig;
		configs.set(path, this.config);
	}

	var loadedPack:NotePackPart = null;
	static var packConfigs:Map<String, NoteSplashConfig> = new Map();

	function loadPackSplash(part:NotePackPart):Bool
	{
		if (!Paths.fileExists('images/${part.image}.png', IMAGE)) return false;
		var atlas = Paths.getSparrowAtlas(part.image);
		if (atlas == null) return false;
		frames = atlas;
		texture = part.image;

		var key:String = part.image + '|' + part.scale + '|' + part.rgb + '|' + part.offsets + '|' + haxe.Json.stringify(part.animations);
		var packConfig:NoteSplashConfig = packConfigs.get(key);
		var variants:Int = 0;
		for (i in 0...Note.colArray.length)
		{
			var list:Array<NotePackAnim> = NotePackData.splashAnims(part, i);
			var count:Int = (list != null) ? list.length : 0;
			if (variants == 0 || count < variants) variants = count;
		}
		if (variants < 1) return false;

		if (packConfig == null)
		{
			packConfig = createConfig();
			packConfig.allowRGB = part.rgb != false;
			packConfig.allowPixel = false;
			var size:Float = (part.scale != null) ? part.scale : 1;
			var base:Array<Float> = (part.offsets != null && part.offsets.length > 1) ? part.offsets : [0, 0];
			for (i => col in Note.colArray)
			{
				var list:Array<NotePackAnim> = NotePackData.splashAnims(part, i);
				for (variant in 0...variants)
				{
					var anim:NotePackAnim = list[variant];
					if (anim == null || anim.prefix == null) continue;
					var fps:Int = Std.int((anim.fps != null) ? anim.fps : 24);
					var name:String = variant > 0 ? col + (variant + 1) : col;
					var offsets:Array<Float> = (anim.offsets != null && anim.offsets.length > 1) ? [base[0] + anim.offsets[0], base[1] + anim.offsets[1]] : base.copy();
					var prefix:String = anim.prefix;
					for (candidate in NotePackData.prefixCandidates(anim.prefix))
						if (NotePack.hasPrefix(this, candidate)) { prefix = candidate; break; }
					addAnimationToConfig(packConfig, size, name, prefix, [fps, fps], offsets, (anim.indices != null) ? anim.indices : [], i + variant * Note.colArray.length);
				}
			}
			packConfigs.set(key, packConfig);
		}

		config = packConfig;
		maxAnims = variants;
		loadedPack = part;
		antialiasing = NotePack.antialiasingOf(part);
		return true;
	}

	function usePackSplash(part:NotePackPart)
	{
		config = null;
		maxAnims = 0;
		loadedPack = null;
		if (!loadPackSplash(part)) loadSplash();
	}

	function applyPackColors(tempShader:RGBPalette, part:NotePackPart)
	{
		var colors:Array<FlxColor> = NotePackData.packColors(part, noteData);
		if (colors == null) return;
		tempShader.r = colors[0];
		tempShader.g = colors[1];
		tempShader.b = colors[2];
	}

	public function spawnSplashNote(?x:Float = 0, ?y:Float = 0, ?noteData:Int = 0, ?note:Note, ?randomize:Bool = true)
	{
		if (note != null && note.noteSplashData.disabled)
			return;

		aliveTime = 0;
		var colorPart:NotePackPart = null;

		if (!inEditor)
		{
			var loadedTexture:String = defaultNoteSplash + getSplashSkinPostfix();
			var chartSplash:String = PlayState.SONG != null ? PlayState.SONG.splashSkin : null;
			var chartHasSplash:Bool = (chartSplash != null && chartSplash.length > 0);
			var noteTexture:String = (note != null) ? note.noteSplashData.texture : null;
			if (noteTexture == chartSplash) noteTexture = null;
			var packPart:NotePackPart = (noteTexture == null) ? NotePack.partFor('splashes', false) : null;
			var typePack:NotePack = (note != null) ? note.typePack : null;
			if (typePack != null)
			{
				var typeSplash:NotePackPart = typePack.typePart('splashes', false, PlayState.isPixelStage, packPart);
				if (typeSplash != null) packPart = typeSplash;
			}
			colorPart = packPart;
			if (typePack != null)
			{
				var raw:NotePackPart = typePack.rawPart('splashes', false, PlayState.isPixelStage);
				if (raw != null && raw.colors != null) colorPart = raw;
			}

			if (packPart != null && packPart.animations != null)
			{
				if (loadedPack != packPart) usePackSplash(packPart);
				loadedTexture = texture;
			}
			else if (packPart != null)
			{
				loadedTexture = packPart.image;
			}
			else if (note != null && note.noteSplashData.texture != null)
			{
				loadedTexture = note.noteSplashData.texture;
			}
			else if (ClientPrefs.data.useChartNoteSkins && chartHasSplash)
			{
				loadedTexture = chartSplash;
			}
			else
			{
				var personalSplash:String = defaultNoteSplash + getSplashSkinPostfix();
				if(Paths.fileExists('images/$personalSplash.png', IMAGE))
					loadedTexture = personalSplash;
				else
					loadedTexture = defaultNoteSplash;
			}

			if (loadedPack != null && (packPart == null || packPart.animations == null))
			{
				loadedPack = null;
				texture = null;
			}

			if (loadedPack == null)
			{
				loadedTexture = pixelOverride(loadedTexture);
				if (texture != loadedTexture) loadSplash(loadedTexture);
			}
		}

		setPosition(x, y);

		if (babyArrow != null)
			setPosition(babyArrow.x - Note.swagWidth * 0.95, babyArrow.y - Note.swagWidth); // To prevent it from being misplaced for one game tick

		if (note != null)
			noteData = note.noteData;

		if (randomize && maxAnims > 1)
			noteData = noteData % Note.colArray.length + (FlxG.random.int(0, maxAnims - 1) * Note.colArray.length);

		this.noteData = noteData;
		var anim:String = playDefaultAnim();

		var tempShader:RGBPalette = null;
		if (config.allowRGB)
		{
			Note.initializeGlobalRGBShader(noteData % Note.colArray.length);
			if (inEditor || (note == null || note.noteSplashData.useRGBShader) && (PlayState.SONG == null || !PlayState.SONG.disableSplashRGB))
			{
				tempShader = new RGBPalette();
				// If Note RGB is enabled:
				if ((note == null || !note.noteSplashData.useGlobalShader) || inEditor)
				{
					var colors = config.rgb;
					if (colors != null)
					{
						for (i in 0...colors.length)
						{
							if (i > 2) break;

							var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[noteData % Note.colArray.length];
							if (PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[noteData % Note.colArray.length];

							var rgb = colors[i];
							if (rgb == null)
							{
								if (i == 0) tempShader.r = arr[0];
								else if (i == 1) tempShader.g = arr[1];
								else if (i == 2) tempShader.b = arr[2];
								continue;
							}

							var r:Null<Int> = rgb.r; 
							var g:Null<Int> = rgb.g;
							var b:Null<Int> = rgb.b;

							if (r == null || Math.isNaN(r) || r < 0) r = arr[0];
							if (g == null || Math.isNaN(g) || g < 0) g = arr[1];
							if (b == null || Math.isNaN(b) || b < 0) b = arr[2];

							var color:FlxColor = FlxColor.fromRGB(r, g, b);
							if (i == 0) tempShader.r = color;
							else if (i == 1) tempShader.g = color;
							else if (i == 2) tempShader.b = color;
						}
					}
					else tempShader.copyValues(Note.globalRgbShaders[noteData % Note.colArray.length]);
					applyPackColors(tempShader, colorPart);

					if (note != null)
					{
						if (note.noteSplashData.r != -1) tempShader.r = note.noteSplashData.r;
						if (note.noteSplashData.g != -1) tempShader.g = note.noteSplashData.g;
						if (note.noteSplashData.b != -1) tempShader.b = note.noteSplashData.b;
					}
				}
				else
				{
					tempShader.copyValues(Note.globalRgbShaders[noteData % Note.colArray.length]);
					applyPackColors(tempShader, colorPart);
				}
			}
		}
		rgbShader.copyValues(tempShader);
		if (!config.allowPixel) rgbShader.pixelAmount = 1;
		else if (PlayState.isPixelStage) rgbShader.pixelAmount = 6;

		offset.set(10, 10);
		var conf:NoteSplashAnim = config.animations.get(anim);
		var offsets:Array<Float> = [0, 0];
		if (conf != null) offsets = conf.offsets;
		if (offsets != null)
		{
			offset.x += offsets[0];
			offset.y += offsets[1];
		}

		animation.finishCallback = function(name:String) {
			kill();
			spawned = false;
		}

		alpha = ClientPrefs.data.splashAlpha;
		if (note != null) alpha = note.noteSplashData.a;
		if (texture == pixelNoteSplash && alpha == ClientPrefs.data.splashAlpha) alpha = PIXEL_SPLASH_ALPHA;
		baseAlpha = alpha;

		antialiasing = ClientPrefs.data.antialiasing;
		if (note != null) antialiasing = note.noteSplashData.antialiasing;
		if (PlayState.isPixelStage && config.allowPixel) antialiasing = false;
		if (texture == pixelNoteSplash) antialiasing = false;
		if (loadedPack != null) antialiasing = NotePack.antialiasingOf(loadedPack);

		var minFps:Int = 22;
		var maxFps:Int = 26;
		if (conf != null)
		{
			minFps = conf.fps[0];
			if (minFps < 0) minFps = 0;

			maxFps = conf.fps[1];
			if (maxFps < 0) maxFps = 0;
		}

		if (animation.curAnim != null)
			animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);

		spawned = true;
	}
	
	public function playDefaultAnim()
	{
		var anim:String = noteDataMap.get(noteData);
		if (anim != null && animation.exists(anim))
			animation.play(anim, true);

		return anim;
	}

	function checkForAnim(anim:String)
	{
		var animFrames = [];
		@:privateAccess
		animation.findByPrefix(animFrames, anim); // adds valid frames to animFrames

		return animFrames.length > 0;
	}

	var aliveTime:Float = 0;
	static var buggedKillTime:Float = 0.5; //automatically kills note splashes if they break to prevent it from flooding your HUD
	override function update(elapsed:Float)
	{
		if (spawned)
		{
			aliveTime += elapsed;
			if (animation.curAnim == null && aliveTime >= buggedKillTime)
			{
				kill();
				spawned = false;
			}
		}

		followStrum();
		super.update(elapsed);
	}

	public function followStrum():Void
	{
		if (babyArrow == null) return;

		if (copyX)
			x = babyArrow.x - Note.swagWidth * 0.95;

		if (copyY)
			y = babyArrow.y - Note.swagWidth;

		angle = babyArrow.angle;
		alpha = baseAlpha * babyArrow.alpha;
	}

	public static function getSplashSkinPostfix()
	{
		var skin:String = '';
		if (ClientPrefs.data.splashSkin != ClientPrefs.defaultData.splashSkin)
			skin = '-' + ClientPrefs.data.splashSkin.trim().toLowerCase().replace(' ', '-');
		return skin;
	}

	public static function createConfig():NoteSplashConfig
	{
		return {
			animations: new Map(),
			scale: 1,
			allowRGB: true,
			allowPixel: true,
			rgb: null
		}
	}

	public static function addAnimationToConfig(config:NoteSplashConfig, scale:Float, name:String, prefix:String, fps:Array<Int>, offsets:Array<Float>, indices:Array<Int>, noteData:Int):NoteSplashConfig
	{
		if (config == null) config = createConfig();

		config.animations.set(name, {name: name, noteData: noteData, prefix: prefix, indices: indices, offsets: offsets, fps: fps});
		config.scale = scale;
		return config;
	}

	function set_config(value:NoteSplashConfig):NoteSplashConfig 
	{
		if (value == null) value = createConfig();

		@:privateAccess
		animation.clearAnimations();
		noteDataMap.clear();

		for (i in value.animations)
		{
			var key:String = i.name;
			if (i.prefix.length > 0 && key != null && key.length > 0)
			{
				if (i.indices != null && i.indices.length > 0)
					animation.addByIndices(key, i.prefix, i.indices, "", i.fps[1], false);
				else
					animation.addByPrefix(key, i.prefix, i.fps[1], false);

				noteDataMap.set(i.noteData, key);
			}
		}

		scale.set(value.scale, value.scale);
		return config = value;
	}

	function set_maxAnims(value:Int)
	{
		if (value > 0)
			noteData = Std.int(FlxMath.wrap(noteData, 0, (value * Note.colArray.length) - 1));
		else
			noteData = 0;

		return maxAnims = value;
	}
}

class PixelSplashShaderRef 
{
	public var shader:PixelSplashShader = new PixelSplashShader();
	public var enabled(default, set):Bool = true;
	public var pixelAmount(default, set):Float = 1;

	public function copyValues(tempShader:RGBPalette)
	{
		if (tempShader != null)
		{
			for (i in 0...3)
			{
				shader.r.value[i] = tempShader.shader.r.value[i];
				shader.g.value[i] = tempShader.shader.g.value[i];
				shader.b.value[i] = tempShader.shader.b.value[i];
			}
			shader.mult.value[0] = tempShader.shader.mult.value[0];
		}
		else enabled = false;
	}

	public function set_enabled(value:Bool)
	{
		enabled = value;
		shader.mult.value = [value ? 1 : 0];
		return value;
	}

	public function set_pixelAmount(value:Float)
	{
		pixelAmount = value;
		shader.uBlocksize.value = [value, value];
		return value;
	}

	public function reset()
	{
		shader.r.value = [0, 0, 0];
		shader.g.value = [0, 0, 0];
		shader.b.value = [0, 0, 0];
	}

	public function new()
	{
		reset();
		enabled = true;

		if (!PlayState.isPixelStage) pixelAmount = 1;
		else pixelAmount = PlayState.daPixelZoom;
		//trace('Created shader ' + Conductor.songPosition);
	}
}

class PixelSplashShader extends FlxShader
{
	@:glFragmentHeader('
		#pragma header

		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;
		uniform vec2 uBlocksize;

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 coord) {
			vec2 blocks = openfl_TextureSize / uBlocksize;
			vec4 color = flixel_texture2D(bitmap, floor(coord * blocks) / blocks);
			if (!hasTransform) {
				return color;
			}

			if (color.a == 0.0 || mult == 0.0) {
				return color * openfl_Alphav;
			}

			vec4 newColor = color;
			newColor.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0));
			newColor.a = color.a;

			color = mix(color, newColor, mult);

			if (color.a > 0.0) {
				return vec4(color.rgb, color.a);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}')

	@:glFragmentSource('
		#pragma header

		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')

	public function new()
	{
		super();
	}
}