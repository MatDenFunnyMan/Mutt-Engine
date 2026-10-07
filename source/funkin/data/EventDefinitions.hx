package funkin.data;

typedef EventField = {
	var label:String;
	@:optional var type:String;
	@:optional var options:Array<String>;
	@:optional var defaultValue:String;
	@:optional var width:Int;
}

typedef EventDefinition = {
	var name:String;
	var description:String;
	var fields:Array<EventField>;
}

class EventDefinitions
{
	public static final NOTHING_DESCRIPTION:String = "Nothing. Yep, that's right.";

	public static final EASES:Array<String> = ['linear', 'classic', 'sine', 'quad', 'cube', 'quart', 'quint', 'expo', 'circ', 'back', 'elastic', 'bounce', 'smoothStep', 'smootherStep'];
	public static final DIRECTIONS:Array<String> = ['In', 'Out', 'InOut'];
	public static final TWEEN_EASES:Array<String> = [for (ease in EASES) if (ease != 'classic') ease];
	public static final DROPDOWN_WIDTH:Int = 105;

	public static final BUILT_IN:Array<EventDefinition> = [
		{
			name: 'Add Cam Zoom',
			description: "Adds a quick zoom to the cameras.\n\nGame Zoom: game camera zoom to add\n(Default: 0.015)\nHUD Zoom: HUD zoom to add\n(Default: 0.03)",
			fields: [
				{label: 'Game Zoom'},
				{label: 'HUD Zoom'}
			]
		},
		{
			name: 'Cam Zoom',
			description: "Changes the game camera zoom.\n\nValue: new zoom (e.g. 1.05)\nDuration: seconds, empty or 0 = instant\nEase 'classic': the camera eases to it\nlike a normal zoom, Duration is ignored\nDefault: if checked, the new zoom stays\nuntil the next change. If unchecked,\nthe camera goes back to the default zoom.",
			fields: [
				{label: 'Value'},
				{label: 'Duration'},
				{label: 'Ease', type: 'dropdown', options: EASES, defaultValue: 'linear', width: DROPDOWN_WIDTH},
				{label: 'Direction', type: 'dropdown', options: DIRECTIONS, defaultValue: 'InOut', width: DROPDOWN_WIDTH},
				{label: 'Default', type: 'checkbox', defaultValue: 'true'}
			]
		},
		{
			name: 'Cam Bopping',
			description: "Makes the cameras bop every few beats.\n\nZooms x Beat: every how many beats\nEmpty or 0 = back to normal\nStrength: bop strength (Default: 1)",
			fields: [
				{label: 'Zooms x Beat'},
				{label: 'Strength'}
			]
		},
		{
			name: 'Cam Follow Pos',
			description: "Moves the camera to a character or a position.\n\nPosition: BF, Dad, GF, strumline number\n(3, 4, 5...), or X, Y (e.g. 640, 880)\nEmpty = back to the normal camera\nDuration: seconds, empty or 0 = instant\nEase 'classic': moves with the stage\ncamera speed, Duration is ignored\nForced: if checked, the camera stays there\nuntil you clear it. If unchecked, the next\nsection moves the camera again.",
			fields: [
				{label: 'Position'},
				{label: 'Duration'},
				{label: 'Ease', type: 'dropdown', options: EASES, defaultValue: 'linear', width: DROPDOWN_WIDTH},
				{label: 'Direction', type: 'dropdown', options: DIRECTIONS, defaultValue: 'InOut', width: DROPDOWN_WIDTH},
				{label: 'Forced', type: 'checkbox', defaultValue: 'true'}
			]
		},
		{
			name: 'Center Camera',
			description: "Moves the camera between the player\nand the opponent and keeps it there.\nUse Cam Follow Pos with an empty\nPosition to unlock it.\n\nDuration: seconds, empty or 0 = instant\nEase 'classic': moves with the stage\ncamera speed, Duration is ignored",
			fields: [
				{label: 'Duration'},
				{label: 'Ease', type: 'dropdown', options: EASES, defaultValue: 'linear', width: DROPDOWN_WIDTH},
				{label: 'Direction', type: 'dropdown', options: DIRECTIONS, defaultValue: 'InOut', width: DROPDOWN_WIDTH}
			]
		},
		{
			name: 'Cam Speed',
			description: "Changes how fast the camera follows\nits target, until the next Cam Speed.\n\nValue: new camera speed\nEmpty or 0 = back to the stage speed",
			fields: [
				{label: 'Value'}
			]
		},
		{
			name: 'Cam Flash',
			description: "Flashes a camera.\n\nDuration: seconds (Default: 1)\nColor: color name or hex code (#FFFFFF)\n(Default: white)",
			fields: [
				{label: 'Duration'},
				{label: 'Color'},
				{label: 'Camera', type: 'dropdown', options: ['Game', 'HUD', 'Other'], defaultValue: 'HUD', width: DROPDOWN_WIDTH}
			]
		},
		{
			name: 'Cam Shake',
			description: "Shakes a camera.\n\nStrength: from 0 to 3\nDuration: seconds (Default: 0.5)",
			fields: [
				{label: 'Camera', type: 'dropdown', options: ['Game', 'HUD', 'Other', 'All'], defaultValue: 'Game', width: DROPDOWN_WIDTH},
				{label: 'Strength'},
				{label: 'Duration'}
			]
		},
		{
			name: 'Cam Rotation',
			description: "Rotates a camera without black borders.\n\nAngle: degrees, 0 = normal\nDuration: seconds, empty or 0 = instant\nForced: if checked, the camera stays rotated.\nIf unchecked, it goes back to 0 with the\nsame Duration and Ease.",
			fields: [
				{label: 'Camera', type: 'dropdown', options: ['Game', 'HUD', 'Other', 'All'], defaultValue: 'Game', width: DROPDOWN_WIDTH},
				{label: 'Angle'},
				{label: 'Duration'},
				{label: 'Ease', type: 'dropdown', options: TWEEN_EASES, defaultValue: 'linear', width: DROPDOWN_WIDTH},
				{label: 'Direction', type: 'dropdown', options: DIRECTIONS, defaultValue: 'InOut', width: DROPDOWN_WIDTH},
				{label: 'Forced', type: 'checkbox', defaultValue: 'true'}
			]
		},
		{
			name: 'Change Character',
			description: "Changes a character.\n\nCharacter: BF, Dad, GF\nor strumline number (3, 4, 5...)\nNew Character: name of the new character",
			fields: [
				{label: 'Character'},
				{label: 'New Character'}
			]
		},
		{
			name: 'Set Char Idle Alt',
			description: "Adds a suffix to the idle animation,\ne.g. -alt plays 'idle-alt'.\n\nCharacter: BF, Dad, GF\nor strumline number (3, 4, 5...)\nSuffix: empty = normal idle",
			fields: [
				{label: 'Character'},
				{label: 'Suffix'}
			]
		},
		{
			name: 'Play Animation',
			description: "Plays an animation on a character.\n\nCharacter: BF, Dad, GF\nor strumline number (3, 4, 5...)\nAnimation: empty = stops a looped\nanimation and goes back to normal\nForced: notes and idle can't interrupt it\nLoop: the animation repeats",
			fields: [
				{label: 'Character'},
				{label: 'Animation'},
				{label: 'Forced', type: 'checkbox', defaultValue: 'false'},
				{label: 'Loop', type: 'checkbox', defaultValue: 'false'}
			]
		},
		{
			name: 'Set GF Speed',
			description: "Sets GF head bopping speed.\n\nSpeed: 1 = normal, 2 = 1/2 speed,\n4 = 1/4 speed etc.\nMust be an integer!",
			fields: [
				{label: 'Speed', defaultValue: '1'}
			]
		},
		{
			name: 'Change Notes',
			description: "Changes the note skins.\n\nEmpty fields are left as they are,\nwrite 'default' to go back to the base skin.\nSkins can be a name or a path\n(e.g. myNote or noteSkins/myNote).",
			fields: [
				{label: 'Target', type: 'dropdown', options: ['BF', 'Dad', 'Both'], defaultValue: 'Both', width: DROPDOWN_WIDTH},
				{label: 'Note Skin'},
				{label: 'Strum Skin'},
				{label: 'Splash Skin'},
				{label: 'Hold Cover Skin'}
			]
		},
		{
			name: 'Set Note Speed',
			description: "Changes the scroll speed of the notes.\n\nValue: speed multiplier (1 = chart speed)\nDuration: seconds, empty or 0 = instant",
			fields: [
				{label: 'Target', type: 'dropdown', options: ['Opponent', 'Player', 'All'], defaultValue: 'All', width: DROPDOWN_WIDTH},
				{label: 'Value'},
				{label: 'Duration'}
			]
		},
		{
			name: 'Play Video',
			description: "Plays a video.\n\nVideo: video file name\nLayer: number, 0 = bottom\n(empty = default)",
			fields: [
				{label: 'Video'},
				{label: 'Camera', type: 'dropdown', options: ['Game', 'HUD', 'Other'], defaultValue: 'Other', width: DROPDOWN_WIDTH},
				{label: 'Layer'},
				{label: 'Can Skip', type: 'checkbox', defaultValue: 'false'},
				{label: 'Mid-Song', type: 'checkbox', defaultValue: 'true'},
				{label: 'Loop', type: 'checkbox', defaultValue: 'false'},
				{label: 'Play On Load', type: 'checkbox', defaultValue: 'true'}
			]
		},
		{
			name: 'Health Drain',
			description: "Drains health, it never kills.\nMisses still take health as usual.\n\nAmount: % of the health bar\nEmpty or 0 = off\nPersistent: if checked, drains every second.\nIf unchecked, drains on opponent notes.",
			fields: [
				{label: 'Amount'},
				{label: 'Persistent', type: 'checkbox', defaultValue: 'false'}
			]
		}
	];

	public static final HIDDEN:Array<String> = [
		'Hey!', 'Set Property', 'Play Sound',
		'Set Cam Zoom',
		'Dadbattle Spotlight', 'Philly Glow', 'Kill Henchmen', 'BG Freaks Expression', 'Trigger BG Ghouls',
		'Add Camera Zoom', 'Set Camera Bopping', 'Camera Follow Pos', 'Target Follow Pos', 'Target Camera',
		'(STEPS) Set Cam Zoom', '(STEPS) Target Camera', '(STEPS) Target Follow Pos',
		'Alt Idle Animation', 'Screen Shake', 'Change Scroll Speed', 'Flash Camera', 'Video Player',
		'Change Note Skin', 'Change NoteStrum Skin', 'Change Hold Cover Skin', 'Change Note Splash Skin'
	];

	public static function get(name:String):EventDefinition
	{
		if(name == null) return null;
		name = canonicalName(name);
		for (def in BUILT_IN)
			if(def.name == name) return def;
		return null;
	}

	public static inline function canonicalName(name:String):String
		return name == 'Set Cam Zoom' ? 'Cam Zoom' : name;

	inline public static function isHidden(name:String):Bool
		return HIDDEN.contains(name);

	public static function uiData(def:EventDefinition):Array<Dynamic>
	{
		var data:Array<Dynamic> = [];
		for (i => field in def.fields)
		{
			var item:Dynamic = {label: field.label, type: (field.type != null) ? field.type : 'inputtext', value: i + 1};
			if(field.options != null) item.options = field.options;
			if(field.width != null) item.width = field.width;
			data.push(item);
		}
		return data;
	}
}
