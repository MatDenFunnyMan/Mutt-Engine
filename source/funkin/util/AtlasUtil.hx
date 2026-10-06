package funkin.util;

#if flxanimate
import flxanimate.animate.FlxSymbol;
import flxanimate.animate.FlxKeyFrame;

class AtlasUtil
{
	public static function mainSymbol(atlas:FlxAnimate):FlxSymbol
	{
		if(atlas == null || atlas.anim == null || atlas.anim.stageInstance == null || atlas.anim.symbolDictionary == null) return null;
		return atlas.anim.symbolDictionary.get(atlas.anim.stageInstance.symbol.name);
	}

	public static function getFrameLabel(atlas:FlxAnimate, name:String):FlxKeyFrame
	{
		var main:FlxSymbol = mainSymbol(atlas);
		if(main == null || name == null || name.length < 1) return null;

		for (label in main.getFrameLabels())
			if(label != null && label.name == name)
				return label;
		return null;
	}

	public static function getFrameLabelNames(atlas:FlxAnimate):Array<String>
	{
		var result:Array<String> = [];
		var main:FlxSymbol = mainSymbol(atlas);
		if(main == null) return result;

		for (label in main.getFrameLabels())
			if(label != null && label.name != null && !result.contains(label.name))
				result.push(label.name);
		return result;
	}

	public static function getSymbolNames(atlas:FlxAnimate, ?exclude:Array<String>):Array<String>
	{
		var result:Array<String> = [];
		if(atlas == null || atlas.anim == null || atlas.anim.symbolDictionary == null) return result;

		for (name in atlas.anim.symbolDictionary.keys())
			if(exclude == null || !exclude.contains(name))
				result.push(name);
		return result;
	}

	public static function addAnimation(atlas:FlxAnimate, anim:String, name:String, indices:Array<Int>, fps:Float, loop:Bool)
	{
		if(atlas == null || atlas.anim == null) return;

		var hasIndices:Bool = (indices != null && indices.length > 0);
		var label:FlxKeyFrame = getFrameLabel(atlas, name);
		if(label != null)
		{
			var frames:Array<Int> = hasIndices ? [for (i in indices) label.index + i] : label.getFrameIndices();
			atlas.anim.addBySymbolIndices(anim, mainSymbol(atlas).name, frames, fps, loop);
			return;
		}

		if(hasIndices)
			atlas.anim.addBySymbolIndices(anim, name, indices, fps, loop);
		else
			atlas.anim.addBySymbol(anim, name, fps, loop);
	}
}
#end

class ModernAtlasUtil
{
	public static function addAnimation(sprite:animate.FlxAnimate, anim:String, name:String, indices:Array<Int>, fps:Float, loop:Bool)
	{
		if(sprite == null || sprite.anim == null) return;

		var hasIndices:Bool = (indices != null && indices.length > 0);
		if(sprite.library != null && hasFrameLabel(sprite.library, name))
		{
			if(hasIndices) sprite.anim.addByFrameLabelIndices(anim, name, indices, fps, loop);
			else sprite.anim.addByFrameLabel(anim, name, fps, loop);
		}
		else if(sprite.library != null && sprite.library.existsSymbol(name))
		{
			if(hasIndices) sprite.anim.addBySymbolIndices(anim, name, indices, fps, loop);
			else sprite.anim.addBySymbol(anim, name, fps, loop);
		}
		else if(hasIndices)
			sprite.animation.addByIndices(anim, name, indices, '', fps, loop);
		else
			sprite.animation.addByPrefix(anim, name, fps, loop);
	}

	@:access(animate.FlxAnimateFrames)
	public static function getFrameLabelNames(library:animate.FlxAnimateFrames):Array<String>
	{
		var result:Array<String> = [];
		var timelines:Array<animate.internal.Timeline> = [library.timeline];
		if(library.addedCollections != null)
			for (collection in library.addedCollections) timelines.push(collection.timeline);

		for (timeline in timelines)
		{
			if(timeline == null) continue;
			for (layer in timeline.layers)
				for (frame in layer.frames)
					if(frame != null && frame.name != null && frame.name.rtrim().length > 0 && !result.contains(frame.name.rtrim()))
						result.push(frame.name.rtrim());
		}
		return result;
	}

	@:access(animate.FlxAnimateFrames)
	public static function getSymbolNames(library:animate.FlxAnimateFrames, ?exclude:Array<String>):Array<String>
	{
		var result:Array<String> = [];
		var libraries:Array<animate.FlxAnimateFrames> = [library];
		if(library.addedCollections != null)
			for (collection in library.addedCollections) libraries.push(collection);

		for (item in libraries)
		{
			if(item._symbolDictionary == null) continue;
			for (symbol in item._symbolDictionary)
				if(symbol != null && symbol.SN != null && !result.contains(symbol.SN) && (exclude == null || !exclude.contains(symbol.SN)))
					result.push(symbol.SN);
		}
		return result;
	}

	@:access(animate.FlxAnimateFrames)
	public static function hasFrameLabel(library:animate.FlxAnimateFrames, name:String):Bool
	{
		if(library.timeline != null && library.timeline.findFrameLabelIndices(name).length > 0) return true;
		if(library.addedCollections != null)
			for (collection in library.addedCollections)
				if(collection.timeline != null && collection.timeline.findFrameLabelIndices(name).length > 0)
					return true;
		return false;
	}
}
