package funkin.ui.options;

class DebugSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('debug_menu', 'Debug Settings');
		rpcTitle = 'Debug Settings Menu';

		var option:Option = new Option('Developer Mode',
			'If checked, enables developer shortcuts:\nPress 7 to open the Editor Picker,\naccess Chart Editor and Character Editor from PlayState.',
			'developerMode',
			BOOL);
		addOption(option);

		#if !mobile
		var option:Option = new Option('Debug Display',
			'Select Debug Display mode.\nOff = Hidden, Simple = Basic info, Simplier = FPS + Memory only, Advanced = Detailed graphs.',
			'fpsMode',
			STRING,
			['Off', 'Simple', 'Advanced', 'Simplier']);
		option.onChange = onChangeDebugDisplay;
		addOption(option);

		var option:Option = new Option('Debug Display BG',
			'Adjusts Debug Display background opacity.\n100% = Fully visible, 10% = Nearly invisible, 0% = Completely hidden.',
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
			"If unchecked, the screenshot key won't do anything.",
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
