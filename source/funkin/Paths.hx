package funkin;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.system.System;
import openfl.geom.Rectangle;

import lime.utils.Assets;
import flash.media.Sound;

import haxe.Json;


#if MODS_ALLOWED
import funkin.modding.Mods;
#end

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = [
		'assets/content/audio/music/freakyMenu.$SOUND_EXT',
		'assets/shared/music/freakyMenu.$SOUND_EXT'
	];
	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
				currentTrackedAssets.remove(key); // and remove the key from local cache map
			}
		}

		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}

		#if cpp
		cpp.vm.Gc.compact();
		#else
		System.gc();
		#end
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key) && !dumpExclusions.contains(key))
			{
				var graphic = FlxG.bitmap.get(key);
				if(graphic != null && !graphic.persist)
					destroyGraphic(graphic);
			}
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		for (bitmap in readableBitmaps)
			if(bitmap != null) bitmap.dispose();
		readableBitmaps.clear();

		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if(grp != null)
				{
					//trace('is actually a group');
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			//trace('check...');
			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if(gfx != null)
				{
					protectedGfx.push(gfx);
					//trace('gfx added to the list successfully!');
				}
			}
			//catch(haxe.Exception) {}
		}

		for (member in FlxG.state.members)
			checkForGraphics(member);

		if(FlxG.state.subState != null)
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);

		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if(!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic); // get rid of the graphic
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					//trace('deleted $key');
				}
			}
		}
	}

	public static function releaseGraphicsExcept(keep:Array<String>)
	{
		for (key in currentTrackedAssets.keys())
		{
			if (!keep.contains(key) && !dumpExclusions.contains(key))
			{
				destroyGraphic(currentTrackedAssets.get(key));
				currentTrackedAssets.remove(key);
			}
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		// free some gpu memory
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}

	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	static final NEW_ROUTES:Map<String, String> = [
		'data' => 'data/',
		'characters' => 'data/characters/',
		'stages' => 'data/stages/',
		'weeks' => 'data/weeks/',
		'images' => 'content/images/',
		'sounds' => 'content/audio/sounds/',
		'music' => 'content/audio/music/',
		'shaders' => 'content/shaders/',
		'videos' => 'videos/',
		'fonts' => 'fonts/',
		'translations' => 'content/translations/',
	];

	static final IMAGE_ALIASES:Map<String, String> = [
		'icons' => 'characters/icons',
		'noteSkins' => 'notes',
		'noteSplashes' => 'notes/splashes',
		'achievements' => 'extra/achievements',
		'dialogue' => 'extra/dialogue',
		'soundtray' => 'extra/soundtray',
		'menubackgrounds' => 'storymode/weekbg',
		'menucharacters' => 'storymode/weekcharacters',
		'menudifficulties' => 'storymode/weekdiff',
		'storymenu' => 'storymode/weekname'
	];

	public static function routeKey(file:String):String
	{
		var slash:Int = file.indexOf('/');
		if(slash < 0) return null;

		var category:String = file.substr(0, slash);
		var route:String = NEW_ROUTES.get(category);
		if(route == null) return null;

		var rest:String = file.substr(slash + 1);
		if(category == 'images') rest = aliasImageKey(rest);

		return route + rest;
	}

	static function aliasImageKey(rest:String):String
	{
		var slash:Int = rest.indexOf('/');
		if(slash < 0) return rest;

		var alias:String = IMAGE_ALIASES.get(rest.substr(0, slash));
		return (alias != null) ? alias + rest.substr(slash) : rest;
	}

	public static function routeLevelKey(file:String, level:String):String
	{
		var key:String = file;
		if(key.startsWith('images/')) key = key.substr(7);
		return 'content/base_weeks/$level/$key';
	}

	public static function routeModLevelKey(file:String, level:String):String
	{
		var key:String = file;
		if(key.startsWith('images/')) key = key.substr(7);
		return 'content/custom_weeks/$level/$key';
	}

	inline public static function assetExists(path:String, ?type:AssetType = TEXT):Bool
	{
		#if sys
		if(FileSystem.exists(path)) return true;
		#end
		return OpenFlAssets.exists(path, type);
	}

	public static function getPath(file:String, ?type:AssetType = TEXT, ?parentfolder:String, ?modsAllowed:Bool = true):String
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			var level:String = (parentfolder != null) ? parentfolder : currentLevel;
			if(level != null && level != 'shared' && level != 'songs')
			{
				var moddedLevel:String = modFolders(routeModLevelKey(file, level));
				if(FileSystem.exists(moddedLevel)) return moddedLevel;
			}

			var customFile:String = file;
			if (parentfolder != null) customFile = '$parentfolder/$file';

			var modded:String = modFolders(customFile);
			if(FileSystem.exists(modded)) return modded;
		}
		#end

		if (parentfolder != null)
		{
			if(parentfolder != 'songs')
			{
				var routedLevel:String = 'assets/' + routeLevelKey(file, parentfolder);
				if(assetExists(routedLevel, type)) return routedLevel;
			}
			return getFolderPath(file, parentfolder);
		}

		if (currentLevel != null && currentLevel != 'shared')
		{
			var routedLevel:String = 'assets/' + routeLevelKey(file, currentLevel);
			if(assetExists(routedLevel, type)) return routedLevel;

			var levelPath = getFolderPath(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		var routed:String = routeKey(file);
		if(routed != null)
		{
			var newPath:String = 'assets/' + routed;
			if(assetExists(newPath, type)) return newPath;
		}
		return getSharedPath(file);
	}

	inline static public function getFolderPath(file:String, folder = "shared")
		return 'assets/$folder/$file';

	inline public static function getSharedPath(file:String = '')
		return 'assets/shared/$file';

	public static function getRoutedSharedPath(file:String = '')
	{
		var routed:String = routeKey(file);
		if(routed != null)
		{
			var newPath:String = 'assets/' + routed;
			#if sys
			if(FileSystem.exists(newPath)) return newPath;
			#end
		}
		return 'assets/shared/$file';
	}

	inline static public function txt(key:String, ?folder:String)
		return getPath('data/$key.txt', TEXT, folder, true);

	inline static public function xml(key:String, ?folder:String)
		return getPath('data/$key.xml', TEXT, folder, true);

	inline static public function json(key:String, ?folder:String)
		return getPath('data/$key.json', TEXT, folder, true);

	inline static public function shaderFragment(key:String, ?folder:String)
		return getPath('shaders/$key.frag', TEXT, folder, true);

	inline static public function shaderVertex(key:String, ?folder:String)
		return getPath('shaders/$key.vert', TEXT, folder, true);

	inline static public function lua(key:String, ?folder:String)
		return getPath('$key.lua', TEXT, folder, true);

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) return file;
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	inline static public function sound(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('sounds/$key', modsAllowed);

	inline static public function music(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('music/$key', null, modsAllowed, true, ClientPrefs.data.streamSongs);

	public static var VARIANT_FIRST_WORD_ONLY:Bool = true;

	public static function variantSuffix(difficulty:String):String
	{
		if(difficulty == null || difficulty.length < 1) return '';

		var value:String = difficulty.charAt(0) == '-' ? difficulty.substr(1) : difficulty;
		if(value.length < 1) return '';

		if(VARIANT_FIRST_WORD_ONLY)
		{
			var dash:Int = value.indexOf('-');
			if(dash > 0) value = value.substr(0, dash);
		}

		return '-' + value;
	}

	static function findSongSound(formattedSong:String, fileName:String, modsAllowed:Bool, beepOnNull:Bool = false, stream:Bool = false):Sound
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			if(FileSystem.exists(getPath('data/songs/$formattedSong/song/$fileName.$SOUND_EXT', SOUND, null, true)))
				return returnSound('songs/$formattedSong/song/$fileName', 'data', modsAllowed, beepOnNull, stream);

			if(FileSystem.exists(getPath('data/$formattedSong/song/$fileName.$SOUND_EXT', SOUND, null, true)))
				return returnSound('$formattedSong/song/$fileName', 'data', modsAllowed, beepOnNull, stream);

			if(FileSystem.exists(getPath('data/$formattedSong/songs/$fileName.$SOUND_EXT', SOUND, null, true)))
				return returnSound('$formattedSong/songs/$fileName', 'data', modsAllowed, beepOnNull, stream);
		}
		#end

		return returnSound('$formattedSong/$fileName', 'songs', modsAllowed, beepOnNull, stream);
	}

	static public function inst(song:String, ?difficulty:String, ?modsAllowed:Bool = true, ?stream:Bool = false):Sound
	{
		var formattedSong = formatToSongPath(song);
		var suffix:String = variantSuffix(difficulty);

		if(suffix.length > 0)
		{
			var variant:Sound = findSongSound(formattedSong, 'Inst$suffix', modsAllowed, false, stream);
			if(variant != null) return variant;
		}

		return findSongSound(formattedSong, 'Inst', modsAllowed, true, stream);
	}

	static public function instPath(song:String, ?difficulty:String, ?modsAllowed:Bool = true):String
	{
		var formattedSong = formatToSongPath(song);
		var suffix:String = variantSuffix(difficulty);

		if(suffix.length > 0)
		{
			var variant:String = findSongSoundPath(formattedSong, 'Inst$suffix', modsAllowed);
			if(variant != null) return variant;
		}

		return findSongSoundPath(formattedSong, 'Inst', modsAllowed);
	}

	static function findSongSoundPath(formattedSong:String, fileName:String, modsAllowed:Bool):String
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			if(FileSystem.exists(getPath('data/songs/$formattedSong/song/$fileName.$SOUND_EXT', SOUND, null, true)))
				return soundFilePath('songs/$formattedSong/song/$fileName', 'data', modsAllowed);

			if(FileSystem.exists(getPath('data/$formattedSong/song/$fileName.$SOUND_EXT', SOUND, null, true)))
				return soundFilePath('$formattedSong/song/$fileName', 'data', modsAllowed);

			if(FileSystem.exists(getPath('data/$formattedSong/songs/$fileName.$SOUND_EXT', SOUND, null, true)))
				return soundFilePath('$formattedSong/songs/$fileName', 'data', modsAllowed);
		}
		#end

		return soundFilePath('$formattedSong/$fileName', 'songs', modsAllowed);
	}

	public static function soundFilePath(key:String, ?path:String, ?modsAllowed:Bool = true):String
	{
		var file:String = getPath(Language.getFileTranslation(key) + '.$SOUND_EXT', SOUND, path, modsAllowed);
		#if sys
		return FileSystem.exists(file) ? file : null;
		#else
		return OpenFlAssets.exists(file, SOUND) ? file : null;
		#end
	}

	static public function voices(song:String, postfix:String = null, ?difficulty:String, ?modsAllowed:Bool = true, ?stream:Bool = false):Sound
	{
		var formattedSong = formatToSongPath(song);
		var base:String = 'Voices' + (postfix != null ? '-' + postfix : '');
		var suffix:String = variantSuffix(difficulty);

		if(suffix.length > 0)
		{
			var variant:Sound = findSongSound(formattedSong, base + suffix, modsAllowed, false, stream);
			if(variant != null) return variant;
		}

		return findSongSound(formattedSong, base, modsAllowed, false, stream);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?modsAllowed:Bool = true)
		return sound(key + FlxG.random.int(min, max), modsAllowed);

	public static var COLLECT_AFTER_UPLOAD:Float = 8388608;
	static var uploadedSinceCollect:Float = 0;

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		key = Language.getFileTranslation('images/$key') + '.png';
		var bitmap:BitmapData = null;
		if (currentTrackedAssets.exists(key))
		{
			localTrackedAssets.push(key);
			return currentTrackedAssets.get(key);
		}
		return cacheBitmap(key, parentFolder, bitmap, allowGPU);
	}

	static var readableBitmaps:Map<String, BitmapData> = [];
	public static function readablePixels(graphic:FlxGraphic):BitmapData
	{
		if(graphic == null || graphic.bitmap == null) return null;
		if(graphic.bitmap.image != null || graphic.key == null) return graphic.bitmap;
		if(readableBitmaps.exists(graphic.key)) return readableBitmaps.get(graphic.key);

		var bitmap:BitmapData = null;
		var file:String = getPath(graphic.key, IMAGE, null, true);
		#if MODS_ALLOWED
		if (FileSystem.exists(file))
			bitmap = BitmapData.fromFile(file);
		else #end if (OpenFlAssets.exists(file, IMAGE))
			bitmap = OpenFlAssets.getBitmapData(file, false);

		readableBitmaps.set(graphic.key, bitmap);
		return bitmap;
	}

	public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		if (bitmap == null)
		{
			var file:String = getPath(key, IMAGE, parentFolder, true);

			#if MODS_ALLOWED
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			else #end if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);

			if (bitmap == null)
			{
				trace('Bitmap not found: $file | key: $key');
				return null;
			}
		}

		if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;

			uploadedSinceCollect += bitmap.width * bitmap.height * 4;
			if (uploadedSinceCollect >= COLLECT_AFTER_UPLOAD)
			{
				uploadedSinceCollect = 0;
				#if cpp
				cpp.vm.Gc.run(true);
				#end
			}
		}

		var existing:FlxGraphic = FlxG.bitmap.get(key);
		if (existing != null)
		{
			existing.persist = false;
			FlxG.bitmap.remove(existing);
		}
		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		localTrackedAssets.push(key);
		return graph;
	}

	inline static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		var path:String = getPath(key, TEXT, !ignoreMods);
		#if sys
		return (FileSystem.exists(path)) ? File.getContent(path) : null;
		#else
		return (OpenFlAssets.exists(path, TEXT)) ? Assets.getText(path) : null;
		#end
	}

	static public function font(key:String)
	{
		var folderKey:String = Language.getFileTranslation('fonts/$key');
		#if MODS_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var modFile:String = mods(Mods.currentModDirectory + '/' + folderKey);
			if(FileSystem.exists(modFile)) return modFile;
		}
		for(mod in Mods.getGlobalMods())
		{
			var modFile:String = mods(mod + '/' + folderKey);
			if(FileSystem.exists(modFile)) return modFile;
		}
		#end
		return 'assets/$folderKey';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?parentFolder:String = null)
	{
		#if MODS_ALLOWED
		if(!ignoreMods)
		{
			var modKey:String = key;
			if(parentFolder == 'songs') modKey = 'songs/$key';

			var level:String = (parentFolder != null) ? parentFolder : currentLevel;
			if(level != null && level != 'shared' && level != 'songs')
				if(FileSystem.exists(modFolders(routeModLevelKey(key, level))))
					return true;

			if(FileSystem.exists(modFolders(modKey)))
				return true;

			if(FileSystem.exists(mods(modKey)))
				return true;
		}
		#end
		return (OpenFlAssets.exists(getPath(key, type, parentFolder, false)));
	}

	static public function getAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var useMod = false;
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);

		var myXml:Dynamic = getPath('images/$key.xml', TEXT, parentFolder, true);
		if(OpenFlAssets.exists(myXml) #if MODS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end )
		{
			#if MODS_ALLOWED
			return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? File.getContent(myXml) : myXml));
			#else
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
			#end
		}
		else
		{
			var myJson:Dynamic = getPath('images/$key.json', TEXT, parentFolder, true);
			if(OpenFlAssets.exists(myJson) #if MODS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end )
			{
				#if MODS_ALLOWED
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? File.getContent(myJson) : myJson));
				#else
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
				#end
			}
		}
		return getPackerAtlas(key, parentFolder);
	}
	
	static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		
		var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim());
		if(keys.length > 1)
		{
			var original:FlxAtlasFrames = parentFrames;
			parentFrames = new FlxAtlasFrames(parentFrames.parent);
			parentFrames.addAtlas(original, true);
			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), parentFolder, allowGPU);
				if(extraFrames != null)
					parentFrames.addAtlas(extraFrames, true);
			}
		}
		return parentFrames;
	}

	inline static public function getSparrowAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if MODS_ALLOWED
		var xmlExists:Bool = false;

		var xml:String = modsXml(key);
		if(FileSystem.exists(xml)) xmlExists = true;

		return FlxAtlasFrames.fromSparrow(imageLoaded, (xmlExists ? File.getContent(xml) : getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSparrow(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder));
		#end
	}

	inline static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if MODS_ALLOWED
		var txtExists:Bool = false;
		
		var txt:String = modsTxt(key);
		if(FileSystem.exists(txt)) txtExists = true;

		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, (txtExists ? File.getContent(txt) : getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder));
		#end
	}

	inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if MODS_ALLOWED
		var jsonExists:Bool = false;

		var json:String = modsImagesJson(key);
		if(FileSystem.exists(json)) jsonExists = true;

		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (jsonExists ? File.getContent(json) : getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder));
		#end
	}

	static public function formatToSongPath(path:String):String {
		var result:StringBuf = null;
		var start:Int = 0;
		for (i in 0...path.length)
		{
			var replacement:String = switch(StringTools.fastCodeAt(path, i))
			{
				case '~'.code | '&'.code | ';'.code | ':'.code | '<'.code | '>'.code | '#'.code | ' '.code | 0x09 | 0x0A | 0x0B | 0x0C | 0x0D: '-';
				case '.'.code | ','.code | "'".code | '"'.code | '%'.code | '?'.code | '!'.code: '';
				default: null;
			}
			if(replacement == null) continue;

			if(result == null) result = new StringBuf();
			result.addSub(path, start, i - start);
			result.add(replacement);
			start = i + 1;
		}
		if(result != null)
		{
			result.addSub(path, start);
			path = result.toString();
		}
		return path.trim().toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true, ?stream:Bool = false)
	{
		var file:String = getPath(Language.getFileTranslation(key) + '.$SOUND_EXT', SOUND, path, modsAllowed);

		#if (sys && lime_vorbis)
		if (stream && file.toLowerCase().endsWith('.ogg') && FileSystem.exists(file))
		{
			var vorbis:lime.media.vorbis.VorbisFile = lime.media.vorbis.VorbisFile.fromFile(file);
			if (vorbis != null)
			{
				var buffer:lime.media.AudioBuffer = lime.media.AudioBuffer.fromVorbisFile(vorbis);
				if (buffer != null)
				{
					@:privateAccess buffer.__srcCustom = file;
					return Sound.fromAudioBuffer(buffer);
				}
			}
		}
		#end

		if (!currentTrackedSounds.exists(file))
		{
			#if sys
			if (FileSystem.exists(file))
				currentTrackedSounds.set(file, Sound.fromFile(file));
			#else
			if (OpenFlAssets.exists(file, SOUND))
				currentTrackedSounds.set(file, OpenFlAssets.getSound(file));
			#end
			else if (beepOnNull)
			{
				trace('SOUND NOT FOUND: $key, PATH: $path');
				FlxG.log.error('SOUND NOT FOUND: $key, PATH: $path');
				return FlxAssets.getSound('flixel/sounds/beep');
			}
		}
		localTrackedAssets.push(file);
		return currentTrackedSounds.get(file);
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '')
		return 'mods/' + key;

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

	inline static public function modsImagesJson(key:String)
		return modFolders('images/' + key + '.json');

	public static function modsRoutedFolder(key:String, ?modDir:String):String
	{
		var prefix:String = (modDir != null && modDir.length > 0) ? modDir + '/' : '';
		var oldPath:String = mods(prefix + key);
		var routed:String = routeKey(key);

		if(routed == null || routed == key) return oldPath;
		if(FileSystem.exists(oldPath)) return oldPath;

		return mods(prefix + routed);
	}

	static public function modFolders(key:String)
	{
		var routed:String = routeKey(key);
		if(routed == key) routed = null;

		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			if(routed != null)
			{
				var newFile:String = mods(Mods.currentModDirectory + '/' + routed);
				if(FileSystem.exists(newFile)) return newFile;
			}

			var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		for(mod in Mods.getGlobalMods())
		{
			if(routed != null)
			{
				var newFile:String = mods(mod + '/' + routed);
				if(FileSystem.exists(newFile)) return newFile;
			}

			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}
		return 'mods/' + key;
	}
	#end

	#if flxanimate
	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
	{
		var changedAnimJson = false;
		var changedAtlasJson = false;
		var changedImage = false;
		
		if(spriteJson != null)
		{
			changedAtlasJson = true;
			spriteJson = File.getContent(spriteJson);
		}

		if(animationJson != null) 
		{
			changedAnimJson = true;
			animationJson = File.getContent(animationJson);
		}

		// is folder or image path
		if(Std.isOfType(folderOrImg, String))
		{
			var originalPath:String = folderOrImg;
			for (i in 0...10)
			{
				var st:String = '$i';
				if(i == 0) st = '';

				if(!changedAtlasJson)
				{
					spriteJson = getTextFromFile('images/$originalPath/spritemap$st.json');
					if(spriteJson != null)
					{
						//trace('found Sprite Json');
						changedImage = true;
						changedAtlasJson = true;
						folderOrImg = image('$originalPath/spritemap$st');
						break;
					}
				}
				else if(fileExists('images/$originalPath/spritemap$st.png', IMAGE))
				{
					//trace('found Sprite PNG');
					changedImage = true;
					folderOrImg = image('$originalPath/spritemap$st');
					break;
				}
			}

			if(!changedImage)
			{
				//trace('Changing folderOrImg to FlxGraphic');
				changedImage = true;
				folderOrImg = image(originalPath);
			}

			if(!changedAnimJson)
			{
				//trace('found Animation Json');
				changedAnimJson = true;
				animationJson = getTextFromFile('images/$originalPath/Animation.json');
			}
		}

		//trace(folderOrImg);
		//trace(spriteJson);
		//trace(animationJson);
		if(Std.isOfType(animationJson, String)) animationJson = convertBTAMatrices(animationJson);
		spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);
	}

	public static function getModernAtlasFrames(image:String, ?parentFolder:String):FlxAtlasFrames
	{
		if(image == null) return null;

		var parts:Array<String> = [for (part in image.split(',')) part.trim()];
		var collections:Array<FlxAtlasFrames> = [];
		var hasModern:Bool = false;
		for (part in parts)
		{
			var animation:String = getTextFromFile('images/$part/Animation.json');
			if(animation != null)
			{
				if(animation.indexOf('"MX"') < 0) return null;
				var atlas:animate.FlxAnimateFrames = loadModernAtlas(part, animation, parentFolder);
				if(atlas == null) return null;
				collections.push(atlas);
				hasModern = true;
			}
			else
			{
				var sparrow:FlxAtlasFrames = getAtlas(part, parentFolder);
				if(sparrow != null) collections.push(sparrow);
			}
		}
		if(!hasModern) return null;

		var modern:Array<FlxAtlasFrames> = [for (frames in collections) if(frames is animate.FlxAnimateFrames) frames];
		for (frames in collections) if(!modern.contains(frames)) modern.push(frames);
		return animate.FlxAnimateFrames.combineAtlas(modern);
	}

	public static function getAnimateAtlasFrames(folder:String, ?parentFolder:String):animate.FlxAnimateFrames
	{
		var animation:String = getTextFromFile('images/$folder/Animation.json');
		if(animation == null) return null;
		return loadModernAtlas(folder, animation, parentFolder);
	}

	static function loadModernAtlas(folder:String, animation:String, ?parentFolder:String):animate.FlxAnimateFrames
	{
		var spritemaps:Array<animate.FlxAnimateFrames.SpritemapInput> = [];
		for (i in 0...10)
		{
			var suffix:String = (i == 0) ? '' : '$i';
			var json:String = getTextFromFile('images/$folder/spritemap$suffix.json');
			if(json == null) continue;

			var graphic:FlxGraphic = image('$folder/spritemap$suffix', parentFolder);
			if(graphic != null) spritemaps.push({source: graphic, json: removeBOM(json)});
		}
		if(spritemaps.length < 1) return null;

		var atlas:animate.FlxAnimateFrames = animate.FlxAnimateFrames.fromAnimate(removeBOM(animation), spritemaps, null, 'animate:$folder', true);
		if(atlas != null && atlas.parent != null) atlas.parent.destroyOnNoUse = false;
		return atlas;
	}

	inline static function removeBOM(text:String):String
		return text.replace(String.fromCharCode(0xFEFF), '');

	static final btaMatrix:EReg = ~/"MX"\s*:\s*\[([^\]]*)\]/g;
	public static function convertBTAMatrices(json:String):String
	{
		if(json == null || json.indexOf('"MX"') < 0) return json;
		return btaMatrix.map(json, function(found:EReg):String
		{
			var m:Array<String> = [for (value in found.matched(1).split(',')) value.trim()];
			if(m.length < 6) return found.matched(0);
			return '"M3D":[${m[0]},${m[1]},0,0,${m[2]},${m[3]},0,0,0,0,1,0,${m[4]},${m[5]},0,1]';
		});
	}
	#end
}