package funkin.ui.options;

class PreferencesSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('preferences_menu', 'Preferences');
		rpcTitle = 'Preferences Menu';

		var option:Option = new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashing',
			BOOL);
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			BOOL);
		addOption(option);

		var option:Option = new Option('Naughtyness',
			"If unchecked, swearing and blood get censored\nin songs, cutscenes and videos.",
			'naughtyness',
			BOOL);
		addOption(option);

		var option:Option = new Option('Combo Stacking',
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read",
			'comboStacking',
			BOOL);
		addOption(option);

		var option:Option = new Option('Subtitles',
			"If checked, subtitles appear during some songs,\ncutscenes and videos.",
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
			"Uncheck this to prevent accidental leaks, it will hide the Application from your \"Playing\" box on Discord",
			'discordRPC',
			BOOL);
		addOption(option);
		#end

		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			BOOL);
		addOption(option);
		#end

		var option:Option = new Option('Pause on Unfocus',
			"If checked, the game pauses when the window loses focus.\nIf unchecked, the game keeps running with the volume lowered.",
			'autoPause',
			BOOL);
		option.onChange = onChangeAutoPause;
		addOption(option);

		var option:Option = new Option('Hide Mouse',
			"If checked, the mouse is hidden and disabled everywhere\nexcept the Main Menu and the Editors.",
			'hideMouse',
			BOOL);
		addOption(option);

		super();
	}

	function onChangeAutoPause()
		FlxG.autoPause = ClientPrefs.data.autoPause;
}
