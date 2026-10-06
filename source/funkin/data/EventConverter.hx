package funkin.data;

using StringTools;

typedef EventTween = {
	var mode:String;
	var duration:String;
	var ease:String;
	var direction:String;
}

class EventConverter
{
	static final EASE_NAMES:Array<String> = ['linear', 'sine', 'quad', 'cube', 'quart', 'quint', 'expo', 'circ', 'back', 'elastic', 'bounce', 'smoothStep', 'smootherStep'];

	public static function convertList(events:Array<Dynamic>, stepSecondsAt:Float->Float):Int
	{
		if(events == null) return 0;

		var converted:Int = 0;
		for (event in events)
		{
			var time:Float = event[0];
			var subEvents:Array<Dynamic> = event[1];
			if(subEvents == null) continue;

			var result:Array<Dynamic> = [];
			for (sub in subEvents)
			{
				var data:Array<String> = [for (value in (sub:Array<Dynamic>)) (value != null) ? Std.string(value) : ''];
				var newEvents:Array<Array<String>> = convertEvent(data, time, stepSecondsAt);
				if(newEvents == null)
				{
					result.push(sub);
					continue;
				}
				converted++;
				for (newEvent in newEvents) result.push(newEvent);
			}

			if(result.length < 1) result.push(['', '', '']);
			event[1] = result;
		}
		return converted;
	}

	public static function stepSecondsForSong(song:Dynamic):Float->Float
	{
		var baseBpm:Float = (song != null && song.bpm != null) ? song.bpm : 100;
		var changes:Array<{time:Float, bpm:Float}> = [];
		var curBpm:Float = baseBpm;
		var totalTime:Float = 0;

		var sections:Array<Dynamic> = (song != null) ? song.notes : null;
		if(sections != null)
		{
			for (section in sections)
			{
				if(section.changeBPM == true && section.bpm != null && section.bpm != curBpm)
				{
					curBpm = section.bpm;
					changes.push({time: totalTime, bpm: curBpm});
				}
				var beats:Float = (section.sectionBeats != null) ? section.sectionBeats : 4;
				totalTime += (60 / curBpm) * 1000 / 4 * Math.round(beats * 4);
			}
		}

		return function(time:Float):Float
		{
			var bpm:Float = baseBpm;
			for (change in changes)
				if(time >= change.time) bpm = change.bpm;
			return 60 / bpm / 4;
		}
	}

	public static function convertEvent(data:Array<String>, time:Float, stepSecondsAt:Float->Float):Array<Array<String>>
	{
		var name:String = data[0];
		inline function v(i:Int):String
			return (i < data.length && data[i] != null) ? data[i].trim() : '';

		var trailingEmpty:Bool = true;
		for (i in 3...data.length)
			if(v(i).length > 0) trailingEmpty = false;

		switch(name)
		{
			case 'Add Camera Zoom':
				return [['Add Cam Zoom', v(1), v(2)]];

			case 'Set Camera Bopping':
				return [['Cam Bopping', v(1), v(2)]];

			case 'Camera Follow Pos':
				if(v(1).length < 1 && v(2).length < 1)
					return [['Cam Follow Pos', '', '', 'classic', 'InOut', 'true']];
				var x:String = (v(1).length > 0) ? v(1) : '0';
				var y:String = (v(2).length > 0) ? v(2) : '0';
				return [['Cam Follow Pos', '$x, $y', '', 'classic', 'InOut', 'true']];

			case 'Target Follow Pos' | '(STEPS) Target Follow Pos':
				if(v(1).length < 1)
					return [['Cam Follow Pos', '', '', 'classic', 'InOut', 'true']];
				var tween:EventTween = parseTween(v(2), '0.3', 'sineInOut', name.startsWith('(STEPS)'), time, stepSecondsAt);
				return [['Cam Follow Pos', v(1), tween.duration, tween.ease, tween.direction, 'true']];

			case 'Target Camera' | '(STEPS) Target Camera':
				var tween:EventTween = parseTween(v(2), '0.3', 'sineInOut', name.startsWith('(STEPS)'), time, stepSecondsAt);
				return [['Cam Follow Pos', v(1), tween.duration, tween.ease, tween.direction, 'false']];

			case 'Set Cam Zoom' | '(STEPS) Set Cam Zoom':
				if(name == 'Set Cam Zoom' && !trailingEmpty) return null;
				var tween:EventTween = parseTween(v(2), '1', 'linear', name.startsWith('(STEPS)'), time, stepSecondsAt);
				return [['Set Cam Zoom', v(1), tween.duration, tween.ease, tween.direction, 'true']];

			case 'Play Animation':
				if(!trailingEmpty) return null;
				if(isCharacterToken(v(1)) && !isCharacterToken(v(2))) return null;
				return [['Play Animation', legacyCharacter(v(2)), v(1), 'false', 'false']];

			case 'Alt Idle Animation':
				return [['Set Char Idle Alt', legacyCharacter(v(1)), v(2)]];

			case 'Screen Shake':
				var result:Array<Array<String>> = [];
				var cams:Array<String> = ['Game', 'HUD'];
				for (i in 0...2)
				{
					var parts:Array<String> = v(i + 1).split(',');
					var duration:Float = Std.parseFloat(parts[0]);
					var intensity:Float = (parts.length > 1) ? Std.parseFloat(parts[1]) : Math.NaN;
					if(Math.isNaN(duration) || Math.isNaN(intensity) || duration <= 0 || intensity == 0) continue;
					var strength:Float = Math.min(3, Math.abs(intensity) / 0.015);
					result.push(['Cam Shake', cams[i], formatNumber(strength), formatNumber(duration)]);
				}
				return result;

			case 'Flash Camera':
				return [['Cam Flash', v(1), v(2), 'HUD']];

			case 'Video Player':
				var params:Array<String> = [for (part in v(1).split(',')) part.trim()];
				var camera:String = 'Other';
				if(params.length > 1)
				{
					switch(params[1].toLowerCase())
					{
						case 'game' | 'camgame': camera = 'Game';
						case 'hud' | 'camhud': camera = 'HUD';
					}
				}
				var flags:Array<String> = [for (part in v(2).split(',')) part.trim().toLowerCase()];
				var flagDefaults:Array<Bool> = [false, true, false, true];
				var bools:Array<String> = [];
				for (i in 0...4)
					bools.push((v(2).length > 0 && i < flags.length) ? Std.string(flags[i] == 'true') : Std.string(flagDefaults[i]));
				return [['Play Video', params[0], camera, (params.length > 2) ? params[2] : '', bools[0], bools[1], bools[2], bools[3]]];

			case 'Change Note Skin':
				return [['Change Notes', skinTarget(v(2)), skinValue(v(1)), '', '', '']];
			case 'Change NoteStrum Skin':
				return [['Change Notes', skinTarget(v(2)), '', skinValue(v(1)), '', '']];
			case 'Change Note Splash Skin':
				return [['Change Notes', skinTarget(v(2)), '', '', skinValue(v(1)), '']];
			case 'Change Hold Cover Skin':
				return [['Change Notes', skinTarget(v(2)), '', '', '', skinValue(v(1))]];

			case 'Change Scroll Speed':
				return [['Set Note Speed', 'All', (v(1).length > 0) ? v(1) : '1', v(2)]];
		}
		return null;
	}

	static function parseTween(raw:String, defaultDuration:String, defaultEase:String, steps:Bool, time:Float, stepSecondsAt:Float->Float):EventTween
	{
		if(raw.length < 1) return {mode: 'classic', duration: '', ease: 'classic', direction: 'InOut'};

		var tokens:Array<String> = [for (part in raw.split(',')) part.trim()];
		for (token in tokens)
			if(token.toLowerCase() == 'instant') return {mode: 'instant', duration: '', ease: 'linear', direction: 'InOut'};

		var duration:String = defaultDuration;
		var easeName:String = defaultEase;
		for (token in tokens)
		{
			if(token.length < 1) continue;
			var number:Float = Std.parseFloat(token);
			if(!Math.isNaN(number))
			{
				if(number > 0) duration = token;
			}
			else easeName = token;
		}

		if(steps)
		{
			var stepCount:Float = Std.parseFloat(duration);
			if(!Math.isNaN(stepCount)) duration = formatNumber(stepCount * stepSecondsAt(time));
		}

		var split:Array<String> = splitEase(easeName);
		return {mode: 'tween', duration: duration, ease: split[0], direction: split[1]};
	}

	static function splitEase(name:String):Array<String>
	{
		var lower:String = name.toLowerCase();
		var direction:String = 'InOut';
		if(lower.endsWith('inout')) lower = lower.substr(0, lower.length - 5);
		else if(lower.endsWith('in')) { lower = lower.substr(0, lower.length - 2); direction = 'In'; }
		else if(lower.endsWith('out')) { lower = lower.substr(0, lower.length - 3); direction = 'Out'; }

		for (ease in EASE_NAMES)
			if(ease.toLowerCase() == lower) return [ease, direction];
		return ['linear', 'InOut'];
	}

	static function legacyCharacter(value:String):String
	{
		var key:String = value.toLowerCase();
		switch(key)
		{
			case 'bf' | 'boyfriend': return 'BF';
			case 'gf' | 'girlfriend': return 'GF';
			case '' | 'dad' | 'opponent': return 'Dad';
		}
		var number:Float = Std.parseFloat(key);
		if(Math.isNaN(number)) return 'Dad';
		var rounded:Int = Math.round(number);
		if(rounded >= 3) return Std.string(rounded);
		return switch(rounded)
		{
			case 1: 'BF';
			case 2: 'GF';
			default: 'Dad';
		}
	}

	static function isCharacterToken(value:String):Bool
	{
		var key:String = value.toLowerCase();
		if(['bf', 'boyfriend', 'player', 'dad', 'opponent', 'gf', 'girlfriend'].contains(key)) return true;
		var parsed:Null<Int> = Std.parseInt(key);
		return parsed != null && Std.string(parsed) == key;
	}

	static function skinTarget(value:String):String
	{
		return switch(value.toLowerCase())
		{
			case 'bf': 'BF';
			case 'dad': 'Dad';
			default: 'Both';
		}
	}

	inline static function skinValue(value:String):String
		return (value.length > 0) ? value : 'default';

	static function formatNumber(value:Float):String
	{
		var rounded:Float = Math.round(value * 10000) / 10000;
		return Std.string(rounded);
	}
}
