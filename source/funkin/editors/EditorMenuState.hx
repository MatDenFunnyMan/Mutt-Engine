package funkin.editors;

import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import funkin.data.WeekData;
import funkin.editors.*;
import funkin.ui.Alphabet;
import funkin.ui.states.FreeplayState;
import funkin.ui.states.MainMenuState;

typedef EditorMenuOption = {
	var name:String;
	var state:Class<MusicBeatState>;
	var loading:Bool;
}

class EditorMenuState extends MusicBeatState
{
	public static var ITEM_SPACING:Float = 130;
	public static var ITEM_START_Y:Float = 120;

	public var options:Array<EditorMenuOption> = [
		{name: "Chart Editor", state: ChartingState, loading: true},
		{name: "Character Editor", state: CharacterEditorState, loading: true},
		{name: "Stage Editor", state: StageEditorState, loading: true},
		{name: "Week Editor", state: WeekEditorState, loading: false},
		{name: "Menu Character Editor", state: MenuCharacterEditorState, loading: false},
		{name: "Dialogue Editor", state: DialogueEditorState, loading: true},
		{name: "Dialogue Portrait Editor", state: DialogueCharacterEditorState, loading: true},
		{name: "Note Splash Editor", state: NoteSplashEditorState, loading: false},
		{name: "Hold Cover Editor", state: HoldCoverEditorState, loading: false}
		#if !DISABLE_MODCHART_EDITOR
		, {name: "Modchart Editor", state: modcharting.ModchartEditorState, loading: false}
		#end
	];

	var items:Array<Alphabet> = [];
	var camFocusPoint:FlxObject;
	var curSelected:Int = 0;
	var confirmed:Bool = false;

	#if MODS_ALLOWED
	var directories:Array<String> = [null];
	var curDirectory:Int = 0;
	var directoryTxt:FlxText;
	#end

	override function create()
	{
		initPsychCamera();
		FlxG.camera.bgColor = FlxColor.BLACK;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		menuBG.color = 0xFF4CAF50;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.scrollFactor.set(0, 0);
		menuBG.antialiasing = ClientPrefs.data.antialiasing;
		add(menuBG);

		camFocusPoint = new FlxObject(0, 0);
		add(camFocusPoint);
		FlxG.camera.follow(camFocusPoint, null, 0.06);

		for (i => option in options)
		{
			var item:Alphabet = new Alphabet(0, ITEM_START_Y + i * ITEM_SPACING, option.name, true);
			item.x = (FlxG.width - item.width) / 2;
			add(item);
			items.push(item);
		}

		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0xFF000000);
		textBG.alpha = 0.6;
		textBG.scrollFactor.set(0, 0);
		add(textBG);

		directoryTxt = new FlxText(0, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set(0, 0);
		add(directoryTxt);

		for (folder in Mods.getModDirectories())
			directories.push(folder);

		var found:Int = directories.indexOf(Mods.currentModDirectory);
		if (found > -1) curDirectory = found;
		changeDirectory();
		#end

		updateSelection();
		FlxG.camera.focusOn(FlxPoint.weak(camFocusPoint.x, camFocusPoint.y));

		FlxG.mouse.visible = false;
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (confirmed) return;

		var change:Int = 0;
		if (controls.UI_UP_P) change = -1;
		if (controls.UI_DOWN_P) change = 1;
		if (FlxG.mouse.wheel != 0) change = -FlxG.mouse.wheel;

		if (change != 0)
		{
			curSelected = FlxMath.wrap(curSelected + change, 0, items.length - 1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			updateSelection();
		}

		#if MODS_ALLOWED
		if (controls.UI_LEFT_P) changeDirectory(-1);
		if (controls.UI_RIGHT_P) changeDirectory(1);
		#end

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
			return;
		}

		if (controls.ACCEPT) accept();
	}

	function accept()
	{
		confirmed = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		var option:EditorMenuOption = options[curSelected];

		FlxFlicker.flicker(items[curSelected], 0.6, ClientPrefs.data.flashing ? 0.06 : 0.15, false, false, function(_)
		{
			EditorHelper.saveCurrentState();
			FreeplayState.destroyFreeplayVocals();

			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
				FlxG.sound.music.volume = 0;
			}

			var target:MusicBeatState = cast Type.createInstance(option.state, []);
			if (option.loading) LoadingState.loadAndSwitchState(target, false);
			else MusicBeatState.switchState(target);
		});
	}

	function updateSelection()
	{
		for (i => item in items)
			item.alpha = (i == curSelected) ? 1 : 0.6;

		var target:Alphabet = items[curSelected];
		camFocusPoint.setPosition(target.x + target.width / 2, target.y + target.height / 2);
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		if (change != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curDirectory = FlxMath.wrap(curDirectory + change, 0, directories.length - 1);

		WeekData.setDirectoryFromWeek();
		if (directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< No Mod Directory Loaded >';
		else
		{
			Mods.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ' + Mods.currentModDirectory + ' >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
	}
	#end
}