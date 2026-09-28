package funkin.ui.options;

import funkin.game.InputSystem;

class GameplaySettingsSubState extends BaseOptionsMenu
{
	static final INPUT_DESCRIPTIONS:Map<String, String> = [
		InputSystem.PSYCH => "Psych Engine's input. Sustains count as one note:\nmiss the start or let go and the whole hold is lost.",
		InputSystem.VSLICE => "Funkin's own input: timing-based score,\nBads and Shits break your combo,\nno Ghost Tapping and Safe Frames locked to 8.",
		InputSystem.LEGACY => "Old Psych Engine input: every piece of a hold\ncounts as its own note, Safe Frames go up to 6."
	];

	var inputOption:Option;
	var safeFramesOption:Option;

	public function new()
	{
		title = Language.getPhrase('gameplay_menu', 'Gameplay Settings');
		rpcTitle = 'Gameplay Settings Menu'; //for Discord Rich Presence

		//I'd suggest using "Downscroll" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Downscroll', //Name
			'If checked, notes go Down instead of Up, simple enough.', //Description
			'downScroll', //Save data variable name
			BOOL); //Variable type
		addOption(option);

		var option:Option = new Option('Middlescroll',
			'If checked, your notes get centered.',
			'middleScroll',
			BOOL);
		addOption(option);

		var option:Option = new Option('Opponent Notes',
			'If unchecked, opponent notes get hidden.',
			'opponentStrums',
			BOOL);
		addOption(option);

		var option:Option = new Option('Ghost Tapping',
			"If checked, you won't get misses from pressing keys\nwhile there are no notes able to be hit.",
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
		option.lockedReason = Language.getPhrase('locked_by_vslice_frames', 'Always 8 with the V-Slice Input System.');
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
		safeFramesOption.maxValue = InputSystem.maxSafeFrames();
		inputOption.description = inputDescription();
		refreshOptions();
	}
}
