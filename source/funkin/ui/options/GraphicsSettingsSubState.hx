package funkin.ui.options;

import funkin.game.Character;
import funkin.backend.DisplaySettings;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	public function new()
	{
		title = Language.getPhrase('graphics_menu', 'Graphics Settings');
		rpcTitle = 'Graphics Settings Menu'; //for Discord Rich Presence

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.animation.finishCallback = function (name:String) boyfriend.dance();
		boyfriend.visible = false;

		#if !html5 //Apparently other framerates isn't correctly supported on Browser? Probably it has some V-Sync shit enabled by default, idk
		var option:Option = new Option('Framerate',
			"Pretty self explanatory, isn't it?",
			'framerate',
			INT);
		addOption(option);

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
		option.minValue = 60;
		option.maxValue = 240;
		option.defaultValue = Std.int(FlxMath.bound(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		#end

		#if (cpp && windows)
		var option:Option = new Option('V-Sync',
			"If checked, the framerate is synced with your monitor's refresh rate,\nremoving screen tearing.",
			'vsync',
			BOOL);
		option.onChange = onChangeVSync;
		addOption(option);
		#end

		#if !html5
		var option:Option = new Option('Unlocked Framerate',
			"If checked, the game runs as fast as it can,\nignoring the Framerate option.",
			'unlockedFramerate',
			BOOL);
		option.onChange = onChangeFramerate;
		addOption(option);

		var option:Option = new Option('Resolution',
			"Fullscreen = the game takes the whole screen.\nBorderless = a window without borders as big as the screen.\nWindowed = a normal window.",
			'resolution',
			STRING,
			DisplaySettings.RESOLUTIONS);
		option.defaultValue = 'Windowed';
		option.onChange = onChangeResolution;
		addOption(option);
		#end

		//I'd suggest using "Low Quality" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Low Quality', //Name
			'If checked, disables some background details,\ndecreases loading times and improves performance.', //Description
			'lowQuality', //Save data variable name
			BOOL); //Variable type
		addOption(option);

		var option:Option = new Option('Anti-aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing; //Changing onChange is only needed if you want to make a special interaction after it changes the value
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		var option:Option = new Option('Shaders', //Name
			"If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker PCs.", //Description
			'shaders',
			BOOL);
		addOption(option);

		var option:Option = new Option('GPU Caching',
			"If checked, images are stored in video memory instead of RAM,\nlowering memory usage. Applies to newly loaded images.",
			'cacheOnGPU',
			BOOL);
		addOption(option);

		super();
		insert(1, boyfriend);
	}

	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeFramerate()
		DisplaySettings.applyFramerate();

	function onChangeVSync()
		DisplaySettings.applyVSync();

	function onChangeResolution()
		DisplaySettings.applyResolution();

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}