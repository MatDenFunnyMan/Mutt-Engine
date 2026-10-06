package funkin.ui.options;

/*
	CUSTOM SETTINGS SUBSTATE - EXAMPLE / TEMPLATE

	This file is a template for making your own options category in source code.
	It is NOT shown in the Options menu by default: copy it, rename the class and edit the options.

	HOW TO SHOW IT IN THE OPTIONS MENU
	Open OptionsState.hx and:
	1) add your category name to the "options" array, for example 'Custom'
	2) add a case to the switch inside openSelectedSubstate():
		case 'Custom':
			SubStateManager.open(this, 'CustomSettingsSubState', () -> new funkin.ui.options.CustomSettingsSubState());

	WHERE THE VALUES ARE SAVED
	Every option reads and writes a variable. There are two ways to store it:

	A) ClientPrefs (the standard way, used by every official category)
		Add the variable to the SaveVariables class in funkin/save/ClientPrefs.hx, for example:
			public var myOption:Bool = false;
		Then create the Option with 'myOption' as the variable name and you're done.
		The value is saved automatically and you read it anywhere with ClientPrefs.data.myOption

	B) FlxG.save (the way this template works, so it runs without touching ClientPrefs)
		Pass the option to storeInSave() after setting its default value.
		You read the value anywhere with CustomSettingsSubState.get('variableName')

	NOT TO BE CONFUSED WITH ModSettingsSubState.hx
	That one is Psych's system for mods: it builds the options from a mod's data/settings.json
	and it's opened from the Mods menu. This file is for options written directly in the source code.
*/
class CustomSettingsSubState extends BaseOptionsMenu
{
	static inline final SAVE_PREFIX:String = 'customSettings_';

	public function new()
	{
		// Title shown on the top left, and the text shown on Discord while you're in this menu
		title = 'Custom Settings';
		rpcTitle = 'Custom Settings Menu';

		/*
			BOOL - a checkbox, ENTER toggles it
			new Option(name shown in the menu, description shown at the bottom, variable name, type)
		*/
		var option:Option = new Option('Example Bool',
			'A checkbox. Press ENTER to toggle it.',
			'exampleBool',
			BOOL);
		option.defaultValue = false;
		addOption(storeInSave(option));

		/*
			INT - a whole number, LEFT/RIGHT changes it (hold to scroll)
			minValue / maxValue = limits
			changeValue = how much a single press adds or removes
			scrollSpeed = how much it changes per second while holding LEFT/RIGHT
			displayFormat = how the value is shown, %v is the current value and %d the default value
		*/
		var option:Option = new Option('Example Int',
			'A whole number. Use LEFT and RIGHT, hold to scroll faster.',
			'exampleInt',
			INT);
		option.defaultValue = 5;
		option.minValue = 0;
		option.maxValue = 10;
		option.changeValue = 1;
		option.scrollSpeed = 10;
		option.displayFormat = '%v times';
		addOption(storeInSave(option));

		/*
			FLOAT - a number with decimals, works like INT
			decimals = how many decimal digits are kept
		*/
		var option:Option = new Option('Example Float',
			'A number with decimals.',
			'exampleFloat',
			FLOAT);
		option.defaultValue = 1.5;
		option.minValue = 0.5;
		option.maxValue = 3;
		option.changeValue = 0.1;
		option.scrollSpeed = 1;
		option.decimals = 1;
		option.displayFormat = '%vx';
		addOption(storeInSave(option));

		/*
			PERCENT - a value from 0 to 1 shown as 0% to 100%
			By default it already has min 0, max 1, step 0.01 and 2 decimals, you can change them like here.
			onChange = a function called every time the value changes
		*/
		var option:Option = new Option('Example Percent',
			'A percentage. It plays a sound at the chosen volume.',
			'examplePercent',
			PERCENT);
		option.defaultValue = 0.5;
		option.changeValue = 0.1;
		option.scrollSpeed = 1.6;
		option.decimals = 1;
		option.onChange = onChangeExamplePercent;
		addOption(storeInSave(option));

		/*
			STRING - a list of choices, LEFT/RIGHT cycles through them
			The 5th argument is the list. The saved value is the chosen text itself.
		*/
		var option:Option = new Option('Example String',
			'A list of choices. Use LEFT and RIGHT to cycle them.',
			'exampleString',
			STRING,
			['First', 'Second', 'Third']);
		option.defaultValue = 'First';
		addOption(storeInSave(option));

		/*
			KEYBIND - a key the player can rebind, ENTER starts the rebinding
			defaultKeys = the default key for keyboard and for gamepad, written as FlxKey / FlxGamepadInputID names
			Read it with CustomSettingsSubState.get('exampleKeybind').keyboard (or .gamepad)
			and convert it with FlxKey.fromString()
		*/
		var option:Option = new Option('Example Keybind',
			'A key you can rebind. Press ENTER, then the new key.',
			'exampleKeybind',
			KEYBIND);
		option.defaultKeys.keyboard = 'F';
		option.defaultKeys.gamepad = 'X';
		addOption(storeInSave(option));

		/*
			BUTTON - no value, ENTER runs onChange
			Useful to open another menu, like "Open Note Color Editor" in the Notes category.
			The variable name is not used, so it's null.
		*/
		var option:Option = new Option('Example Button',
			'Press ENTER to open the Note Color Editor.',
			null,
			BUTTON);
		option.onChange = () -> SubStateManager.open(this, 'NotesColorSubState', () -> new NotesColorSubState());
		addOption(option);

		// Always call super() AFTER adding all the options, it's the one that builds the menu
		super();
	}

	function onChangeExamplePercent()
		FlxG.sound.play(Paths.sound('scrollMenu'), get('examplePercent'));

	/*
		Reads a value saved by storeInSave() from anywhere in the game, for example:
			if(CustomSettingsSubState.get('exampleBool') == true) ...
	*/
	public static function get(variable:String):Dynamic
		return Reflect.field(FlxG.save.data, SAVE_PREFIX + variable);

	/*
		Makes an option read and write its value in FlxG.save instead of ClientPrefs.
		Set defaultValue (or defaultKeys for KEYBIND) BEFORE calling this.
		The save is written to disk when you leave the Options menu.
	*/
	function storeInSave(option:Option):Option
	{
		var key:String = SAVE_PREFIX + option.variable;
		if(option.type == KEYBIND)
		{
			var saved:Dynamic = Reflect.field(FlxG.save.data, key);
			if(saved == null)
			{
				saved = {keyboard: option.defaultKeys.keyboard, gamepad: option.defaultKeys.gamepad};
				Reflect.setField(FlxG.save.data, key, saved);
			}
			option.keys.keyboard = saved.keyboard;
			option.keys.gamepad = saved.gamepad;
			option.getValue = function():Dynamic
			{
				var data:Dynamic = Reflect.field(FlxG.save.data, key);
				return !Controls.instance.controllerMode ? data.keyboard : data.gamepad;
			};
			option.setValue = function(value:Dynamic):Dynamic
			{
				var data:Dynamic = Reflect.field(FlxG.save.data, key);
				if(!Controls.instance.controllerMode) data.keyboard = value;
				else data.gamepad = value;
				return value;
			};
			return option;
		}

		if(Reflect.field(FlxG.save.data, key) == null) Reflect.setField(FlxG.save.data, key, option.defaultValue);
		option.getValue = function():Dynamic return Reflect.field(FlxG.save.data, key);
		option.setValue = function(value:Dynamic):Dynamic
		{
			Reflect.setField(FlxG.save.data, key, value);
			return value;
		};
		if(option.type == STRING) option.curOption = Std.int(Math.max(0, option.options.indexOf(option.getValue())));
		return option;
	}
}
