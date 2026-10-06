package funkin.ui.options;

class NotesSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('notes_menu', 'Notes');
		rpcTitle = 'Notes Settings Menu';

		var option:Option = new Option('Open Note Color Editor',
			'Change the colors of your notes.',
			null,
			BUTTON);
		option.onChange = () -> SubStateManager.open(this, 'NotesColorSubState', () -> new NotesColorSubState());
		addOption(option);

		var option:Option = new Option('Strumline Background',
			'Give player strumline a semi-transparent background',
			'strumlineBackgroundPlayer',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Quant Notes',
			"If checked, notes are colored by their beat quantization\ninstead of their lane color.",
			'quantNotes',
			BOOL);
		addOption(option);

		super();
	}
}
