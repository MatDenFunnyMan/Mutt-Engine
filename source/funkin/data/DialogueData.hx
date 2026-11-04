package funkin.data;

import haxe.Json;

typedef DialogueAnimation = {
	var name:String;
	var prefix:String;
	@:optional var fps:Null<Float>;
	@:optional var loop:Null<Bool>;
	@:optional var offsets:Array<Float>;
}

typedef DialogueCharacterData = {
	var name:String;
	var portrait:String;
	@:optional var scale:Array<Float>;
	@:optional var position:Array<Float>;
	@:optional var flipX:Null<Bool>;
	@:optional var boxColor:String;
	@:optional var nameColor:String;
	@:optional var nametagWidth:Null<Float>;
	@:optional var nametagPosition:Array<Float>;
	@:optional var namePosition:Array<Float>;
	@:optional var textSize:Null<Int>;
	@:optional var font:String;
	@:optional var voice:String;
	@:optional var voiceStep:Null<Int>;
	@:optional var voicePitch:Null<Float>;
	@:optional var animations:Array<DialogueAnimation>;
}

typedef DialogueBackground = {
	var id:String;
	@:optional var image:String;
	@:optional var color:String;
	@:optional var alpha:Null<Float>;
	@:optional var center:Null<Bool>;
}

typedef DialogueStyleData = {
	@:optional var box:String;
	@:optional var overlay:String;
	@:optional var boxX:Null<Float>;
	@:optional var boxY:Null<Float>;
	@:optional var nametagColor:String;
	@:optional var borderSize:Null<Float>;
	@:optional var borderColor:String;
	@:optional var nameFont:String;
	@:optional var nameSize:Null<Int>;
	@:optional var font:String;
	@:optional var textSize:Null<Int>;
	@:optional var singleTextSize:Null<Int>;
	@:optional var textOffset:Array<Float>;
	@:optional var textWidth:Null<Int>;
	@:optional var speed:Null<Float>;
	@:optional var minVoiceGap:Null<Float>;
	@:optional var voiceVolume:Null<Float>;
	@:optional var hint:String;
	@:optional var hintFont:String;
	@:optional var hintSize:Null<Int>;
	@:optional var hintOffset:Array<Float>;
	@:optional var skipHint:String;
	@:optional var skipHintFont:String;
	@:optional var skipHintSize:Null<Int>;
	@:optional var skipHintPosition:Array<Float>;
	@:optional var skipKey:String;
	@:optional var backgrounds:Array<DialogueBackground>;
}

typedef DialogueAudio = {
	@:optional var name:String;
	@:optional var volume:Null<Float>;
	@:optional var fade:String;
	@:optional var fadeTime:Null<Float>;
	@:optional var pitch:Null<Float>;
	@:optional var delay:Null<Float>;
	@:optional var life:Null<Float>;
}

typedef DialogueScene = {
	var scene:String;
	@:optional var character:String;
	@:optional var portrait:String;
	@:optional var text:String;
	@:optional var speed:Null<Float>;
	@:optional var font:String;
	@:optional var size:Null<Int>;
	@:optional var voicePitch:Null<Float>;
	@:optional var voiceStep:Null<Int>;
	@:optional var skipDialog:Dynamic;
	@:optional var fx:Dynamic;
	@:optional var track:DialogueAudio;
	@:optional var sfx:DialogueAudio;
	@:optional var target:Dynamic;
	@:optional var alpha:Null<Float>;
	@:optional var duration:Null<Float>;
	@:optional var keepText:Null<Bool>;
	@:optional var custom:String;
	@:optional var fade:Null<Bool>;
}

typedef DialogueFileData = {
	@:optional var style:String;
	@:optional var music:String;
	@:optional var antialiasing:Null<Bool>;
	@:optional var backgrounds:Array<DialogueBackground>;
	var scenes:Array<DialogueScene>;
}

class DialogueData
{
	public static inline final CHARACTER_FOLDER:String = 'dialogue/characters/';
	public static inline final STYLE_FOLDER:String = 'dialogue/styles/';
	public static inline final DEFAULT_STYLE:String = 'default';
	public static final SCENE_TYPES:Array<String> = ['normal', 'single', 'wait', 'fade', 'free', 'ending'];
	public static final FX_TYPES:Array<String> = ['shake', 'flash', 'textShake'];
	public static var characterOverrides:Map<String, DialogueCharacterData> = [];
	public static var styleOverrides:Map<String, DialogueStyleData> = [];

	public static function readJson(key:String):Dynamic
	{
		var path:String = Paths.json(key);
		#if sys
		if(!FileSystem.exists(path)) return null;
		#else
		if(!openfl.utils.Assets.exists(path, TEXT)) return null;
		#end
		try
		{
			return Json.parse(Paths.getTextFromFile('data/$key.json'));
		}
		catch(e:Dynamic)
		{
			trace('Dialogue: could not read $key.json: $e');
		}
		return null;
	}

	public static function songDialogue(song:String, name:String):DialogueFileData
	{
		var folder:String = Paths.formatToSongPath(song);
		var data:Dynamic = null;
		#if TRANSLATIONS_ALLOWED
		data = readJson('songs/$folder/${name}_${ClientPrefs.data.language}');
		#end
		if(data == null) data = readJson('songs/$folder/$name');
		if(data == null) data = readJson(name);
		return validFile(data) ? data : null;
	}

	public static function validFile(data:Dynamic):Bool
		return data != null && Std.isOfType(data.scenes, Array) && (data.scenes:Array<Dynamic>).length > 0;

	public static function character(id:String):DialogueCharacterData
	{
		if(id == null || id.length < 1) return null;
		if(characterOverrides.exists(id)) return characterOverrides.get(id);
		var data:Dynamic = readJson(CHARACTER_FOLDER + id);
		return (data != null && data.portrait != null) ? data : null;
	}

	public static function style(?name:String):DialogueStyleData
	{
		var key:String = (name != null && name.length > 0) ? name : DEFAULT_STYLE;
		if(styleOverrides.exists(key)) return styleOverrides.get(key);
		var data:Dynamic = readJson(STYLE_FOLDER + key);
		return (data != null) ? data : {};
	}

	public static function defaultCharacter(id:String):DialogueCharacterData
	{
		return {
			name: id.toUpperCase(),
			portrait: 'dialogue/$id',
			scale: [1, 1],
			position: [0, 0],
			flipX: false,
			boxColor: 'FFFFFF',
			nameColor: 'FFFFFF',
			nametagWidth: 300,
			nametagPosition: [50, -80],
			namePosition: [70, -75],
			voice: '',
			voiceStep: 1,
			voicePitch: 1,
			animations: [{name: 'neutral', prefix: '', fps: 24, loop: false, offsets: [0, 0]}]
		};
	}
}
