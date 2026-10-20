package funkin.game.notes;

import funkin.data.NotePackData;
import funkin.data.NoteTypesConfig;
import funkin.data.Song.SwagSong;

using StringTools;

class NotePack
{
	public static final PACK_FOLDER:String = 'data/notes/';
	public static final GLOBAL_FILE:String = 'data/notes.json';
	public static final SONG_FILE:String = 'notes.json';

	static var cache:Map<String, NotePack> = new Map();
	static var overrides:Map<String, NotePack> = new Map();
	static var typeCache:Map<String, NotePack> = new Map();

	public static var active(get, never):NotePack;
	static var activeSong:SwagSong = null;
	static var activeKey:String = null;
	static var activeValue:NotePack = null;
	public static var preview:NotePack = null;

	public static function setPreview(data:NotePackFile):NotePack
	{
		preview = (data != null) ? new NotePack('editor', data) : null;
		return preview;
	}

	static function get_active():NotePack
	{
		var song:SwagSong = PlayState.SONG;
		var key:String = (song == null) ? '' : '${song.song}|${song.notePack}|${ClientPrefs.data.useChartNoteSkins}|${Mods.currentModDirectory}';
		if(song != activeSong || key != activeKey)
		{
			activeSong = song;
			activeKey = key;
			activeValue = forSong(song);
		}
		return activeValue;
	}

	public static function partFor(name:String, opponent:Bool, ?pixel:Null<Bool>):NotePackPart
	{
		if(pixel == null) pixel = PlayState.isPixelStage;
		var key:String = overrideKey(name, opponent);
		var pack:NotePack = (preview != null) ? preview : (overrides.exists(key) ? overrides.get(key) : active);
		return (pack != null) ? pack.part(name, opponent, pixel) : null;
	}

	public static function tintFor(opponent:Bool):NotePackTint
	{
		var pack:NotePack = (preview != null) ? preview : active;
		return (pack != null) ? pack.tint(opponent) : null;
	}

	public static function setOverride(name:String, opponent:Bool, pack:NotePack)
		overrides.set(overrideKey(name, opponent), pack);

	public static function clearOverride(name:String, opponent:Bool)
		overrides.remove(overrideKey(name, opponent));

	public static function resetOverrides()
		overrides.clear();

	static function overrideKey(name:String, opponent:Bool):String
		return (name == 'splashes') ? name : '$name|$opponent';

	public static function addAnimation(sprite:FlxSprite, name:String, anim:NotePackAnim, gridded:Bool):Bool
	{
		if(anim == null) return false;
		var fps:Float = (anim.fps != null) ? anim.fps : 24;
		var loop:Bool = (anim.loop != null) ? anim.loop : false;
		if(gridded)
		{
			if(anim.frames == null || anim.frames.length < 1) return false;
			sprite.animation.add(name, anim.frames, fps, loop);
			return true;
		}

		if(anim.prefix == null || anim.prefix.length < 1) return false;
		for (prefix in NotePackData.prefixCandidates(anim.prefix))
		{
			if(!hasPrefix(sprite, prefix)) continue;
			if(anim.indices != null && anim.indices.length > 0)
				sprite.animation.addByIndices(name, prefix, anim.indices, '', fps, loop);
			else
				sprite.animation.addByPrefix(name, prefix, fps, loop);
			return true;
		}
		return false;
	}

	public static function hasPrefix(sprite:FlxSprite, prefix:String):Bool
	{
		if(sprite.frames == null) return false;
		var found:Array<flixel.graphics.frames.FlxFrame> = [];
		@:privateAccess sprite.animation.findByPrefix(found, prefix);
		return found.length > 0;
	}

	public static function isGridded(part:NotePackPart):Bool
		return part != null && part.grid != null && part.grid.length > 1 && part.grid[0] > 0 && part.grid[1] > 0;

	public static function loadImage(sprite:FlxSprite, image:String, grid:Array<Int>):Bool
	{
		if(grid != null && grid.length > 1 && grid[0] > 0 && grid[1] > 0)
		{
			var graphic = Paths.image(image);
			if(graphic == null) return false;
			sprite.loadGraphic(graphic, true, Math.floor(graphic.width / grid[0]), Math.floor(graphic.height / grid[1]));
			return true;
		}
		var atlas = Paths.getSparrowAtlas(image);
		if(atlas == null) return false;
		sprite.frames = atlas;
		return true;
	}

	public static function antialiasingOf(part:NotePackPart):Bool
		return ClientPrefs.data.antialiasing && part.antialiasing != false;

	public static function forNoteType(name:String):NotePack
	{
		if(name == null || name.trim().length < 1) return null;
		var key:String = '$name|${PlayState.SONG != null ? PlayState.SONG.song : ''}|${Mods.currentModDirectory}';
		if(typeCache.exists(key)) return typeCache.get(key);
		var path:String = NoteTypesConfig.findFile(name, '.json');
		var pack:NotePack = (path != null) ? load(path) : null;
		typeCache.set(key, pack);
		return pack;
	}

	public var path(default, null):String;
	public var data(default, null):NotePackFile;

	var parts:Map<String, NotePackPart> = new Map();
	var typeParts:Map<String, NotePackPart> = new Map();
	var typeBases:Map<String, NotePackPart> = new Map();

	function new(path:String, data:NotePackFile)
	{
		this.path = path;
		this.data = data;
	}

	public function part(name:String, opponent:Bool, pixel:Bool):NotePackPart
	{
		var key:String = '$name|$opponent|$pixel';
		if(!parts.exists(key)) parts.set(key, NotePackData.resolvePart(data, name, opponent, pixel));
		return parts.get(key);
	}

	public function hasPart(name:String, opponent:Bool, pixel:Bool):Bool
		return part(name, opponent, pixel) != null;

	public function rawPart(name:String, opponent:Bool, pixel:Bool):NotePackPart
	{
		var raw:NotePackPart = NotePackData.rawPart(data, name, opponent, pixel);
		if(raw == null && pixel) raw = NotePackData.rawPart(data, name, opponent, false);
		return raw;
	}

	public function typePart(name:String, opponent:Bool, pixel:Bool, base:NotePackPart):NotePackPart
	{
		var raw:NotePackPart = NotePackData.rawPart(data, name, opponent, pixel);
		var ownSkin:Bool = false;
		if(raw == null && pixel)
		{
			raw = NotePackData.rawPart(data, name, opponent, false);
			ownSkin = raw != null && (raw.image != null || raw.animations != null);
			if(ownSkin) base = null;
			pixel = false;
		}
		if(raw == null) return null;
		if(base == null && raw.image == null && raw.animations == null && !ownSkin) return null;

		var key:String = '$name|$opponent|$pixel';
		if(!typeParts.exists(key) || typeBases.get(key) != base)
		{
			typeBases.set(key, base);
			typeParts.set(key, NotePackData.mergePart((base != null) ? base : NotePackData.defaultPart(name, pixel), raw, name));
		}
		return typeParts.get(key);
	}

	public function tint(opponent:Bool):NotePackTint
		return NotePackData.tint(data, opponent);

	public static function forSong(song:SwagSong):NotePack
	{
		if(song == null || !ClientPrefs.data.useChartNoteSkins) return null;

		var songPath:String = songFile(song.song);
		if(songPath != null) return load(songPath);

		var chosen:NotePack = named(song.notePack);
		if(chosen != null) return chosen;

		return Paths.fileExists(GLOBAL_FILE, TEXT) ? load(GLOBAL_FILE) : null;
	}

	public static function named(name:String):NotePack
	{
		var path:String = packPath(name);
		return (path != null) ? load(path) : null;
	}

	public static function packPath(name:String):String
	{
		if(name == null) return null;
		name = name.trim();
		if(name.length < 1) return null;

		var candidates:Array<String> = [];
		if(name.endsWith('.json')) candidates.push(name);
		else candidates.push(PACK_FOLDER + name + '.json');
		if(!name.contains('/')) candidates.push(PACK_FOLDER + name.toLowerCase().replace(' ', '-') + '.json');

		for (candidate in candidates)
			if(Paths.fileExists(candidate, TEXT)) return candidate;
		return null;
	}

	public static function songFile(song:String):String
	{
		if(song == null || song.trim().length < 1) return null;
		var folder:String = Paths.formatToSongPath(song);
		for (candidate in ['data/songs/$folder/$SONG_FILE', 'data/$folder/$SONG_FILE'])
			if(Paths.fileExists(candidate, TEXT)) return candidate;
		return null;
	}

	public static function load(path:String):NotePack
	{
		if(path == null) return null;
		var fullPath:String = Paths.getPath(path, TEXT);
		if(cache.exists(fullPath)) return cache.get(fullPath);

		var pack:NotePack = null;
		try
		{
			pack = new NotePack(path, NotePackData.parse(Paths.getTextFromFile(path)));
		}
		catch(e:Dynamic)
		{
			trace('NotePack: could not read $path: $e');
			if(PlayState.instance != null) PlayState.instance.addTextToDebug('Could not read note pack "$path": $e', FlxColor.RED);
		}
		cache.set(fullPath, pack);
		return pack;
	}

	public static function list():Array<String>
	{
		var names:Array<String> = [];
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), PACK_FOLDER))
		{
			if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) continue;
			for (file in FileSystem.readDirectory(folder))
			{
				if(!file.toLowerCase().endsWith('.json')) continue;
				var name:String = file.substr(0, file.length - 5);
				if(!names.contains(name)) names.push(name);
			}
		}
		names.sort(function(a:String, b:String) return (a.toLowerCase() < b.toLowerCase()) ? -1 : (a.toLowerCase() > b.toLowerCase()) ? 1 : 0);
		return names;
	}

	public static function clearCache()
	{
		cache.clear();
		overrides.clear();
		typeCache.clear();
		activeSong = null;
		activeKey = null;
		activeValue = null;
	}
}
