package funkin.ui.options;

import funkin.ui.states.MainMenuState;
import funkin.data.StageData;
import funkin.backend.StateManager;
import flixel.FlxObject;

class OptionsState extends MusicBeatState
{
	var options:Array<String> = [
		'Preferences',
		'Notes',
		'Controls',
		'Lag Adjustment',
		'Graphics',
		'Gameplay',
		'Debug'
	];
	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	private static var curSelectedPartial:Float = 0;
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	var exiting:Bool = false;

	private var mainCam:FlxCamera;
	public static var funnyCam:FlxCamera;
	private var camFollow:FlxObject;
	private var camFollowPos:FlxObject;

	function openSelectedSubstate(label:String) {
		funnyCam.visible = persistentUpdate = false;

		switch(label)
		{
			case 'Preferences':
				SubStateManager.open(this, 'PreferencesSettingsSubState', () -> new funkin.ui.options.PreferencesSettingsSubState());
			case 'Notes':
				SubStateManager.open(this, 'NotesSettingsSubState', () -> new funkin.ui.options.NotesSettingsSubState());
			case 'Controls':
				SubStateManager.open(this, 'ControlsSubState', () -> new funkin.ui.options.ControlsSubState());
			case 'Lag Adjustment':
				SubStateManager.open(this, 'LagAdjustmentSubState', () -> new funkin.ui.options.LagAdjustmentSubState());
			case 'Graphics':
				SubStateManager.open(this, 'GraphicsSettingsSubState', () -> new funkin.ui.options.GraphicsSettingsSubState());
			case 'Gameplay':
				SubStateManager.open(this, 'GameplaySettingsSubState', () -> new funkin.ui.options.GameplaySettingsSubState());
			case 'Debug':
				SubStateManager.open(this, 'DebugSettingsSubState', () -> new funkin.ui.options.DebugSettingsSubState());
		}
	}

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;
	var flickering:Bool = false;

	static inline final FLICKER_TIME:Float = 1;
	static inline final FLICKER_INTERVAL:Float = 0.06;
	static final FLICKER_OPTIONS:Array<String> = ['Lag Adjustment'];

	override function create()
	{
		mainCam = initPsychCamera();
		funnyCam = new FlxCamera();
		funnyCam.bgColor.alpha = 0;
		FlxG.cameras.add(funnyCam, false);

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);
		FlxG.cameras.list[FlxG.cameras.list.indexOf(funnyCam)].follow(camFollowPos);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();

		bg.screenCenter();
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (num => option in options)
		{
			var optionText:Alphabet = new Alphabet(0, 0, Language.getPhrase('options_$option', option), true);
			optionText.screenCenter();
			optionText.y += (92 * (num - (options.length / 2))) + 45;
			optionText.cameras = [funnyCam];
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		selectorLeft.cameras = [funnyCam];
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		selectorRight.cameras = [funnyCam];
		add(selectorRight);

		changeSelection(0);
		ClientPrefs.saveSettings();

		super.create();
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
		persistentUpdate = funnyCam.visible = true;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		if(exiting || flickering) return;

		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);

		var lerpVal:Float = Math.max(0, Math.min(1, elapsed * 7.5));
		camFollowPos.setPosition(635, FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			exiting = true;
			if(onPlayState)
			{
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(new PlayState());
				FlxG.sound.music.volume = 0;
			}
			else StateManager.switchState('MainMenuState');
		}
		else if (controls.ACCEPT) selectOption(options[curSelected]);
	}
	
	function selectOption(label:String)
	{
		if(!FLICKER_OPTIONS.contains(label))
		{
			openSelectedSubstate(label);
			return;
		}

		flickering = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		flixel.effects.FlxFlicker.flicker(grpOptions.members[curSelected], FLICKER_TIME, FLICKER_INTERVAL, true, false, (_) -> {
			flickering = false;
			openSelectedSubstate(label);
		});
	}

	function changeSelection(change:Int = 0)
	{
		if(change != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		curSelectedPartial = curSelected;

		for (num => item in grpOptions.members)
		{
			item.targetY = Std.int(num - curSelectedPartial);
			item.alpha = 0.6;
			if (num == curSelected)
			{
				item.alpha = 1;
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;
				var thing:Float = grpOptions.members.length > 6 ? grpOptions.members.length * 2 : 0;
				camFollow.setPosition(635, item.y + 100 - thing);
			}
		}
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}