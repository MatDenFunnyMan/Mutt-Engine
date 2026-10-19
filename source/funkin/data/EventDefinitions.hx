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
			description: "Add Camera Zoom event, you know this already lol\n\nGame: camGame zoom\n(Default: 0.015)\nHUD: camHUD zoom\n(Default: 0.03)",
			fields: [
				{label: 'Game'},
				{label: 'HUD'}
			]
		},
		{
			name: 'Cam Zoom',
			description: "Changes Cam Zoom for stage\n\nValue: new zoom\nDuration: time it takes to zoom in seconds (0 or empty = instant)\nEase: cam ease / 'classic' ignores duration\nDefault: if checked, sets new value as default",
			fields: [
				{label: 'Value'},
				{label: 'Duration'},
				{label: 'Ease', type: 'dropdown', options: EASES, defaultValue: 'linear', width: DROPDOWN_WIDTH},
				{label: 'Direction', type: 'dropdown', options: DIRECTIONS, defaultValue: 'In', width: DROPDOWN_WIDTH},
				{label: 'Default', type: 'checkbox', defaultValue: 'true'}
			]
		},
		{
			name: 'Cam Bopping',
			description: "Automatic cam zooms per beat\n\nZooms x Beat: self explanatory, lul (0 or empty = resets to normal)\nStrength: bop strength (defaults to 1)",
			fields: [
				{label: 'Zooms x Beat'},
				{label: 'Strength'}
			]
		},
		{
			name: 'Cam Follow Pos',
			description: "Moves the camera to set position\n\nPosition: BF, Dad, GF, char number (3,4,5,...), absolute position (x,y), offsets (ex. BF, 100, -50 - applies offset to 'BF') (empty = default)\nDuration: seconds (0 or empty = instant)\nEase: 'classic' ignores duration\nForced: if checked, forced cam position till next event called",
			fields: [
				{label: 'Position'},
				{label: 'Duration'},
				{label: 'Ease', type: 'dropdown', options: EASES, defaultValue: 'linear', width: DROPDOWN_WIDTH},
				{label: 'Direction', type: 'dropdown', options: DIRECTIONS, defaultValue: 'In', width: DROPDOWN_WIDTH},
				{label: 'Forced', type: 'checkbox', defaultValue: 'true'}
			]
		},
		{
			name: 'Center Camera',
			description: "Sets cam position to stage center, Cam Follow Pos unlocks camera again\n\nDuration: seconds (0 or empty = instant)\nEase: 'classic' ignores duration",
			fields: [
				{label: 'Duration'},
				{label: 'Ease', type: 'dropdown', options: EASES, defaultValue: 'linear', width: DROPDOWN_WIDTH},
				{label: 'Direction', type: 'dropdown', options: DIRECTIONS, defaultValue: 'In', width: DROPDOWN_WIDTH}
			]
		},
		{
			name: 'Cam Speed',
			description: "Changes camera speed\n\nValue: new cam speed (0 or empty = default stage speed)",
			fields: [
				{label: 'Value'}
			]
		},
		{
			name: 'Cam Flash',
			description: "Camera flash, lol\n\nDuration: seconds (default is 1)\nColor: name or hex (#FFFFFF) (defaults to 'white')",
			fields: [
				{label: 'Duration'},
				{label: 'Color'},
				{label: 'Camera', type: 'dropdown', options: ['Game', 'HUD', 'Other'], defaultValue: 'HUD', width: DROPDOWN_WIDTH}
			]
		},
		{
			name: 'Cam Shake',
			description: "Shakes the camera\n\nStrength: 0-3\nDuration: seconds (defaults to 0.5)",
			fields: [
				{label: 'Camera', type: 'dropdown', options: ['Game', 'HUD', 'Other', 'All'], defaultValue: 'Game', width: DROPDOWN_WIDTH},
				{label: 'Strength'},
				{label: 'Duration'}
			]
		},
		{
			name: 'Cam Rotation',
			description: "Rotates the camera\n\nAngle: degrees (0 = normal)\nDuration: seconds (0 or empty = instant)\nForced: if checked, cam angle does not change until new event",
			fields: [
				{label: 'Camera', type: 'dropdown', options: ['Game', 'HUD', 'Other', 'All'], defaultValue: 'Game', width: DROPDOWN_WIDTH},
				{label: 'Angle'},
				{label: 'Duration'},
				{label: 'Ease', type: 'dropdown', options: TWEEN_EASES, defaultValue: 'linear', width: DROPDOWN_WIDTH},
				{label: 'Direction', type: 'dropdown', options: DIRECTIONS, defaultValue: 'In', width: DROPDOWN_WIDTH},
				{label: 'Forced', type: 'checkbox', defaultValue: 'true'}
			]
		},
		{
			name: 'Change Character',
			description: "Change Character event, duh\n\nCharacter: BF, Dad, GF, char number (3,4,5,...)\nNew Char: new character name",
			fields: [
				{label: 'Character'},
				{label: 'New Char'}
			]
		},
		{
			name: 'Set Char Idle Alt',
			description: "Plays alt idle animation for character\n\nCharacter: BF, Dad, GF, char number (3,4,5,...)\nSuffix: put '-alt' (empty = normal idle)",
			fields: [
				{label: 'Character'},
				{label: 'Suffix'}
			]
		},
		{
			name: 'Play Animation',
			description: "Plays an animation on a character.\n\nCharacter: BF, Dad, GF, char num (3,4,5,...)\nAnimation: name of animation (empty = stops loop)\nForced: does not get interrupted in any way\nLoop: self-explanatory lmao",
			fields: [
				{label: 'Character'},
				{label: 'Animation'},
				{label: 'Forced', type: 'checkbox', defaultValue: 'false'},
				{label: 'Loop', type: 'checkbox', defaultValue: 'false'}
			]
		},
		{
			name: 'Character Sing-Along',
			description: "Extra characters sing along with the \"father\" character (ex. duets), includes misses\n\nFather: char that 'commands' the 'children' (BF, Dad, GF, char num)\nChildren: chars that follow the 'father' (BF, Dad, GF, char num)\nMust be separated with commas (',')\nAll: every char on the father's side sings\nChildren = null + 'All' = false = back to normal",
			fields: [
				{label: 'Father', defaultValue: 'Dad'},
				{label: 'Children'},
				{label: 'All', type: 'checkbox', defaultValue: 'false'}
			]
		},
		{
			name: 'Set GF Speed',
			description: "Sets GF bopping speed.\n\nSpeed: 1 = normal, 2 = 1/2 speed,\n4 = 1/4 speed etc.\nMust be an integer!",
			fields: [
				{label: 'Speed', defaultValue: '1'}
			]
		},
		{
			name: 'Change Notes',
			description: "Changes the note skins.\n\nTo revert back to FNF skin, insert 'default' in Notes or Strums\nAllows paths (ex. 'myNote' or 'noteSkins/myNote' or 'notes/skins/custom_folder/myNote')",
			fields: [
				{label: 'Target', type: 'dropdown', options: ['BF', 'Dad', 'Both'], defaultValue: 'Both', width: DROPDOWN_WIDTH},
				{label: 'Notes'},
				{label: 'Strums'},
				{label: 'Splashes'},
				{label: 'Hold Covers'}
			]
		},
		{
			name: 'Set Note Speed',
			description: "Changes note scroll speed for both strumlines OR singular\n\nValue: speed multiplier (1 = chart)\nDuration: seconds (0 or empty = instant)",
			fields: [
				{label: 'Target', type: 'dropdown', options: ['Opponent', 'Player', 'All'], defaultValue: 'All', width: DROPDOWN_WIDTH},
				{label: 'Value'},
				{label: 'Duration'}
			]
		},
		{
			name: 'Play Video',
			description: "Plays a video, duh...\n\nVideo: file name, must be .mp4\nCamera: game, HUD, other\nLayer: zIndex of video sprite (empty = default)",
			fields: [
				{label: 'Video'},
				{label: 'Camera', type: 'dropdown', options: ['Game', 'HUD', 'Other'], defaultValue: 'Other', width: DROPDOWN_WIDTH},
				{label: 'Layer'},
				{label: 'Can Skip', type: 'checkbox', defaultValue: 'false'},
				{label: 'Loop', type: 'checkbox', defaultValue: 'false'}
			]
		},
		{
			name: 'Health Drain',
			description: "ahahah funny overused health drain fucking event!!!!\nmisses are also counted :)\n\nAmount: damage, in percent (%)\n(0 or empty = disable health drain)\nPersistent: if checked, ignores opponent input, drains naturally\nUncheck this if you want the opponent health drain",
			fields: [
				{label: 'Amount'},
				{label: 'Persistent', type: 'checkbox', defaultValue: 'false'}
			]
		},
		{
			name: 'Ghost Trail',
			description: "Adds ghost trails to characters\n\nCharacter: BF, Dad, GF, char num (3,4,5,...)\nType: simple, animated, AURA (this one WAS important, trust...), Off\nDouble Note: ghosts only on 2+ notes, works only for 'simple' & 'animated'\nDistance: how far the ghost travels, works only for 'animated' (ex. 10 = ghost moves 10px in designated direction)\nColor: ghost color, type 'hp' or 'health' for healthbar color (empty = normal colors, semi-transparent / AURA: healthbar color)\nDuration: how long a ghost lasts, in seconds",
			fields: [
				{label: 'Character', defaultValue: 'Dad'},
				{label: 'Type', type: 'dropdown', options: ['Simple', 'Animated', 'Aura', 'Off'], defaultValue: 'Simple', width: DROPDOWN_WIDTH},
				{label: 'Double Note', type: 'checkbox', defaultValue: 'false'},
				{label: 'Distance'},
				{label: 'Color'},
				{label: 'Duration'}
			]
		},
		{
			name: 'Silhouette',
			description: "hehehe silhouette event for the funzies. also makes a color bg\n\nColors: bg first, then for chars separated with commas (ex.\"white\", \"red\", \"blue\", \"green\"), order: bg, dad, bf, optional values for gf and extra chars\nLeave empty for black bg and icon colors\nValue: 0 to 1 (default: 1), empty = default, 0 = off\nDuration: in seconds (0 or empty = instant)\nHUD: if checked, colors are applied to hud as well\nDetailed: shows character outlines/details",
			fields: [
				{label: 'Colors'},
				{label: 'Value'},
				{label: 'Duration'},
				{label: 'Ease', type: 'dropdown', options: TWEEN_EASES, defaultValue: 'linear', width: DROPDOWN_WIDTH},
				{label: 'HUD', type: 'checkbox', defaultValue: 'false'},
				{label: 'Detailed', type: 'checkbox', defaultValue: 'false'}
			]
		},
		{
			name: 'BG Flash',
			description: "Simple BG flash almost 99% of Sonic.EXE mods use ig??\n\nColor: name or hex (default = white)\nDuration: in seconds (default = 1)\nChar Color: color for chars, leave empty to ignore them",
			fields: [
				{label: 'Color'},
				{label: 'Duration'},
				{label: 'Char Color'},
				{label: 'Ease', type: 'dropdown', options: TWEEN_EASES, defaultValue: 'quad', width: DROPDOWN_WIDTH},
				{label: 'Direction', type: 'dropdown', options: DIRECTIONS, defaultValue: 'Out', width: DROPDOWN_WIDTH}
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

	public static function canonicalName(name:String):String
	{
		return switch(name)
		{
			case 'Set Cam Zoom': 'Cam Zoom';
			case 'Background Flash': 'BG Flash';
			default: name;
		}
	}

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
