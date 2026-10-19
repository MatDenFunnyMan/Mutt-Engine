package funkin.data;

import haxe.Json;
import lime.utils.Assets;

import funkin.game.notes.Note;

typedef ExtraStrumlineData =
{
	var character:String;
	var type:String;
	var stagePosition:String;
	var scale:Float;
	var spacing:Float;
	var hudX:Float;
	var hudY:Float;
	var visible:Bool;
	var scrollSpeed:Float;
	var usesChartScroll:Bool;
	var useExistingStrumline:Bool;
	@:optional var layer:Int;
}

typedef ExtraCharacterData =
{
	var slot:Int;
	var character:String;
	var parent:String;
	var strumline:String;
	@:optional var anchor:String;
	@:optional var playable:Bool;
	@:optional var visible:Bool;
	@:optional var alpha:Float;
	@:optional var scale:Float;
	@:optional var spacing:Float;
	@:optional var hudX:Float;
	@:optional var hudY:Float;
	@:optional var scrollSpeed:Float;
	@:optional var usesChartScroll:Bool;
	@:optional var strumlineOf:Int;
	@:optional var healthIcon:Bool;
}

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var mania:Int;
	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;
	@:optional var disableSplashRGB:Bool;
	@:optional var disableHoldRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
	@:optional var holdCoverSkin:String;
	@:optional var notePack:String;

	@:optional var extraStrumlines:Array<ExtraStrumlineData>;
	@:optional var extraCharacters:Array<ExtraCharacterData>;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
	@:optional var mustHitTarget:String;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var holdCoverSkin:String;
	public var notePack:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var disableSplashRGB:Bool = false;
	public var disableHoldRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	public static inline final MAX_CHARACTERS:Int = 10;
	public static inline final FIRST_EXTRA_SLOT:Int = 3;
	public static inline final SHARED:String = 'shared';
	public static inline final SEPARATE:String = 'separate';
	public static final PARENTS:Array<String> = ['bf', 'dad', 'gf'];

	public static function characterNoteType(slot:Int, alt:Bool = false):String
		return 'Char $slot ' + (alt ? 'ALT Note' : 'Note');

	public static function cameraTargetName(slot:Int):String
		return 'Char $slot';

	public static function slotFromNoteType(noteType:String):Int
	{
		if(noteType == null || !(noteType.startsWith('Char ') || noteType.startsWith('Character '))) return -1;
		var parts:Array<String> = noteType.split(' ');
		if(parts.length < 3) return -1;
		var slot:Null<Int> = Std.parseInt(parts[1]);
		if(slot == null || slot < FIRST_EXTRA_SLOT || slot > MAX_CHARACTERS) return -1;
		var rest:String = parts.slice(2).join(' ');
		return (rest == 'Note' || rest == 'ALT Note') ? slot : -1;
	}

	public static function cameraTargetSlot(target:String):Int
	{
		if(target == null) return -1;
		var number:String = null;
		if(target.startsWith('Char ')) number = target.substr('Char '.length);
		else if(target.startsWith('Character ')) number = target.substr('Character '.length);
		else if(target.startsWith('Strumline #')) number = target.substr('Strumline #'.length);
		if(number == null) return -1;
		var slot:Null<Int> = Std.parseInt(number.trim());
		return (slot != null && slot >= FIRST_EXTRA_SLOT && slot <= MAX_CHARACTERS) ? slot : -1;
	}

	public static function isAltCharacterNote(noteType:String):Bool
		return slotFromNoteType(noteType) > 0 && noteType.endsWith(' ALT Note');

	public static function separateCharacters(song:SwagSong):Array<ExtraCharacterData>
	{
		var list:Array<ExtraCharacterData> = [];
		if(song == null || song.extraCharacters == null) return list;
		for (data in song.extraCharacters)
			if(data != null && data.strumline == SEPARATE) list.push(data);
		list.sort((a, b) -> a.slot - b.slot);
		return list;
	}

	public static function getExtraCharacter(song:SwagSong, slot:Int):ExtraCharacterData
	{
		if(song == null || song.extraCharacters == null) return null;
		for (data in song.extraCharacters)
			if(data != null && data.slot == slot) return data;
		return null;
	}

	public static function sanitizeExtraCharacters(songJson:Dynamic):Void
	{
		var list:Array<Dynamic> = songJson.extraCharacters;
		if(list == null) return;

		var clean:Array<Dynamic> = [];
		var used:Array<Int> = [];
		var pending:Array<Dynamic> = [];
		for (data in list)
		{
			if(data == null || clean.length + pending.length >= MAX_CHARACTERS - 2) continue;
			if(data.character == null) data.character = '';
			if(!PARENTS.contains(data.parent)) data.parent = 'dad';
			if(data.strumline != SEPARATE) data.strumline = SHARED;
			if(data.anchor != null && !PARENTS.contains(data.anchor)) Reflect.deleteField(data, 'anchor');

			var slot:Null<Int> = Std.parseInt(Std.string(data.slot));
			if(slot == null || slot < FIRST_EXTRA_SLOT || slot > MAX_CHARACTERS || used.contains(slot)) pending.push(data);
			else
			{
				data.slot = slot;
				used.push(slot);
				clean.push(data);
			}
		}

		var next:Int = FIRST_EXTRA_SLOT;
		for (data in pending)
		{
			while(used.contains(next)) next++;
			data.slot = next;
			used.push(next);
			clean.push(data);
		}

		clean.sort((a, b) -> Std.int(a.slot) - Std.int(b.slot));
		for (data in clean)
		{
			if(data.strumlineOf == null) continue;
			var hostSlot:Null<Int> = Std.parseInt(Std.string(data.strumlineOf));
			var host:Dynamic = null;
			if(data.strumline == SHARED && hostSlot != null && hostSlot != data.slot)
				for (other in clean) if(other.slot == hostSlot && other.strumline == SEPARATE) host = other;
			if(host == null) Reflect.deleteField(data, 'strumlineOf');
			else
			{
				data.strumlineOf = hostSlot;
				data.parent = host.parent;
			}
		}
		songJson.extraCharacters = clean;
	}

	public static function convertExtraStrumlines(songJson:Dynamic):Void
	{
		var old:Array<Dynamic> = songJson.extraStrumlines;
		if(old == null) return;
		songJson.extraStrumlines = null;
		if(old.length < 1 || songJson.extraCharacters != null) return;

		var characters:Array<ExtraCharacterData> = [];
		var converted:Array<ExtraCharacterData> = [];
		var lanes:Array<Int> = [];
		var separateCount:Int = 0;
		for (data in old)
		{
			if(data == null || characters.length >= MAX_CHARACTERS - 2)
			{
				converted.push(null);
				lanes.push(-1);
				continue;
			}

			var type:String = Std.string(data.type).toUpperCase();
			var parent:String = (type == 'PLAYER' || type == 'BOYFRIEND' || type == 'BF') ? 'bf' : 'dad';
			var anchor:String = switch(Std.string(data.stagePosition).toUpperCase())
			{
				case 'BF' | 'BOYFRIEND': 'bf';
				case 'GF' | 'GIRLFRIEND': 'gf';
				case 'DAD' | 'OPPONENT': 'dad';
				default: null;
			}
			var shared:Bool = data.useExistingStrumline == true;
			var entry:ExtraCharacterData = {
				slot: FIRST_EXTRA_SLOT + characters.length,
				character: (data.character != null) ? data.character : '',
				parent: parent,
				strumline: shared ? SHARED : SEPARATE
			};
			if(anchor != null && anchor != parent) entry.anchor = anchor;
			if(!shared)
			{
				entry.playable = parent == 'bf';
				entry.visible = data.visible != false;
				if(data.scale != null) entry.scale = data.scale;
				if(data.spacing != null) entry.spacing = data.spacing;
				if(data.scrollSpeed != null) entry.scrollSpeed = data.scrollSpeed;
				if(data.usesChartScroll != null) entry.usesChartScroll = data.usesChartScroll;
			}
			characters.push(entry);
			converted.push(entry);
			lanes.push(shared ? -1 : separateCount++);
		}

		var lostTypes:Int = 0;
		var sections:Array<SwagSection> = songJson.notes;
		if(sections != null)
		{
			for (section in sections)
			{
				if(section == null || section.sectionNotes == null) continue;
				for (note in section.sectionNotes)
				{
					var column:Int = Std.int(note[1]);
					if(column < 8) continue;
					var index:Int = Std.int(column / 4) - 2;
					var entry:ExtraCharacterData = (index < converted.length) ? converted[index] : null;
					if(entry == null) continue;

					if(entry.strumline == SEPARATE)
					{
						note[1] = 8 + lanes[index] * 4 + column % 4;
						continue;
					}

					note[1] = column % 4 + (entry.parent == 'bf' ? 0 : 4);
					var noteType:String = (note.length > 3 && note[3] != null) ? Std.string(note[3]) : '';
					if(noteType == '' || noteType == '0') note[3] = characterNoteType(entry.slot);
					else if(noteType == 'Alt Animation') note[3] = characterNoteType(entry.slot, true);
					else lostTypes++;
				}
			}
		}

		songJson.extraCharacters = characters;
		trace('Converted ${characters.length} extra strumlines/characters, $lostTypes notes successfully stored.');
	}

	public static function renameCharacterLabels(songJson:Dynamic):Void
	{
		var sections:Array<Dynamic> = songJson.notes;
		if(sections == null) return;
		for (section in sections)
		{
			if(section == null) continue;
			var target:String = section.mustHitTarget;
			var targetSlot:Int = cameraTargetSlot(target);
			if(targetSlot > 0 && target != cameraTargetName(targetSlot)) section.mustHitTarget = cameraTargetName(targetSlot);

			var notes:Array<Dynamic> = section.sectionNotes;
			if(notes == null) continue;
			for (note in notes)
			{
				if(note == null || note.length < 4 || !Std.isOfType(note[3], String)) continue;
				var noteType:String = note[3];
				if(!noteType.startsWith('Character ')) continue;
				var slot:Int = slotFromNoteType(noteType);
				if(slot > 0) note[3] = characterNoteType(slot, noteType.endsWith(' ALT Note'));
			}
		}
	}

	public static function convert(songJson:Dynamic) // Convert old charts to psych_v1 format
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;

		for (section in sectionsData)
		{
			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
			}

			for (note in section.sectionNotes)
			{
				if (note[1] >= 8)
				{
					if(!Std.isOfType(note[3], String))
						note[3] = Note.defaultNoteTypes[note[3]];
					continue;
				}
				var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

				if(!Std.isOfType(note[3], String))
					note[3] = Note.defaultNoteTypes[note[3]]; //compatibility with Week 7 and 0.1-0.3 psych charts
			}
		}
	}

	public static var chartPath:String;
	public static var loadedSongName:String;
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);
		if(PlayState.SONG == null)
		{
			throw new haxe.Exception('Chart file not found: $jsonInput');
		}
		loadedSongName = folder;
		chartPath = _lastPath;
		modcharting.ModchartFile.editorData = null;
		#if windows
		// prevent any saving errors by fixing the path on Windows (being the only OS to ever use backslashes instead of forward slashes for paths)
		chartPath = chartPath.replace('/', '\\');
		#end
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	static var _lastPath:String;
	public static function findChartPath(jsonInput:String, ?folder:String):String
	{
		if(folder == null) folder = jsonInput;

		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);

		#if MODS_ALLOWED
		var newPath0:String = Paths.json('songs/$formattedFolder/charts/$formattedSong');
		if(FileSystem.exists(newPath0)) return newPath0;

		var newPathRoot:String = Paths.json('songs/$formattedFolder/$formattedSong');
		if(FileSystem.exists(newPathRoot)) return newPathRoot;

		var newPath1:String = Paths.json('$formattedFolder/charts/$formattedSong');
		if(FileSystem.exists(newPath1)) return newPath1;

		var newPath2:String = Paths.json('$formattedFolder/chart/$formattedSong');
		if(FileSystem.exists(newPath2)) return newPath2;
		#end

		var path:String = Paths.json('$formattedFolder/$formattedSong');
		#if MODS_ALLOWED
		if(FileSystem.exists(path)) return path;
		#end
		return Assets.exists(path) ? path : null;
	}

	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		_lastPath = findChartPath(jsonInput, folder);
		if(_lastPath == null) return null;

		var rawData:String = null;
		#if MODS_ALLOWED
		if(FileSystem.exists(_lastPath))
			rawData = File.getContent(_lastPath);
		else
		#end
		rawData = Assets.getText(_lastPath);

		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	static function getCodenameMeta(?songName:String):Dynamic
	{
		if(songName == null) return null;

		var formattedFolder:String = Paths.formatToSongPath(songName);
		var possiblePaths:Array<String> = [
			Paths.json('$formattedFolder/meta'),
			Paths.json('$formattedFolder/charts/meta'),
			Paths.json('$formattedFolder/chart/meta')
		];

		var rawMeta:String = null;
		for (metaPath in possiblePaths)
		{
			#if MODS_ALLOWED
			if(FileSystem.exists(metaPath))
			{
				rawMeta = File.getContent(metaPath);
				break;
			}
			#end
			if(Assets.exists(metaPath))
			{
				rawMeta = Assets.getText(metaPath);
				break;
			}
		}

		if(rawMeta == null)
		{
			trace('WARNING: could not find meta.json for codename song $songName.');
			return null;
		}

		return Json.parse(rawMeta);
	}

	static function convertCodenameChart(songJson:Dynamic, ?nameForError:String):Void
	{
		funkin.editors.content.Codename.convertToPsych(songJson, getCodenameMeta(nameForError), nameForError);
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if(!Reflect.hasField(songJson, 'notes') && Reflect.field(songJson, 'codenameChart') != true && !Reflect.hasField(songJson, 'strumLines') && !Reflect.hasField(songJson, 'events'))
		{
			throw new haxe.Exception('The selected file is not a valid chart (it looks like a meta.json or another file, not a difficulty chart).');
		}

		if(Reflect.field(songJson, 'codenameChart') == true)
		{
			songJson.format = 'psych_v1_convert';
			convertCodenameChart(songJson, nameForError);
			renameCharacterLabels(songJson);
			sanitizeExtraCharacters(songJson);
			return songJson;
		}

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';

			switch(convertTo)
			{
				case 'psych_v1':
					if(!fmt.startsWith('psych_v1')) //Convert to Psych 1.0 format
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
		}
		convertExtraStrumlines(songJson);
		renameCharacterLabels(songJson);
		sanitizeExtraCharacters(songJson);
		return songJson;
	}
}