package funkin.debug;

#if MEMTEST
import funkin.game.Character;
import lime.graphics.Image;
import lime.graphics.ImageFileFormat;
import sys.io.File;
import sys.io.FileOutput;
import sys.FileSystem;

class CharAlign extends flixel.FlxState
{
	var names:Array<String>;
	var isPlayer:Bool;
	var zoom:Float;
	var anims:Array<String>;
	var chars:Array<Character> = [];
	var step:Int = 0;
	var wait:Int = 0;
	var capturePending:Bool = false;
	var output:FileOutput;

	public static function start():Bool
	{
		var args:Array<String> = Sys.args();
		var index:Int = args.indexOf('--charalign');
		if(index < 0 || args.length < index + 5) return false;

		FlxG.switchState(new CharAlign(args[index + 1].split(','), args[index + 2] == '1', Std.parseFloat(args[index + 3]), args[index + 4].split(',')));
		return true;
	}

	public function new(names:Array<String>, isPlayer:Bool, zoom:Float, anims:Array<String>)
	{
		super();
		this.names = names;
		this.isPlayer = isPlayer;
		this.zoom = zoom;
		this.anims = anims;
	}

	override function create()
	{
		super.create();
		FlxG.updateFramerate = FlxG.drawFramerate = 60;
		FlxG.camera.bgColor = 0xFFFF00FF;
		FlxG.camera.zoom = zoom;
		if(!FileSystem.exists('charalign')) FileSystem.createDirectory('charalign');
		output = File.write('charalign/log.txt', false);

		for (name in names)
		{
			var char:Character = new Character(0, 0, name, isPlayer);
			char.x += char.positionArray[0];
			char.y += char.positionArray[1];
			char.debugMode = true;
			char.visible = false;
			add(char);
			chars.push(char);
			output.writeString('char $name atlas ${char.isAnimateAtlas} pos ${char.x} ${char.y} size ${char.width} ${char.height} frame ${char.frameWidth} ${char.frameHeight} midpoint ${char.getMidpoint().x} ${char.getMidpoint().y}\n');
		}
		if(Sys.args().contains('--ghosttest'))
		{
			var ghost:animate.FlxAnimate = new animate.FlxAnimate();
			ghost.frames = Paths.getModernAtlasFrames(chars[0].imageFile);
			add(ghost);
			remove(ghost, true);
			ghost.destroy();
			output.writeString('ghost created and destroyed
');
		}
		FlxG.camera.focusOn(chars[0].getMidpoint());
		output.writeString('camera ${FlxG.camera.scroll.x} ${FlxG.camera.scroll.y} zoom $zoom\n');
		lime.app.Application.current.window.onRender.add(onRender, false, -1000);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(capturePending) return;

		if(step >= anims.length * chars.length)
		{
			output.close();
			Sys.exit(0);
			return;
		}

		if(wait == 0)
		{
			var anim:String = anims[Std.int(step / chars.length)];
			var current:Character = chars[step % chars.length];
			for (char in chars) char.visible = (char == current);
			current.playAnim(anim, true);
			current.animPaused = true;
			if(current.isAnimateAtlas)
				output.writeString('debug ${current.curCharacter} $anim labels ${funkin.util.AtlasUtil.getFrameLabelNames(current.atlas)} main ${funkin.util.AtlasUtil.mainSymbol(current.atlas) != null} inst ${current.atlas.anim.curInstance != null} sym ${current.atlas.anim.curSymbol != null ? current.atlas.anim.curSymbol.name : null} len ${current.atlas.anim.length} vis ${current.atlas.visible} alpha ${current.atlas.alpha}
');
			wait = 4;
		}
		else
		{
			wait--;
			if(wait == 0) capturePending = true;
		}
	}

	function onRender(_)
	{
		if(!capturePending) return;
		capturePending = false;

		var anim:String = anims[Std.int(step / chars.length)];
		var name:String = names[step % chars.length];
		var image:Image = lime.app.Application.current.window.readPixels();
		if(image != null)
		{
			File.saveBytes('charalign/${name}__${anim}.png', image.encode(ImageFileFormat.PNG));
			output.writeString('capture $name $anim ${image.width} ${image.height}\n');
		}
		step++;
	}
}
#end
