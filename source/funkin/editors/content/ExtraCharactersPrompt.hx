package funkin.editors.content;

import funkin.data.Song;
import funkin.data.Song.ExtraCharacterData;
import funkin.editors.content.Prompt.BasePrompt;
import funkin.game.notes.ExtraStrumlineLayout;

class ExtraCharactersPrompt extends BasePrompt
{
	static final SIDE_LABELS:Array<String> = ['Opponent', 'Player', 'GF'];
	static final SIDE_VALUES:Array<String> = ['dad', 'bf', 'gf'];
	static final STRUMLINE_LABELS:Array<String> = ['Existing', 'New'];

	var characterList:Array<String>;
	var stageName:String;
	var stageSpots:Int;
	var onChange:Void->Void;
	var onRemove:Int->Void;
	var onStrumline:Int->Bool->Void;
	var onSharedStrumline:Int->Int->String->Void;

	var slotDropDown:PsychUIDropDownMenu;
	var charDropDown:PsychUIDropDownMenu;
	var sideDropDown:PsychUIDropDownMenu;
	var strumlineDropDown:PsychUIDropDownMenu;
	var playableCheckBox:PsychUICheckBox;
	var visibleCheckBox:PsychUICheckBox;
	var iconCheckBox:PsychUICheckBox;
	var scaleStepper:PsychUINumericStepper;
	var spacingStepper:PsychUINumericStepper;
	var hudXStepper:PsychUINumericStepper;
	var hudYStepper:PsychUINumericStepper;
	var chartSpeedCheckBox:PsychUICheckBox;
	var speedStepper:PsychUINumericStepper;
	var alphaStepper:PsychUINumericStepper;
	var separateObjects:Array<FlxSprite> = [];
	var infoText:FlxText;
	var selected:Int = 0;

	public function new(characterList:Array<String>, stageName:String, stageSpots:Int, onChange:Void->Void, onRemove:Int->Void, onStrumline:Int->Bool->Void, onSharedStrumline:Int->Int->String->Void)
	{
		this.characterList = [''].concat(characterList);
		this.stageName = stageName;
		this.stageSpots = stageSpots;
		this.onChange = onChange;
		this.onRemove = onRemove;
		this.onStrumline = onStrumline;
		this.onSharedStrumline = onSharedStrumline;
		super(460, 470, 'Extra Characters', build);
	}

	override function update(elapsed:Float)
	{
		FlxG.mouse.visible = true;
		super.update(elapsed);
	}

	function list():Array<ExtraCharacterData>
	{
		if(PlayState.SONG.extraCharacters == null) PlayState.SONG.extraCharacters = [];
		return PlayState.SONG.extraCharacters;
	}

	function current():ExtraCharacterData
	{
		var characters:Array<ExtraCharacterData> = list();
		return (selected >= 0 && selected < characters.length) ? characters[selected] : null;
	}

	function build(_:BasePrompt)
	{
		var bx:Float = bg.x + 14;
		var by:Float = bg.y;

		var slotLabel:FlxText = new FlxText(bx, by + 60, 150, 'Extra Character:');
		slotDropDown = new PsychUIDropDownMenu(bx, by + 73, [''], function(id:Int, label:String)
		{
			selected = id;
			refresh();
		}, 120);
		slotDropDown.autoSort = false;

		var addButton:PsychUIButton = new PsychUIButton(bx + 140, by + 73, 'Add', addCharacter);
		addButton.normalStyle.bgColor = FlxColor.GREEN;
		addButton.normalStyle.textColor = FlxColor.WHITE;

		var removeButton:PsychUIButton = new PsychUIButton(bx + 230, by + 73, 'Remove', askRemove);
		removeButton.normalStyle.bgColor = FlxColor.RED;
		removeButton.normalStyle.textColor = FlxColor.WHITE;

		var charLabel:FlxText = new FlxText(bx, by + 110, 150, 'Character:');
		charDropDown = new PsychUIDropDownMenu(bx, by + 123, characterList, function(id:Int, character:String)
		{
			var data:ExtraCharacterData = current();
			if(data == null) return;
			data.character = (character != null) ? character : '';
			changed();
		}, 150);

		var sideLabel:FlxText = new FlxText(bx + 180, by + 110, 150, 'Side:');
		sideDropDown = new PsychUIDropDownMenu(bx + 180, by + 123, SIDE_LABELS, function(id:Int, side:String)
		{
			var data:ExtraCharacterData = current();
			if(data == null) return;
			var index:Int = SIDE_LABELS.indexOf(side);
			if(data.strumline != Song.SEPARATE && onSharedStrumline != null)
			{
				var hostSlot:Int = (index < 0) ? hostFromLabel(side) : -1;
				if(index < 0 && hostSlot < 0) return;
				onSharedStrumline(data.slot, hostSlot, (index >= 0) ? SIDE_VALUES[index] : data.parent);
				refresh();
				return;
			}
			if(index < 0) return;
			data.parent = SIDE_VALUES[index];
			changed();
		}, 120);
		sideDropDown.autoSort = false;

		iconCheckBox = new PsychUICheckBox(bx + 330, by + 126, 'Health Icon', 80, function()
		{
			var data:ExtraCharacterData = current();
			if(data == null) return;
			setField(data, 'healthIcon', iconCheckBox.checked, true);
			changed();
		});

		var strumlineLabel:FlxText = new FlxText(bx, by + 160, 150, 'Strumline:');
		strumlineDropDown = new PsychUIDropDownMenu(bx, by + 173, STRUMLINE_LABELS, function(id:Int, label:String)
		{
			var data:ExtraCharacterData = current();
			if(data == null) return;
			var separate:Bool = (label == 'New');
			if((data.strumline == Song.SEPARATE) != separate && onStrumline != null) onStrumline(data.slot, separate);
			refresh();
		}, 120);
		strumlineDropDown.autoSort = false;

		playableCheckBox = new PsychUICheckBox(bx + 180, by + 176, 'Playable?', 120, function()
		{
			var data:ExtraCharacterData = current();
			if(data == null) return;
			setField(data, 'playable', playableCheckBox.checked, data.parent == 'bf');
			changed();
		});

		visibleCheckBox = new PsychUICheckBox(bx + 330, by + 176, 'Visible?', 80, function()
		{
			var data:ExtraCharacterData = current();
			if(data == null) return;
			setField(data, 'visible', visibleCheckBox.checked, true);
			changed();
		});

		var scaleLabel:FlxText = new FlxText(bx, by + 210, 100, 'Scale:');
		scaleStepper = new PsychUINumericStepper(bx, by + 223, 0.05, 1, 0.1, 3, 2);
		scaleStepper.onValueChange = function() editNumber('scale', scaleStepper.value, 1);

		var spacingLabel:FlxText = new FlxText(bx + 105, by + 210, 100, 'Spacing (0 = auto):');
		spacingStepper = new PsychUINumericStepper(bx + 105, by + 223, 5, 0, 0, 400, 0);
		spacingStepper.onValueChange = function() editNumber('spacing', spacingStepper.value, 0);

		var hudXLabel:FlxText = new FlxText(bx + 215, by + 210, 100, 'X Offset:');
		hudXStepper = new PsychUINumericStepper(bx + 215, by + 223, 10, 0, -1280, 1280, 0);
		hudXStepper.onValueChange = function() editNumber('hudX', hudXStepper.value, 0);

		var hudYLabel:FlxText = new FlxText(bx + 320, by + 210, 100, 'Y Offset:');
		hudYStepper = new PsychUINumericStepper(bx + 320, by + 223, 10, 0, -720, 720, 0);
		hudYStepper.onValueChange = function() editNumber('hudY', hudYStepper.value, 0);

		var speedLabel:FlxText = new FlxText(bx, by + 260, 150, 'Scroll Speed:');
		chartSpeedCheckBox = new PsychUICheckBox(bx, by + 276, 'Default (Chart)', 100, function()
		{
			var data:ExtraCharacterData = current();
			if(data == null) return;
			Reflect.deleteField(data, 'usesChartScroll');
			if(chartSpeedCheckBox.checked) Reflect.deleteField(data, 'scrollSpeed');
			else data.scrollSpeed = speedStepper.value;
			changed();
		});
		speedStepper = new PsychUINumericStepper(bx + 120, by + 273, 0.1, 1, 0.1, 10, 2);
		speedStepper.onValueChange = function()
		{
			var data:ExtraCharacterData = current();
			if(data == null || chartSpeedCheckBox.checked) return;
			data.scrollSpeed = speedStepper.value;
			changed();
		};

		var alphaLabel:FlxText = new FlxText(bx + 250, by + 260, 100, 'Alpha:');
		alphaStepper = new PsychUINumericStepper(bx + 250, by + 273, 0.05, 1, 0, 1, 2);
		alphaStepper.onValueChange = function() editNumber('alpha', alphaStepper.value, 1);

		infoText = new FlxText(bx, by + 310, bg.width - 28, '', 8);

		var closeButton:PsychUIButton = new PsychUIButton(0, by + bg.height - 35, 'Close', close);
		closeButton.screenCenter(X);

		separateObjects = [playableCheckBox, visibleCheckBox, scaleLabel, scaleStepper, spacingLabel, spacingStepper, hudXLabel, hudXStepper, hudYLabel, hudYStepper, speedLabel, chartSpeedCheckBox, speedStepper, alphaLabel, alphaStepper];
		for (obj in ([slotLabel, addButton, removeButton, charLabel, sideLabel, strumlineLabel, iconCheckBox] : Array<FlxSprite>).concat(separateObjects).concat([infoText, closeButton, strumlineDropDown, sideDropDown, charDropDown, slotDropDown]))
		{
			obj.cameras = cameras;
			add(obj);
		}
		refresh();
	}

	function setField(data:ExtraCharacterData, field:String, value:Dynamic, defaultValue:Dynamic)
	{
		if(value == defaultValue) Reflect.deleteField(data, field);
		else Reflect.setField(data, field, value);
	}

	function editNumber(field:String, value:Float, defaultValue:Float)
	{
		var data:ExtraCharacterData = current();
		if(data == null) return;
		setField(data, field, value, defaultValue);
		changed();
	}

	function changed()
	{
		if(onChange != null) onChange();
		refresh();
	}

	function setSeparateEnabled(enabled:Bool)
	{
		for (obj in separateObjects)
		{
			obj.active = enabled;
			obj.alpha = enabled ? 1 : 0.4;
		}
	}

	function hostFromLabel(label:String):Int
	{
		if(label == null || !label.startsWith('Char ')) return -1;
		var slot:Null<Int> = Std.parseInt(label.substr('Char '.length));
		return (slot != null) ? slot : -1;
	}

	function sideLabels(data:ExtraCharacterData):Array<String>
	{
		var labels:Array<String> = SIDE_LABELS.copy();
		if(data != null && data.strumline != Song.SEPARATE)
			for (host in Song.separateCharacters(PlayState.SONG))
				if(host != data) labels.push('Char ${host.slot}');
		return labels;
	}

	function refresh()
	{
		var characters:Array<ExtraCharacterData> = list();
		var labels:Array<String> = [for (data in characters) 'Character ${data.slot}'];
		slotDropDown.list = (labels.length > 0) ? labels : ['None'];
		selected = (characters.length > 0) ? Std.int(FlxMath.bound(selected, 0, characters.length - 1)) : -1;
		slotDropDown.selectedIndex = Std.int(Math.max(0, selected));

		var data:ExtraCharacterData = current();
		if(data == null)
		{
			charDropDown.selectedIndex = -1;
			sideDropDown.selectedIndex = -1;
			strumlineDropDown.selectedIndex = -1;
			setSeparateEnabled(false);
			infoText.text = 'Song has no extra characters.\n\nPress "Add" to add one (up to ${Song.MAX_CHARACTERS - 2}).';
			return;
		}

		var separate:Bool = data.strumline == Song.SEPARATE;
		iconCheckBox.checked = Reflect.field(data, 'healthIcon') != false;
		charDropDown.selectedLabel = data.character;
		var labels:Array<String> = sideLabels(data);
		sideDropDown.list = labels;
		var hostLabel:String = (data.strumlineOf != null) ? 'Char ${data.strumlineOf}' : null;
		sideDropDown.selectedIndex = (hostLabel != null && labels.contains(hostLabel)) ? labels.indexOf(hostLabel) : SIDE_VALUES.indexOf(data.parent);
		strumlineDropDown.selectedIndex = separate ? 1 : 0;

		playableCheckBox.checked = ExtraStrumlineLayout.playable(data);
		visibleCheckBox.checked = data.visible != false;
		scaleStepper.value = (data.scale != null && data.scale > 0) ? data.scale : 1;
		spacingStepper.value = (data.spacing != null) ? data.spacing : 0;
		hudXStepper.value = (data.hudX != null) ? data.hudX : 0;
		hudYStepper.value = (data.hudY != null) ? data.hudY : 0;
		var chartSpeed:Bool = data.usesChartScroll == true || data.scrollSpeed == null || data.scrollSpeed <= 0;
		chartSpeedCheckBox.checked = chartSpeed;
		speedStepper.value = chartSpeed ? PlayState.SONG.speed : data.scrollSpeed;
		alphaStepper.value = (data.alpha != null) ? data.alpha : 1;
		setSeparateEnabled(separate);
		if(separate && chartSpeed)
		{
			speedStepper.active = false;
			speedStepper.alpha = 0.4;
		}
		if(separate && data.visible == false)
		{
			alphaStepper.active = false;
			alphaStepper.alpha = 0.4;
		}

		var side:String = SIDE_LABELS[Std.int(Math.max(0, SIDE_VALUES.indexOf(data.parent)))];
		var lines:Array<String> = [];
		if(separate)
		{
			lines.push('New Strumlines are created below base one, position depends on char\'s side (player, opponent, gf)');
			lines.push(ExtraStrumlineLayout.playable(data) ? 'Controlled by Player' : 'Controlled by Opponent');
		}
		else
		{
			lines.push('Extra character uses existing strumline (player, opponent, gf, extra char with new strumline)');
			lines.push('New note types are created for each new char and only registered by them.');
		}
		if(data.character == null || data.character.length < 1)
			lines.push('\nCharacter not selected, notes belong to $side.');

		if(data.slot - Song.FIRST_EXTRA_SLOT < stageSpots)
			lines.push('\nSelected stage contains data for char ${data.slot}.');
		else
			lines.push('\nSelected stage does not contain data for char ${data.slot}.');
		infoText.text = lines.join('\n');
	}

	function addCharacter()
	{
		var characters:Array<ExtraCharacterData> = list();
		var slot:Int = -1;
		for (candidate in Song.FIRST_EXTRA_SLOT...Song.MAX_CHARACTERS + 1)
		{
			if(Song.getExtraCharacter(PlayState.SONG, candidate) == null)
			{
				slot = candidate;
				break;
			}
		}
		if(slot < 0)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}

		characters.push({slot: slot, character: '', parent: 'dad', strumline: Song.SHARED});
		characters.sort((a, b) -> a.slot - b.slot);
		for (index => data in characters)
			if(data.slot == slot) selected = index;
		changed();
	}

	function askRemove()
	{
		var data:ExtraCharacterData = current();
		if(data == null) return;

		var slot:Int = data.slot;
		openSubState(new Prompt('Remove Character $slot?\nNotes associated to said char will be removed!', function()
		{
			if(onRemove != null) onRemove(slot);
			refresh();
		}));
	}
}
