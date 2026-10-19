package funkin.editors.content;

import funkin.data.Song;
import funkin.data.Song.SwagSection;
import funkin.data.Song.ExtraCharacterData;
import funkin.data.StageData;

typedef CodenameEventContext =
{
	var bpm:Float;
	var bpmChanges:Array<Dynamic>;
	var lineKeys:Array<Array<String>>;
	var speed:Float;
	var stageZoom:Float;
}

class Codename
{
	public static function convertEvents(rawEvents:Array<Dynamic>, ?context:CodenameEventContext):Array<Dynamic>
	{
		var sorted:Array<Dynamic> = rawEvents.copy();
		sorted.sort(function(a, b) {
			var timeA:Float = Reflect.field(a, "time");
			var timeB:Float = Reflect.field(b, "time");
			if (timeA < timeB) return -1;
			if (timeA > timeB) return 1;
			return 0;
		});

		var result:Array<Dynamic> = [];

		for (raw in sorted)
		{
			var name:String = Reflect.field(raw, "name");
			var time:Float = Reflect.field(raw, "time");
			var params:Array<Dynamic> = Reflect.field(raw, "params");

			if(name == null) continue;

			var events:Array<Array<String>> = (context != null) ? convertEvent(name, (params != null) ? params : [], time, context) : null;
			if(events != null)
			{
				for (event in events) pushEvent(result, time, event);
				continue;
			}

			var converted:Array<String> = [name];
			if(params != null)
				for (p in params)
					converted.push(Std.string(p));

			pushEvent(result, time, converted);
		}

		return result;
	}

	static function convertEvent(name:String, params:Array<Dynamic>, time:Float, context:CodenameEventContext):Array<Array<String>>
	{
		inline function param(index:Int):Dynamic return (index < params.length) ? params[index] : null;

		switch(name)
		{
			case 'BPM Change':
				return [];

			case 'Camera Movement':
				var keys:Array<String> = lineKeysAt(context, param(0));
				if(keys == null) return null;
				var position:String = eventLabel(keys[0]);
				var offsetX:Float = toFloat(param(5));
				var offsetY:Float = toFloat(param(6));
				if(offsetX != 0 || offsetY != 0) position += ', ${number(offsetX)}, ${number(offsetY)}';
				var movement:Array<String> = tweenValues(param(1), param(2), param(3), param(4), time, context);
				return [['Cam Follow Pos', position, movement[0], movement[1], movement[2], 'false']];

			case 'Camera Position':
				if(isTrue(param(6))) return null;
				var movement:Array<String> = tweenValues(param(2), param(3), param(4), param(5), time, context);
				return [['Cam Follow Pos', '${number(toFloat(param(0)))}, ${number(toFloat(param(1)))}', movement[0], movement[1], movement[2], 'true']];

			case 'Camera Zoom':
				if(Std.string(param(2)) == 'camHUD' || isTrue(param(7))) return null;
				var zoom:Float = toFloat(param(1));
				if(Std.string(param(6)) == 'stage') zoom *= context.stageZoom;
				var movement:Array<String> = tweenValues(param(0), param(3), param(4), param(5), time, context);
				return [['Cam Zoom', number(zoom), movement[0], movement[1], movement[2], 'true']];

			case 'Camera Flash':
				if(isTrue(param(0))) return null;
				var color:Int = Std.int(toFloat(param(1)));
				return [['Cam Flash', stepSeconds(context, time, param(2)), '#' + StringTools.hex(color & 0xFFFFFF, 6), (Std.string(param(3)) == 'camHUD') ? 'HUD' : 'Game']];

			case 'Scroll Speed Change':
				var speed:Float = toFloat(param(1));
				if(speed <= 0) return null;
				var value:Float = (isTrue(param(5)) || context.speed <= 0) ? speed : speed / context.speed;
				return [['Set Note Speed', 'All', number(value), isEnabled(param(0)) ? stepSeconds(context, time, param(2)) : '0']];

			case 'Camera Modulo Change':
				var every:String = (param(2) != null) ? Std.string(param(2)).toUpperCase() : 'BEAT';
				if(every == 'STEP') return null;
				var interval:Float = toFloat(param(0));
				if(every == 'MEASURE') interval *= 4;
				return [['Cam Bopping', number(interval), number((param(1) != null) ? toFloat(param(1)) : 1)]];

			case 'Add Camera Zoom':
				var amount:String = number(toFloat(param(0)));
				return [(Std.string(param(1)) == 'camHUD') ? ['Add Cam Zoom', '0', amount] : ['Add Cam Zoom', amount, '0']];

			case 'Play Animation':
				var keys:Array<String> = lineKeysAt(context, param(0));
				if(keys == null || param(1) == null) return null;
				var forced:String = isTrue(param(2)) ? 'true' : 'false';
				return [for (key in keys) ['Play Animation', eventLabel(key), Std.string(param(1)), forced, 'false']];
		}
		return null;
	}

	static function tweenValues(enabled:Dynamic, steps:Dynamic, ease:Dynamic, direction:Dynamic, time:Float, context:CodenameEventContext):Array<String>
	{
		if(!isEnabled(enabled)) return ['0', 'linear', 'In'];
		var easeName:String = (ease != null) ? Std.string(ease) : 'CLASSIC';
		if(easeName.toUpperCase() == 'CLASSIC') return ['', 'classic', 'In'];
		return [stepSeconds(context, time, steps), easeName, (direction != null) ? Std.string(direction) : 'In'];
	}

	static function stepSeconds(context:CodenameEventContext, time:Float, steps:Dynamic):String
	{
		var bpm:Float = context.bpm;
		for (change in context.bpmChanges) if(change.time <= time) bpm = change.bpm;
		var count:Float = (steps != null) ? toFloat(steps) : 4;
		return number(count * 15 / bpm);
	}

	static function lineKeysAt(context:CodenameEventContext, index:Dynamic):Array<String>
	{
		var line:Null<Int> = Std.parseInt(Std.string(index));
		if(line == null || line < 0 || line >= context.lineKeys.length) return null;
		var keys:Array<String> = context.lineKeys[line];
		return (keys != null && keys.length > 0) ? keys : null;
	}

	static function eventLabel(key:String):String
	{
		return switch(key)
		{
			case 'bf': 'BF';
			case 'dad': 'Dad';
			case 'gf': 'GF';
			default: key;
		}
	}

	static function number(value:Float):String
		return Std.string(Math.round(value * 1000) / 1000);

	static function toFloat(value:Dynamic):Float
	{
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? 0 : parsed;
	}

	static function isTrue(value:Dynamic):Bool
		return value == true || Std.string(value).toLowerCase() == 'true';

	static function isEnabled(value:Dynamic):Bool
		return !(value == false || Std.string(value).toLowerCase() == 'false');

	static function applyCameraTarget(section:SwagSection, key:String, extras:Array<ExtraCharacterData>):Void
	{
		switch(key)
		{
			case 'bf':
				section.mustHitSection = true;
			case 'dad':
				section.mustHitSection = false;
			case 'gf':
				section.mustHitSection = false;
				section.mustHitTarget = 'GF';
			default:
				var slot:Null<Int> = Std.parseInt(key);
				if(slot == null) return;
				for (entry in extras)
				{
					if(entry.slot != slot) continue;
					section.mustHitSection = entry.parent == 'bf';
					section.mustHitTarget = Song.cameraTargetName(slot);
				}
		}
	}

	static function pushEvent(result:Array<Dynamic>, time:Float, converted:Array<String>):Void
	{
		for (entry in result)
		{
			if (entry[0] == time)
			{
				entry[1].push(converted);
				return;
			}
		}
		result.push([time, [converted]]);
	}

	static function compareNoteTimes(a:Dynamic, b:Dynamic):Int
	{
		var timeA:Float = a[0];
		var timeB:Float = b[0];
		return (timeA < timeB) ? -1 : ((timeA > timeB) ? 1 : 0);
	}

	static function firstCharacter(line:Dynamic, fallback:String):String
	{
		if(line == null || line.characters == null || line.characters.length < 1) return fallback;
		var name:String = line.characters[0];
		return (name != null && name.length > 0) ? name : fallback;
	}

	public static function resolveNoteType(noteTypes:Array<String>, rawTypeId:Dynamic):String
	{
		var typeId:Null<Int> = rawTypeId;
		if(typeId == null || typeId <= 0) return '';
		var name:String = noteTypes[typeId - 1];
		return switch(name)
		{
			case null: '';
			case 'Alt Anim Note': 'Alt Animation';
			case 'No Anim Note': 'No Animation';
			default: name;
		}
	}

	public static function convertToPsych(songJson:Dynamic, ?metaJson:Dynamic, ?songName:String):Void
	{
		if(songJson.bpm == null)
		{
			var bpmField:Dynamic = (metaJson != null) ? Reflect.field(metaJson, 'bpm') : null;
			songJson.bpm = (bpmField != null && !Math.isNaN(bpmField)) ? bpmField : 100;
		}

		if(songName != null && songName.length > 0) songJson.song = songName;
		else if(metaJson != null && Reflect.field(metaJson, 'name') != null) songJson.song = Reflect.field(metaJson, 'name');

		songJson.needsVoices = (metaJson != null && Reflect.hasField(metaJson, 'needsVoices')) ? Reflect.field(metaJson, 'needsVoices') : true;
		songJson.speed = (songJson.scrollSpeed != null) ? songJson.scrollSpeed : 1;

		var strumLines:Array<Dynamic> = (songJson.strumLines != null) ? songJson.strumLines : [];
		var noteTypes:Array<String> = (songJson.noteTypes != null) ? songJson.noteTypes : [];

		var playerLine:Dynamic = null;
		var opponentLine:Dynamic = null;
		var gfLine:Dynamic = null;
		var extraLines:Array<Dynamic> = [];

		for (line in strumLines)
		{
			var position:String = (line.position != null) ? Std.string(line.position).toLowerCase() : '';
			if(playerLine == null && line.type == 1)
				playerLine = line;
			else if(opponentLine == null && line.type == 0)
				opponentLine = line;
			else if(gfLine == null && (position == 'girlfriend' || position == 'gf'))
				gfLine = line;
			else
				extraLines.push(line);
		}

		songJson.player1 = firstCharacter(playerLine, 'bf');
		songJson.player2 = firstCharacter(opponentLine, 'dad');
		songJson.gfVersion = firstCharacter(gfLine, 'gf');

		var allNotes:Array<Dynamic> = [];

		function pushLineNotes(line:Dynamic, columnOffset:Int):Void
		{
			if(line.notes == null) return;
			for (note in (line.notes : Array<Dynamic>))
			{
				var data:Array<Dynamic> = [];
				data.push(note.time);
				data.push(Std.int(note.id) + columnOffset);
				data.push((note.sLen != null) ? note.sLen : 0);
				data.push(resolveNoteType(noteTypes, note.type));
				allNotes.push(data);
			}
		}

		if(playerLine != null) pushLineNotes(playerLine, 0);
		if(opponentLine != null) pushLineNotes(opponentLine, 4);

		var extras:Array<ExtraCharacterData> = [];
		var singAlongs:Array<Array<String>> = [];
		var separateCount:Int = 0;
		var lineKeys:Array<Array<String>> = [for (_ in strumLines) null];
		function setLineKeys(line:Dynamic, keys:Array<String>):Void
		{
			var index:Int = strumLines.indexOf(line);
			if(index >= 0) lineKeys[index] = keys;
		}

		function addExtra(character:String, parent:String, separate:Bool, line:Dynamic):ExtraCharacterData
		{
			if(extras.length >= Song.MAX_CHARACTERS - 2)
			{
				trace('WARNING: Codename chart contains more than ${Song.MAX_CHARACTERS} characters.');
				return null;
			}

			var entry:ExtraCharacterData = {
				slot: Song.FIRST_EXTRA_SLOT + extras.length,
				character: (character != null) ? character : '',
				parent: parent,
				strumline: separate ? Song.SEPARATE : Song.SHARED
			};
			if(separate && line != null)
			{
				entry.playable = line.type == 1;
				entry.visible = line.visible != false;
				if(line.strumScale != null) entry.scale = line.strumScale;
				if(line.strumSpacing != null) entry.spacing = line.strumSpacing;
				if(line.scrollSpeed != null)
				{
					entry.scrollSpeed = line.scrollSpeed;
					entry.usesChartScroll = true;
				}
				pushLineNotes(line, 8 + separateCount * 4);
				separateCount++;
			}
			extras.push(entry);
			return entry;
		}

		function addFollowers(line:Dynamic, parent:String, commander:String):Void
		{
			if(line == null) return;
			var characters:Array<String> = line.characters;
			var followers:Array<String> = [];
			if(characters != null)
			{
				for (k in 1...characters.length)
				{
					var entry:ExtraCharacterData = addExtra(characters[k], parent, false, null);
					if(entry != null) followers.push(Std.string(entry.slot));
				}
			}
			setLineKeys(line, [commander].concat(followers));
			if(followers.length > 0) singAlongs.push([commander, followers.join(',')]);
		}

		addFollowers(playerLine, 'bf', 'bf');
		addFollowers(opponentLine, 'dad', 'dad');
		addFollowers(gfLine, 'gf', 'gf');

		if(gfLine != null && gfLine.notes != null && (gfLine.notes : Array<Dynamic>).length > 0)
			addExtra('', 'gf', true, gfLine);

		for (line in extraLines)
		{
			var characters:Array<String> = (line.characters != null) ? line.characters : [];
			var entry:ExtraCharacterData = addExtra(characters.length > 0 ? characters[0] : '', line.type == 1 ? 'bf' : 'dad', true, line);
			if(entry == null) continue;

			var followers:Array<String> = [];
			for (k in 1...characters.length)
			{
				var follower:ExtraCharacterData = addExtra(characters[k], entry.parent, false, null);
				if(follower != null) followers.push(Std.string(follower.slot));
			}
			setLineKeys(line, [Std.string(entry.slot)].concat(followers));
			if(followers.length > 0) singAlongs.push([Std.string(entry.slot), followers.join(',')]);
		}

		songJson.extraCharacters = (extras.length > 0) ? extras : null;
		songJson.extraStrumlines = null;

		allNotes.sort(compareNoteTimes);

		var rawEvents:Array<Dynamic> = (songJson.events != null) ? songJson.events : [];

		var bpmChanges:Array<Dynamic> = [];
		for (event in rawEvents)
		{
			if(event.name == 'BPM Change')
				bpmChanges.push({time: event.time, bpm: event.params[0]});
		}
		bpmChanges.sort(function(a, b) return (a.time < b.time) ? -1 : ((a.time > b.time) ? 1 : 0));

		var sections:Array<SwagSection> = [];
		var sectionStarts:Array<Float> = [];
		var curBpm:Float = songJson.bpm;
		var curTime:Float = 0;
		var bpmIndex:Int = 0;
		var noteIndex:Int = 0;
		var lastNoteTime:Float = (allNotes.length > 0) ? allNotes[allNotes.length - 1][0] : 0;

		while (noteIndex < allNotes.length || curTime <= lastNoteTime)
		{
			while(bpmIndex < bpmChanges.length && bpmChanges[bpmIndex].time <= curTime)
			{
				curBpm = bpmChanges[bpmIndex].bpm;
				bpmIndex++;
			}

			var sectionLength:Float = (60000 / curBpm) * 4;
			var sectionEnd:Float = curTime + sectionLength;

			var sectionNotes:Array<Dynamic> = [];
			while(noteIndex < allNotes.length && allNotes[noteIndex][0] < sectionEnd)
			{
				sectionNotes.push(allNotes[noteIndex]);
				noteIndex++;
			}

			sectionStarts.push(curTime);
			sections.push({
				sectionNotes: sectionNotes,
				sectionBeats: 4,
				mustHitSection: true,
				bpm: curBpm,
				changeBPM: bpmIndex > 0
			});

			curTime = sectionEnd;
			if(sections.length > 100000) break;
		}

		var cameraMoves:Array<Dynamic> = [for (event in rawEvents) if(event.name == 'Camera Movement' && event.params != null) event];
		cameraMoves.sort(function(a, b) return (a.time < b.time) ? -1 : ((a.time > b.time) ? 1 : 0));
		var moveIndex:Int = 0;
		var cameraKey:String = null;
		for (index => section in sections)
		{
			while(moveIndex < cameraMoves.length && cameraMoves[moveIndex].time <= sectionStarts[index] + 1)
			{
				var line:Null<Int> = Std.parseInt(Std.string(cameraMoves[moveIndex].params[0]));
				if(line != null && line >= 0 && line < lineKeys.length && lineKeys[line] != null) cameraKey = lineKeys[line][0];
				moveIndex++;
			}
			if(cameraKey != null) applyCameraTarget(section, cameraKey, extras);
		}

		var stageZoom:Float = 1;
		if(songJson.stage != null)
		{
			var stageFile:StageFile = StageData.getStageFile(songJson.stage);
			if(stageFile != null && stageFile.defaultZoom > 0) stageZoom = stageFile.defaultZoom;
		}

		songJson.notes = sections;
		songJson.events = convertEvents(rawEvents, {bpm: songJson.bpm, bpmChanges: bpmChanges, lineKeys: lineKeys, speed: songJson.speed, stageZoom: stageZoom});
		for (singAlong in singAlongs)
			pushEvent(songJson.events, 0, ['Character Sing-Along', singAlong[0], singAlong[1]]);

		Reflect.setField(songJson, 'codenameChart', false);
		for (field in ['strumLines', 'noteTypes', 'chartVersion', 'scrollSpeed'])
			Reflect.deleteField(songJson, field);
	}
}