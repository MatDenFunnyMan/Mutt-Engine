package funkin.ui.options;

class PreferencesSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('preferences_menu', 'Preferences');
		rpcTitle = 'Preferences Menu';

		var option:Option = new Option('Flashing Lights',
			"If unchecked, disables cam flashing and patterns\nthat may cause discomfort for certain users.",
			'flashing',
			BOOL);
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.\nReduces motion sickness or smth like that ig.",
			'camZooms',
			BOOL);
		addOption(option);

		var option:Option = new Option('Naughtyness',
			"If unchecked, raunchy content (ex. swearing, explicit content, etc.)\nwill be disabled from gameplay.",
			'naughtyness',
			BOOL);
		addOption(option);

		var option:Option = new Option('Combo Stacking',
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read",
			'comboStacking',
			BOOL);
		addOption(option);

		var option:Option = new Option('Subtitles',
			"If checked, enables subtitles for cutscenes, songs and videos.",
			'subtitles',
			BOOL);
		addOption(option);

		#if TRANSLATIONS_ALLOWED
		var option:Option = new Option('Language',
			'Change the language of the game.',
			null,
			BUTTON);
		option.onChange = () -> SubStateManager.open(this, 'LanguageSubState', () -> new LanguageSubState());
		addOption(option);
		#end

		#if DISCORD_ALLOWED
		var option:Option = new Option('Discord RPC',
			"If checked, shows the application running\nfrom your \"Playing\" box on Discord.\nUncheck this to avoid accidental leaks!\n(Seriously, this happened to me before and it sucks balls)",
			'discordRPC',
			BOOL);
		addOption(option);
		#end

		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			"Check this option to get notified on startup\nfor updates or new engine versions.",
			'checkForUpdates',
			BOOL);
		addOption(option);
		#end

		var option:Option = new Option('Pause on Unfocus',
			"If checked, the game will pause when losing focus.\nFor modders: uncheck this if you're making a 4th wall breaking mod",
			'autoPause',
			BOOL);
		option.onChange = onChangeAutoPause;
		addOption(option);

		var option:Option = new Option('Unfocused Volume',
			"Volume of the game when unfocused.\n0% is recommended if you're streaming and want to avoid noise.",
			'unfocusedVolume',
			PERCENT);
		option.scrollSpeed = 1;
		option.locked = () -> ClientPrefs.data.autoPause;
		option.lockedReason = Language.getPhrase('locked_by_autopause', 'Only works with Pause on Unfocus off.');
		addOption(option);

		var option:Option = new Option('Input Overlay',
			"If checked, enables a dedicated window for key inputs,\nhold timer in ms, NPS & BPM.\nFor the true pro max gamers :)",
			'inputOverlay',
			BOOL);
		addOption(option);

		var option:Option = new Option('Smooth Health Bar',
			"If checked, the health bar and the icons slide smoothly\ninstead of jumping when health changes.",
			'smoothHealthBar',
			BOOL);
		addOption(option);

		var option:Option = new Option('Note Camera',
			"Moves the camera when a note is hit.\nSimple: basic movement, follows character on focus\nAdvanced: smoother, uses easings for customization",
			'noteCamera',
			STRING,
			['Off', 'Simple', 'Advanced']);
		option.onChange = refreshOptions;
		addOption(option);

		var option:Option = new Option('Note Camera Intensity',
			"Changes Note Camera behavior.\n1 = small, slow movements | 10 = big, fast movements",
			'noteCameraIntensity',
			INT);
		option.minValue = 1;
		option.maxValue = 10;
		option.changeValue = 1;
		option.scrollSpeed = 5;
		option.locked = () -> ClientPrefs.data.noteCamera == 'Off';
		option.lockedReason = Language.getPhrase('locked_by_note_camera', 'Only works with Note Camera on.');
		addOption(option);

		var option:Option = new Option('Note Camera Ease',
			"Ease type for Advanced Note Camera\nDefault uses the normal smooth movement",
			'noteCameraEase',
			STRING,
			funkin.game.effects.NoteCamera.EASES);
		option.hidden = () -> ClientPrefs.data.noteCamera != 'Advanced';
		addOption(option);

		var option:Option = new Option('Hide Mouse',
			"If checked, the mouse is hidden and disabled everywhere\nexcept the Main Menu and the Editors.",
			'hideMouse',
			BOOL);
		addOption(option);

		super();
	}

	function onChangeAutoPause()
	{
		FlxG.autoPause = ClientPrefs.data.autoPause;
		refreshOptions();
	}
}
