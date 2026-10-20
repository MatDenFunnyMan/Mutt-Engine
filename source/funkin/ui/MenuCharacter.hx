package funkin.ui;

import openfl.utils.Assets;
import haxe.Json;

typedef MenuCharacterFile = {
	var image:String;
	var scale:Float;
	var position:Array<Int>;
	var idle_anim:String;
	var confirm_anim:String;
	var flipX:Bool;
	var antialiasing:Null<Bool>;
}

class MenuCharacter extends FlxSprite
{
	public var character:String;
	public var hasConfirmAnimation:Bool = false;
	private static var DEFAULT_CHARACTER:String = 'bf';

	public function new(x:Float, character:String = 'bf')
	{
		super(x);

		changeCharacter(character);
	}

	public function changeCharacter(?character:String = 'bf') {
		if(character == null) character = '';
		if(character == this.character) return;

		this.character = character;
		visible = true;

		var dontPlayAnim:Bool = false;
		scale.set(1, 1);
		updateHitbox();
		
		color = FlxColor.WHITE;
		alpha = 1;

		hasConfirmAnimation = false;
		switch(character) {
			case '':
				visible = false;
				dontPlayAnim = true;
			default:
				var path:String = filePath(character);
				if (path == null)
				{
					path = Paths.getRoutedSharedPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
					color = FlxColor.BLACK;
					alpha = 0.6;
				}

				var charFile:MenuCharacterFile = parseFile(path);
				if(charFile == null) trace('Error loading menu character file of "$character"');
				else applyFile(charFile);
		}
	}

	public static function filePath(character:String):String
	{
		var path:String = Paths.getPath('images/menucharacters/' + character + '.json', TEXT);
		#if MODS_ALLOWED
		return FileSystem.exists(path) ? path : null;
		#else
		return Assets.exists(path) ? path : null;
		#end
	}

	public static function parseFile(path:String):MenuCharacterFile
	{
		if(path == null) return null;
		try
		{
			#if MODS_ALLOWED
			return cast Json.parse(File.getContent(path));
			#else
			return cast Json.parse(Assets.getText(path));
			#end
		}
		catch(e:Dynamic) {}
		return null;
	}

	public function applyFile(charFile:MenuCharacterFile)
	{
		hasConfirmAnimation = false;
		scale.set(1, 1);
		var image:String = 'menucharacters/' + charFile.image;
		if(charFile.image == null || charFile.image.length < 1 || !Paths.fileExists('images/' + image + '.png', IMAGE))
		{
			visible = false;
			return;
		}
		visible = true;
		frames = Paths.getSparrowAtlas(image);
		animation.addByPrefix('idle', charFile.idle_anim, 24);

		var confirmAnim:String = charFile.confirm_anim;
		if(confirmAnim != null && confirmAnim.length > 0 && confirmAnim != charFile.idle_anim)
		{
			animation.addByPrefix('confirm', confirmAnim, 24, false);
			if (animation.getByName('confirm') != null)
				hasConfirmAnimation = true;
		}
		flipX = (charFile.flipX == true);

		scale.set(charFile.scale, charFile.scale);
		updateHitbox();
		offset.set(charFile.position[0], charFile.position[1]);
		animation.play('idle');

		antialiasing = (charFile.antialiasing != false && ClientPrefs.data.antialiasing);
	}
}
