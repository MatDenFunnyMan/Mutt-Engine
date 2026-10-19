package funkin.data;

import haxe.Json;

using StringTools;

typedef NotePackAnim = {
	?prefix:String,
	?indices:Array<Int>,
	?frames:Array<Int>,
	?fps:Null<Float>,
	?loop:Null<Bool>,
	?offsets:Array<Float>
}

typedef NotePackPart = {
	?image:String,
	?scale:Null<Float>,
	?antialiasing:Null<Bool>,
	?rgb:Null<Bool>,
	?grid:Array<Int>,
	?holdImage:String,
	?holdGrid:Array<Int>,
	?colors:Dynamic,
	?offsets:Array<Float>,
	?animations:Dynamic
}

typedef NotePackSide = {
	?strums:NotePackPart,
	?notes:NotePackPart,
	?splashes:NotePackPart,
	?holdCovers:NotePackPart
}

typedef NotePackPixel = {
	?player:NotePackSide,
	?opponent:NotePackSide
}

typedef NotePackTint = {
	?color:String,
	?strength:Null<Float>
}

typedef NotePackTints = {
	?player:NotePackTint,
	?opponent:NotePackTint
}

typedef NotePackFile = {
	?player:NotePackSide,
	?opponent:NotePackSide,
	?pixel:NotePackPixel,
	?tint:NotePackTints
}

class NotePackData
{
	public static final DIRECTIONS:Array<String> = ['left', 'down', 'up', 'right'];
	public static final PARTS:Array<String> = ['strums', 'notes', 'splashes', 'holdCovers'];
	public static final PART_ANIMS:Map<String, Array<String>> = [
		'strums' => ['static', 'pressed', 'confirm'],
		'notes' => ['note', 'hold', 'holdEnd'],
		'holdCovers' => ['hold', 'end']
	];
	public static final PREFIX_ALIASES:Map<String, Array<String>> = [
		'purple hold end' => ['pruple end hold']
	];

	static final COLORS:Array<String> = ['purple', 'blue', 'green', 'red'];
	static final STRUM_NAMES:Array<String> = ['arrowLEFT', 'arrowDOWN', 'arrowUP', 'arrowRIGHT'];

	public static function parse(raw:String):NotePackFile
	{
		if(raw == null || raw.trim().length < 1) throw 'empty file';
		var json:Dynamic = Json.parse(raw);
		if(json == null || Type.typeof(json) != TObject || Std.isOfType(json, Array)) throw 'the file is not a JSON object';
		return json;
	}

	public static function directionIndex(direction:String):Int
		return DIRECTIONS.indexOf(direction == null ? '' : direction.toLowerCase());

	public static function rawPart(file:NotePackFile, part:String, opponent:Bool, pixel:Bool):NotePackPart
	{
		if(file == null) return null;
		var player:NotePackSide = pixel ? (file.pixel != null ? file.pixel.player : null) : file.player;
		var other:NotePackSide = pixel ? (file.pixel != null ? file.pixel.opponent : null) : file.opponent;

		var found:NotePackPart = null;
		if(opponent && part != 'splashes') found = sidePart(other, part);
		if(found == null) found = sidePart(player, part);
		return found;
	}

	public static function resolvePart(file:NotePackFile, part:String, opponent:Bool, pixel:Bool):NotePackPart
	{
		var custom:NotePackPart = rawPart(file, part, opponent, pixel);
		if(custom == null) return null;
		return mergePart(defaultPart(part, pixel), custom, part);
	}

	public static function tint(file:NotePackFile, opponent:Bool):NotePackTint
	{
		if(file == null || file.tint == null) return null;
		var found:NotePackTint = opponent ? file.tint.opponent : file.tint.player;
		if(found == null && opponent) found = file.tint.player;
		if(found == null || found.color == null || found.color.trim().length < 1) return null;
		return {color: found.color.trim(), strength: (found.strength == null) ? 1 : Math.max(0, Math.min(1, found.strength))};
	}

	public static function anim(part:NotePackPart, direction:Int, name:String):NotePackAnim
	{
		var dir:Dynamic = directionAnims(part, direction);
		if(dir == null || Std.isOfType(dir, Array)) return null;
		return Reflect.field(dir, name);
	}

	public static function splashAnims(part:NotePackPart, direction:Int):Array<NotePackAnim>
	{
		var dir:Dynamic = directionAnims(part, direction);
		if(dir == null) return null;
		if(Std.isOfType(dir, Array)) return cast dir;
		return [dir];
	}

	public static function packColors(part:NotePackPart, direction:Int):Array<FlxColor>
	{
		if(part == null || part.colors == null) return null;
		var list:Array<Dynamic> = Reflect.field(part.colors, DIRECTIONS[direction % DIRECTIONS.length]);
		if(list == null || list.length < 3) return null;
		var result:Array<FlxColor> = [];
		for (i in 0...3)
		{
			var parsed:Null<FlxColor> = FlxColor.fromString('#' + Std.string(list[i]).replace('#', ''));
			if(parsed == null) return null;
			result.push(parsed);
		}
		return result;
	}

	public static function prefixCandidates(prefix:String):Array<String>
	{
		var list:Array<String> = [prefix];
		var aliases:Array<String> = PREFIX_ALIASES.get(prefix);
		if(aliases != null) for (alias in aliases) list.push(alias);
		return list;
	}

	public static function defaultPart(part:String, pixel:Bool):NotePackPart
	{
		return switch(part)
		{
			case 'strums': pixel ? pixelStrums() : normalStrums();
			case 'notes': pixel ? pixelNotes() : normalNotes();
			case 'splashes': {image: pixel ? 'pixelUI/pixelNoteSplash' : 'noteSplashes/noteSplashes'};
			case 'holdCovers': pixel ? pixelHoldCovers() : normalHoldCovers();
			default: null;
		}
	}

	public static function defaultFile():NotePackFile
	{
		var normal:NotePackSide = {};
		var pixel:NotePackSide = {};
		for (part in PARTS)
		{
			Reflect.setField(normal, part, defaultPart(part, false));
			Reflect.setField(pixel, part, defaultPart(part, true));
		}
		return {player: normal, pixel: {player: pixel}};
	}

	public static function mergePart(base:NotePackPart, custom:NotePackPart, part:String):NotePackPart
	{
		if(base == null) return copyPart(custom);
		if(custom == null) return copyPart(base);

		var result:NotePackPart = copyPart(base);
		for (field in ['image', 'scale', 'antialiasing', 'rgb', 'grid', 'holdImage', 'holdGrid', 'offsets', 'colors'])
		{
			var value:Dynamic = Reflect.field(custom, field);
			if(value != null) Reflect.setField(result, field, copyValue(value));
		}

		var ownImage:Bool = custom.image != null && custom.image != base.image;
		if(part == 'splashes' || (part == 'holdCovers' && ownImage && custom.animations == null))
		{
			result.animations = (custom.animations != null) ? copyValue(custom.animations) : (ownImage ? null : copyValue(base.animations));
			return result;
		}

		if(custom.animations == null) return result;
		var merged:Dynamic = {};
		for (index => direction in DIRECTIONS)
		{
			var baseDir:Dynamic = directionAnims(base, index);
			var customDir:Dynamic = directionAnims(custom, index);
			var names:Array<String> = PART_ANIMS.exists(part) ? PART_ANIMS.get(part).copy() : [];
			if(customDir != null && !Std.isOfType(customDir, Array))
				for (name in Reflect.fields(customDir)) if(!names.contains(name)) names.push(name);

			var dir:Dynamic = {};
			for (name in names)
			{
				var a:NotePackAnim = (baseDir != null && !Std.isOfType(baseDir, Array)) ? Reflect.field(baseDir, name) : null;
				var b:NotePackAnim = (customDir != null && !Std.isOfType(customDir, Array)) ? Reflect.field(customDir, name) : null;
				var anim:NotePackAnim = mergeAnim(a, b);
				if(anim != null) Reflect.setField(dir, name, anim);
			}
			Reflect.setField(merged, direction, dir);
		}
		result.animations = merged;
		return result;
	}

	public static function mergeAnim(base:NotePackAnim, custom:NotePackAnim):NotePackAnim
	{
		if(base == null && custom == null) return null;
		var result:NotePackAnim = (base != null) ? copyValue(base) : {};
		if(custom != null)
			for (field in Reflect.fields(custom))
			{
				var value:Dynamic = Reflect.field(custom, field);
				if(value != null) Reflect.setField(result, field, copyValue(value));
			}
		return result;
	}

	static function sidePart(side:NotePackSide, part:String):NotePackPart
		return (side == null) ? null : Reflect.field(side, part);

	static function directionAnims(part:NotePackPart, direction:Int):Dynamic
	{
		if(part == null || part.animations == null || direction < 0 || direction >= DIRECTIONS.length) return null;
		return Reflect.field(part.animations, DIRECTIONS[direction]);
	}

	static function copyPart(part:NotePackPart):NotePackPart
		return (part == null) ? null : copyValue(part);

	static function copyValue(value:Dynamic):Dynamic
	{
		if(value == null) return null;
		if(Std.isOfType(value, Array))
		{
			var list:Array<Dynamic> = cast value;
			return [for (item in list) copyValue(item)];
		}
		if(Type.typeof(value) == TObject)
		{
			var copy:Dynamic = {};
			for (field in Reflect.fields(value)) Reflect.setField(copy, field, copyValue(Reflect.field(value, field)));
			return copy;
		}
		return value;
	}

	static function perDirection(make:Int->Dynamic):Dynamic
	{
		var result:Dynamic = {};
		for (index => direction in DIRECTIONS) Reflect.setField(result, direction, make(index));
		return result;
	}

	static function normalStrums():NotePackPart
	{
		return {
			image: 'noteSkins/NOTE_assets',
			scale: 0.7,
			rgb: true,
			animations: perDirection(function(i:Int) return {
				'static': ({prefix: STRUM_NAMES[i], fps: 24, loop: true}:NotePackAnim),
				pressed: ({prefix: '${DIRECTIONS[i]} press', fps: 24, loop: false}:NotePackAnim),
				confirm: ({prefix: '${DIRECTIONS[i]} confirm', fps: 24, loop: false}:NotePackAnim)
			})
		};
	}

	static function pixelStrums():NotePackPart
	{
		return {
			image: 'pixelUI/noteSkins/NOTE_assets',
			grid: [4, 5],
			scale: 6,
			antialiasing: false,
			rgb: true,
			animations: perDirection(function(i:Int) return {
				'static': ({frames: [i], fps: 24, loop: true}:NotePackAnim),
				pressed: ({frames: [i + 4, i + 8], fps: 12, loop: false}:NotePackAnim),
				confirm: ({frames: [i + 12, i + 16], fps: (i == 2) ? 12 : 24, loop: false}:NotePackAnim)
			})
		};
	}

	static function normalNotes():NotePackPart
	{
		return {
			image: 'noteSkins/NOTE_assets',
			scale: 0.7,
			rgb: true,
			animations: perDirection(function(i:Int) return {
				note: ({prefix: '${COLORS[i]}0', fps: 24, loop: true}:NotePackAnim),
				hold: ({prefix: '${COLORS[i]} hold piece', fps: 24, loop: true}:NotePackAnim),
				holdEnd: ({prefix: '${COLORS[i]} hold end', fps: 24, loop: true}:NotePackAnim)
			})
		};
	}

	static function pixelNotes():NotePackPart
	{
		return {
			image: 'pixelUI/noteSkins/NOTE_assets',
			grid: [4, 5],
			holdImage: 'pixelUI/noteSkins/NOTE_assetsENDS',
			holdGrid: [4, 2],
			scale: 6,
			antialiasing: false,
			rgb: true,
			animations: perDirection(function(i:Int) return {
				note: ({frames: [i + 4], fps: 24, loop: true}:NotePackAnim),
				hold: ({frames: [i], fps: 24, loop: true}:NotePackAnim),
				holdEnd: ({frames: [i + 4], fps: 24, loop: true}:NotePackAnim)
			})
		};
	}

	static function normalHoldCovers():NotePackPart
	{
		return {
			image: 'holdCovers/holdCoverRGB',
			scale: 1,
			rgb: true,
			offsets: [-105, -100],
			animations: perDirection(function(i:Int) return {
				hold: ({prefix: 'holdCoverRGB', fps: 24, loop: true}:NotePackAnim),
				end: ({prefix: 'holdCoverEndRGB', fps: 24, loop: false}:NotePackAnim)
			})
		};
	}

	static function pixelHoldCovers():NotePackPart
	{
		return {
			image: 'pixelUI/pixelNoteHoldCover',
			scale: 6,
			antialiasing: false,
			rgb: true,
			offsets: [-385, -125],
			animations: perDirection(function(i:Int) return {
				hold: ({prefix: 'loop', fps: 24, loop: true}:NotePackAnim),
				end: ({prefix: 'explode', fps: 16, loop: false}:NotePackAnim)
			})
		};
	}
}
