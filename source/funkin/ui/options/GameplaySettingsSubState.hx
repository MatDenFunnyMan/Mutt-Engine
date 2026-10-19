package funkin.ui.options;

import funkin.game.InputSystem;

class GameplaySettingsSubState extends BaseOptionsMenu
{
	static final INPUT_DESCRIPTIONS:Map<String, String> = [
		InputSystem.PSYCH => "Psych Engine's input system.\nSustains as One Note automatically enabled and always on,\nusing a more 'modern' input.",
		InputSystem.VSLICE => "Funkin's input system.\nBAD & SHIT break combo, Ghost Tapping force disabled,\nSafe Frames locked to 9.6.",
		InputSystem.LEGACY => "'Old' Psych input system.\nSustains as One Note disabled and always off, Max Safe Frames are 9."
	];

	var inputOption:Option;
	var safeFramesOption:Option;

	public function new()
	{
		title = Language.getPhrase('gameplay_menu', 'Gameplay Settings');
		rpcTitle = 'Gameplay Settings Menu'; //for Discord Rich Presence

		//I'd suggest using "Downscroll" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Downscroll', //Name
			"If checked, notes go Down instead of Up, simple enough.\nI FUCKING HATE YOU DOWNSCROLL PLAYERS (kidding, i luv yall :>)", //Description
			'downScroll', //Save data variable name
			BOOL); //Variable type
		addOption(option);

		var option:Option = new Option('Middlescroll',
			"If checked, player notes stay centered.\nDisable this option for mods, please. It stinks :(",
			'middleScroll',
			BOOL);
		addOption(option);

		var option:Option = new Option('Opponent Notes',
			"If unchecked, opponent notes get hidden.\nI don't have anything w this one so uhh... pee pee poo poo",
			'opponentStrums',
			BOOL);
		addOption(option);

		var option:Option = new Option('Ghost Tapping',
			"If checked, misses are disabled on free input\n(aka. when there are no notes to hit)\nDisabled if 'V-Slice' input system is on, cause fuck you :)",
			'ghostTapping',
			BOOL);
		option.getValue = () -> InputSystem.ghostTapping();
		option.locked = InputSystem.ghostTappingLocked;
		option.lockedReason = Language.getPhrase('locked_by_vslice_ghost', 'Always off with the V-Slice Input System.');
		addOption(option);

		var option:Option = new Option('No Reset',
			"If checked, pressing Reset won't do anything.",
			'noReset',
			BOOL);
		addOption(option);

		var option:Option = new Option('Input System',
			inputDescription(),
			'inputSystem',
			STRING,
			InputSystem.LIST);
		option.onChange = onChangeInputSystem;
		inputOption = addOption(option);

		var option:Option = new Option('Safe Frames',
			'Changes how many frames you have for\nhitting a note earlier or late.',
			'safeFrames',
			FLOAT);
		option.scrollSpeed = 5;
		option.minValue = 2;
		option.maxValue = InputSystem.maxSafeFrames();
		option.changeValue = 0.1;
		option.getValue = () -> InputSystem.safeFrames();
		option.locked = InputSystem.safeFramesLocked;
		option.lockedReason = Language.getPhrase('locked_by_vslice_frames', 'Always 9.6 with the V-Slice Input System.');
		safeFramesOption = addOption(option);

		var option:Option = new Option('Disable Results',
			'If checked, disables Results screen on all songs',
			'disableSongResults',
			BOOL);
		addOption(option);

		super();
	}

	static function inputDescription():String
	{
		var mode:String = InputSystem.current;
		return Language.getPhrase('description_input_system-' + Paths.formatToSongPath(mode), INPUT_DESCRIPTIONS.get(mode));
	}

	function onChangeInputSystem()
	{
		if(InputSystem.current == InputSystem.PSYCH)
			safeFramesOption.setValue(safeFramesOption.defaultValue);
		safeFramesOption.maxValue = InputSystem.maxSafeFrames();
		inputOption.description = inputDescription();
		refreshOptions();
	}
}
