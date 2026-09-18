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
