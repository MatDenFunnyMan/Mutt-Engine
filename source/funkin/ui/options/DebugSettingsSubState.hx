package funkin.ui.options;

class DebugSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('debug_menu', 'Debug Settings');
		rpcTitle = 'Debug Settings Menu';

		var option:Option = new Option('Developer Mode',
			"If checked, enables developer features and shortcuts.\nGrants access to Editor Menu (6 on Main Menu)\n& PlayState Debug Mode (Ctrl+Shift+Enter)",
			'developerMode',
			BOOL);
		addOption(option);

		#if !mobile
		var option:Option = new Option('Debug Display',
			"Select Debug Display mode, or press F6 anywhere to switch.\nOptions: Off, Simple, Simpler, Advanced",
			'fpsMode',
			STRING,
			['Off', 'Simple', 'Simpler', 'Advanced']);
		option.onChange = onChangeDebugDisplay;
		addOption(option);

		var option:Option = new Option('Debug Display BG',
			"Adjusts Debug Display background opacity.",
			'debugBgOpacity',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = onChangeDebugDisplay;
		addOption(option);
		#end

		var option:Option = new Option('Allow Screenshots',
			"If unchecked, screenshots are disabled, including hotkey",
			'allowScreenshots',
			BOOL);
		addOption(option);

		super();
	}

	#if !mobile
	function onChangeDebugDisplay()
		ClientPrefs.updateFPSCounter();
	#end
}
