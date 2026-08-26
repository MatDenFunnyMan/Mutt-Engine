package funkin.editors.content;

import funkin.data.Song.SwagSection;
import funkin.data.Song.ExtraStrumlineData;

class Codename
{
	public static function convertEvents(rawEvents:Array<Dynamic>):Array<Dynamic>
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

			var converted:Array<String> = [name];
			if(params != null)
				for (p in params)
					converted.push(Std.string(p));

			pushEvent(result, time, converted);
		}

		return result;
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

	public static function resolveNoteType(noteTypes:Array<String>, rawTypeId:Dynamic):String
	{
		var typeId:Null<Int> = rawTypeId;
		if(typeId == null || typeId <= 0) return '';
		return (noteTypes[typeId - 1] != null) ? noteTypes[typeId - 1] : '';
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
		var extraLines:Array<Dynamic> = [];

		for (line in strumLines)
		{
			if(playerLine == null && line.type == 1)
				playerLine = line;
			else if(opponentLine == null && line.type == 0)
				opponentLine = line;
			else
				extraLines.push(line);
		}

		songJson.player1 = (opponentLine != null) ? opponentLine.characters[0] : 'dad';
		songJson.player2 = (playerLine != null) ? playerLine.characters[0] : 'bf';

		var gfLine:Dynamic = null;
		var finalExtraLines:Array<Dynamic> = [];
		for (line in extraLines)
		{
			if(gfLine == null && line.position == 'gf')
				gfLine = line;
			else
				finalExtraLines.push(line);
		}
		songJson.gfVersion = (gfLine != null) ? gfLine.characters[0] : 'gf';

		var allNotes:Array<Dynamic> = [];

		function pushLineNotes(line:Dynamic, roleOffset:Int):Void
		{
			var keyCount:Int = (line.keyCount != null) ? line.keyCount : 4;
			for (note in (line.notes : Array<Dynamic>))
			{
				allNotes.push([
					note.time,
					note.id + (roleOffset * keyCount),
					(note.sLen != null) ? note.sLen : 0,
					resolveNoteType(noteTypes, note.type)
				]);
			}
		}

		if(playerLine != null) pushLineNotes(playerLine, 0);
		if(opponentLine != null) pushLineNotes(opponentLine, 1);

		var extraStrumlines:Array<ExtraStrumlineData> = [];
		var extraIndex:Int = 2;
		for (line in finalExtraLines)
		{
			pushLineNotes(line, extraIndex);

			extraStrumlines.push({
				character: line.characters[0],
				type: line.position,
				stagePosition: line.position,
				scale: (line.strumScale != null) ? line.strumScale : 1,
				spacing: (line.strumSpacing != null) ? line.strumSpacing : 1,
				hudX: (line.strumPos != null) ? line.strumPos[0] : 0,
				hudY: (line.strumPos != null) ? line.strumPos[1] : 0,
				visible: (line.visible != null) ? line.visible : true,
				scrollSpeed: (line.scrollSpeed != null) ? line.scrollSpeed : songJson.speed,
				usesChartScroll: line.scrollSpeed != null,
				useExistingStrumline: false,
				layer: extraIndex
			});
			extraIndex++;
		}
		if(extraStrumlines.length > 0) songJson.extraStrumlines = extraStrumlines;

		allNotes.sort(function(a, b) return (a[0] < b[0]) ? -1 : ((a[0] > b[0]) ? 1 : 0));

		var rawEvents:Array<Dynamic> = (songJson.events != null) ? songJson.events : [];

		var bpmChanges:Array<Dynamic> = [];
		for (event in rawEvents)
		{
			if(event.name == 'BPM Change')
				bpmChanges.push({time: event.time, bpm: event.params[0]});
		}
		bpmChanges.sort(function(a, b) return (a.time < b.time) ? -1 : ((a.time > b.time) ? 1 : 0));

		var sections:Array<SwagSection> = [];
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

		songJson.notes = sections;
		songJson.events = convertEvents(rawEvents);

		Reflect.setField(songJson, 'codenameChart', false);
	}
}