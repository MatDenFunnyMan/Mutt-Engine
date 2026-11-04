package funkin.editors;

import haxe.Json;
import haxe.io.Path;

import funkin.data.DialogueData;
import funkin.game.cutscenes.DialogueCutscene;
import funkin.editors.content.Prompt;
import funkin.editors.content.FileDialogHandler;
import funkin.editors.NoteEditorState.NoteEditorColorPicker;

typedef DialogueField = {
	var refresh:Void->Void;
}

class DialogueEditorState extends MusicBeatState
{
	static final TIPS:String = 'A/D - Scene | Space - Replay | Enter - Advance | W/S - Portrait animation | Esc - Exit\nArrows - Move portrait (Style tab: box) | Ctrl+Arrows - Offset | Shift = 10x | Ctrl+S - Save';
	static final SKIP_MODES:Array<String> = ['Wait Input', 'Auto', 'Auto (+ Delay)'];
	static final FX_MODES:Array<String> = ['None', 'shake', 'flash', 'textShake'];
	static final FX_LABELS:Array<String> = ['None', 'Shake', 'Flash', 'Text Shake'];
	static final FADE_MODES:Array<String> = ['None', 'in', 'out'];
	static inline final PREVIEW_WIDTH:Int = 880;
	static inline final PREVIEW_HEIGHT:Int = 495;
	static inline final PREVIEW_Y:Int = 28;

	var camPreview:FlxCamera;
	var camHUD:FlxCamera;
	var preview:DialogueCutscene;

	var data:DialogueFileData;
	var styleName:String = DialogueData.DEFAULT_STYLE;
	var style:DialogueStyleData;
	var editedCharacters:Map<String, DialogueCharacterData> = [];
	var charId:String = 'bf';
	var curScene:Int = 0;
	var curAnim:Int = 0;
	var curBackground:Int = 0;

	var fields:Array<DialogueField> = [];
	var fileDialog:FileDialogHandler = new FileDialogHandler();
	var unsaved:Bool = false;
	var transitioning:Bool = false;
	var refreshing:Bool = false;
	var previewAudio:Bool = true;
	static var muteVoices:Bool = false;
	var rebuildQueued:Bool = false;

	var UI_box:PsychUIBox;
	var infoText:FlxText;
	var messageText:FlxText;
	var portraitDropDown:PsychUIDropDownMenu;
	var animDropDown:PsychUIDropDownMenu;
	var backgroundDropDown:PsychUIDropDownMenu;

	override function create()
	{
		persistentUpdate = persistentDraw = true;
		var camBG:FlxCamera = initPsychCamera();
		camBG.bgColor = 0xFF1E1E1E;

		var frame:FlxSprite = new FlxSprite(6, PREVIEW_Y - 4).makeGraphic(PREVIEW_WIDTH + 8, PREVIEW_HEIGHT + 8, 0xFF0A0A0A);
		frame.cameras = [camBG];
		add(frame);
		var infoPanel:FlxSprite = new FlxSprite(6, PREVIEW_Y + PREVIEW_HEIGHT + 10).makeGraphic(PREVIEW_WIDTH + 8, FlxG.height - PREVIEW_Y - PREVIEW_HEIGHT - 16, 0xFF2A2A2A);
		infoPanel.cameras = [camBG];
		add(infoPanel);

		camPreview = new FlxCamera(10, PREVIEW_Y, FlxG.width, FlxG.height, PREVIEW_WIDTH / FlxG.width);
		camPreview.bgColor = 0xFF5A5A5A;
		FlxG.cameras.add(camPreview, false);

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		infoText = makeHudText(16, PREVIEW_Y + PREVIEW_HEIGHT + 16, PREVIEW_WIDTH - 12, 16);
		var tipText:FlxText = makeHudText(16, FlxG.height - 42, PREVIEW_WIDTH - 12, 14);
		tipText.text = TIPS;
		tipText.alpha = 0.75;
		messageText = makeHudText(16, FlxG.height - 66, PREVIEW_WIDTH - 12, 16);
		messageText.alpha = 0;

		loadStartingDialogue();
		addEditorBox();
		addColorBox();
		addUpperMenu();
		add(fileDialog);
		FlxG.mouse.visible = true;

		refreshFields();
		rebuildPreview();

		if(FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.fadeOut(0.6, 0);
		EditorHelper.scheduleEditorMusic(10);
		super.create();
	}

	function makeHudText(x:Float, y:Float, width:Int, size:Int):FlxText
	{
		var text:FlxText = new FlxText(x, y, width, '', size);
		text.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.scrollFactor.set();
		text.cameras = [camHUD];
		add(text);
		return text;
	}

	function loadStartingDialogue()
	{
		var loaded:DialogueFileData = (PlayState.SONG != null) ? DialogueData.songDialogue(PlayState.SONG.song, 'dialogue') : null;
		if(loaded != null) setDialogue(copy(loaded));
		else loadTemplate();
	}

	static inline final TEMPLATE_STYLE:String = 'new-style';
	static inline final TEMPLATE_CHARACTER:String = 'char-name';

	static function templateDialogue():DialogueFileData
	{
		return {
			style: TEMPLATE_STYLE,
			backgrounds: [],
			scenes: [{scene: 'normal', character: TEMPLATE_CHARACTER, portrait: 'neutral', text: 'Placeholder text'}]
		};
	}

	function loadTemplate()
	{
		editedCharacters.clear();
		DialogueData.characterOverrides.clear();
		DialogueData.styleOverrides.clear();

		var info:DialogueCharacterData = DialogueData.defaultCharacter(TEMPLATE_CHARACTER);
		info.name = 'Name';
		info.portrait = '';
		editedCharacters.set(TEMPLATE_CHARACTER, info);
		DialogueData.characterOverrides.set(TEMPLATE_CHARACTER, info);

		var templateStyle:DialogueStyleData = copy(DialogueData.style(DialogueData.DEFAULT_STYLE));
		templateStyle.hint = 'Forward input text here';
		templateStyle.skipHint = 'Skip text here';
		DialogueData.styleOverrides.set(TEMPLATE_STYLE, templateStyle);

		setDialogue(templateDialogue());
		unsaved = false;
	}

	function setDialogue(file:DialogueFileData)
	{
		data = file;
		if(data.backgrounds == null) data.backgrounds = [];
		styleName = (data.style != null && data.style.length > 0) ? data.style : DialogueData.DEFAULT_STYLE;
		style = copy(DialogueData.style(styleName));
		DialogueData.styleOverrides.set(styleName, style);
		curScene = 0;
		curBackground = 0;
		var first:DialogueScene = data.scenes[0];
		selectCharacter((first != null && first.character != null) ? first.character : 'bf');
	}

	static function copy<T>(value:T):T
		return (value == null) ? null : Json.parse(Json.stringify(value));

	inline function scene():DialogueScene
		return data.scenes[curScene];

	function character():DialogueCharacterData
	{
		if(!editedCharacters.exists(charId))
		{
			DialogueData.characterOverrides.remove(charId);
			var loaded:DialogueCharacterData = DialogueData.character(charId);
			var info:DialogueCharacterData = (loaded != null) ? copy(loaded) : DialogueData.defaultCharacter(charId);
			if(info.animations == null) info.animations = [];
			editedCharacters.set(charId, info);
			DialogueData.characterOverrides.set(charId, info);
		}
		return editedCharacters.get(charId);
	}

	function selectCharacter(id:String)
	{
		if(id == null || id.trim().length < 1) return;
		charId = id.trim();
		curAnim = 0;
		character();
	}

	function addEditorBox()
	{
		UI_box = new PsychUIBox(PREVIEW_WIDTH + 20, 6, FlxG.width - PREVIEW_WIDTH - 26, 660, ['Scene', 'Audio', 'Character', 'Style']);
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];
		addSceneUI();
		addAudioUI();
		addCharacterUI();
		addStyleUI();
		UI_box.selectedName = 'Scene';
		add(UI_box);

		var buttonY:Float = UI_box.y + UI_box.height + 6;
		var musicCheckBox:PsychUICheckBox = EditorHelper.createEditorMusicCheckBox(UI_box.x + 4, buttonY + 8, 100);
		musicCheckBox.cameras = [camHUD];
		add(musicCheckBox);

		var voicesCheckBox:PsychUICheckBox = new PsychUICheckBox(UI_box.x + 128, buttonY + 8, 'Mute Voices', 100);
		voicesCheckBox.checked = muteVoices;
		voicesCheckBox.onClick = function()
		{
			muteVoices = voicesCheckBox.checked;
			if(preview != null) preview.playVoices = !muteVoices;
		};
		voicesCheckBox.cameras = [camHUD];
		add(voicesCheckBox);

		var audioCheckBox:PsychUICheckBox = new PsychUICheckBox(UI_box.x + 248, buttonY + 8, 'Preview Music/SFX', 100);
		audioCheckBox.checked = previewAudio;
		audioCheckBox.onClick = function()
		{
			previewAudio = audioCheckBox.checked;
			rebuildPreview();
		};
		audioCheckBox.cameras = [camHUD];
		add(audioCheckBox);
	}

	function label(tab:FlxSpriteGroup, x:Float, y:Float, text:String)
		tab.add(new FlxText(x, y - 15, 0, text));

	function inputField(tab:FlxSpriteGroup, x:Float, y:Float, width:Int, name:String, get:Void->String, set:String->Void, ?rebuild:Bool = true):PsychUIInputText
	{
		label(tab, x, y, name);
		var input:PsychUIInputText = new PsychUIInputText(x, y, width, '', 8);
		input.onChange = function(old:String, cur:String)
		{
			if(refreshing) return;
			set(cur);
			changed(rebuild);
		};
		tab.add(input);
		fields.push({refresh: function() if(PsychUIInputText.focusOn != input) input.text = (get() != null) ? get() : ''});
		return input;
	}

	var colorBox:PsychUIBox;
	var colorPicker:NoteEditorColorPicker;
	var colorHexInput:PsychUIInputText;
	var colorTitle:FlxText;
	var colorTarget:String->Void = null;

	function addColorBox()
	{
		colorBox = new PsychUIBox(PREVIEW_WIDTH / 2 - 105, 140, 230, 250, ['Color Picker']);
		colorBox.scrollFactor.set();
		colorBox.canMinimize = false;
		colorBox.selectedName = 'Color Picker';
		colorBox.cameras = [camHUD];
		var menu = colorBox.getTab('Color Picker').menu;

		colorTitle = new FlxText(10, 4, 180, '');
		colorPicker = new NoteEditorColorPicker(10, 22);
		colorPicker.onChange = function(color:FlxColor)
		{
			colorHexInput.text = color.toHexString(false, false);
			applyPickedColor(colorHexInput.text);
		};
		colorHexInput = new PsychUIInputText(10, 202, 80, '', 8);
		colorHexInput.onChange = function(old:String, cur:String)
		{
			var hex:String = cur.trim().replace('#', '');
			if(hex.length != 6) return;
			colorPicker.setColor(CoolUtil.colorFromString(hex));
			applyPickedColor(hex.toUpperCase());
		};
		var closeButton:PsychUIButton = new PsychUIButton(196, 4, 'X', closeColorBox, 24, 24);

		menu.add(colorTitle);
		menu.add(colorPicker);
		menu.add(new FlxText(10, colorHexInput.y - 15, 0, 'Hex:'));
		menu.add(colorHexInput);
		menu.add(closeButton);
		colorBox.visible = colorBox.active = false;
		add(colorBox);
	}

	function openColorBox(title:String, current:String, target:String->Void)
	{
		colorTarget = null;
		colorTitle.text = title;
		var color:FlxColor = (current != null && current.trim().length > 0) ? CoolUtil.colorFromString(current) : FlxColor.WHITE;
		colorPicker.setColor(color);
		colorHexInput.text = color.toHexString(false, false);
		colorTarget = target;
		colorBox.visible = colorBox.active = true;
	}

	function closeColorBox()
	{
		colorTarget = null;
		colorBox.visible = colorBox.active = false;
	}

	function applyPickedColor(hex:String)
	{
		if(colorTarget == null) return;
		colorTarget(hex);
		changed(true);
	}

	function colorField(tab:FlxSpriteGroup, x:Float, y:Float, width:Int, name:String, get:Void->String, set:String->Void):PsychUIInputText
	{
		var input:PsychUIInputText = inputField(tab, x, y, width - 26, name, get, set);
		var pick:PsychUIButton = new PsychUIButton(x + width - 22, y - 2, '+', function() openColorBox(name.replace(':', ''), get(), set), 22, 20);
		tab.add(pick);
		return input;
	}

	function stepperField(tab:FlxSpriteGroup, x:Float, y:Float, name:String, step:Float, min:Float, max:Float, decimals:Int, get:Void->Float, set:Float->Void, ?width:Int = 60):PsychUINumericStepper
	{
		label(tab, x, y, name);
		var stepper:PsychUINumericStepper = new PsychUINumericStepper(x, y, step, min, min, max, decimals, width);
		stepper.onValueChange = function()
		{
			if(refreshing) return;
			set(stepper.value);
			changed(true);
		};
		tab.add(stepper);
		fields.push({refresh: function() stepper.value = get()});
		return stepper;
	}

	function checkField(tab:FlxSpriteGroup, x:Float, y:Float, name:String, get:Void->Bool, set:Bool->Void):PsychUICheckBox
	{
		var check:PsychUICheckBox = new PsychUICheckBox(x, y, name, 90);
		check.onClick = function()
		{
			set(check.checked);
			changed(true);
		};
		tab.add(check);
		fields.push({refresh: function() check.checked = get()});
		return check;
	}

	function dropField(dropdowns:Array<PsychUIDropDownMenu>, tab:FlxSpriteGroup, x:Float, y:Float, width:Float, name:String, list:Array<String>, get:Void->String, set:String->Void):PsychUIDropDownMenu
	{
		label(tab, x, y, name);
		var drop:PsychUIDropDownMenu = new PsychUIDropDownMenu(x, y, list, function(id:Int, value:String)
		{
			if(refreshing) return;
			set(value);
			changed(true);
		}, width);
		dropdowns.push(drop);
		fields.push({refresh: function() drop.selectedLabel = get()});
		return drop;
	}

	static inline final BLUE:FlxColor = 0xFF2F6FD0;
	static inline final GREEN:FlxColor = 0xFF2E9E44;
	static inline final RED:FlxColor = 0xFFC93636;

	function button(tab:FlxSpriteGroup, x:Float, y:Float, text:String, onClick:Void->Void, ?width:Int = 110, ?color:Null<FlxColor>):PsychUIButton
	{
		var btn:PsychUIButton = new PsychUIButton(x, y, text, onClick, width);
		if(color != null)
		{
			btn.normalStyle = {bgColor: color, textColor: FlxColor.WHITE, bgAlpha: 1};
			btn.hoverStyle = {bgColor: color.getLightened(0.3), textColor: FlxColor.WHITE, bgAlpha: 1};
			btn.clickStyle = {bgColor: color.getDarkened(0.3), textColor: FlxColor.WHITE, bgAlpha: 1};
			btn.bg.color = color;
			btn.bg.alpha = 1;
			btn.text.color = FlxColor.WHITE;
		}
		tab.add(btn);
		return btn;
	}

	static inline function setField(obj:Dynamic, field:String, value:Dynamic)
	{
		if(value == null || value == '') Reflect.deleteField(obj, field);
		else Reflect.setField(obj, field, value);
	}

	static function stringOf(value:Dynamic):String
		return (value == null) ? '' : Std.string(value);

	static function parseValue(text:String):Dynamic
	{
		text = text.trim();
		if(text.length < 1) return null;
		if(text == 'true') return true;
		if(text == 'false') return false;
		var number:Float = Std.parseFloat(text);
		return Math.isNaN(number) ? text : number;
	}

	static inline function col(c:Int):Float
		return 10 + c * 120;

	static inline function span(n:Int):Int
		return 108 + (n - 1) * 120;

	static inline function row(r:Float):Float
		return 32 + r * 52;

	function header(tab:FlxSpriteGroup, y:Float, text:String)
	{
		var line:FlxSprite = new FlxSprite(10, y + 6).makeGraphic(span(3), 1, 0x60FFFFFF);
		tab.add(line);
		var title:FlxText = new FlxText(10, y - 6, span(3), text);
		title.color = 0xFFFFE47A;
		tab.add(title);
	}

	function addSceneUI()
	{
		var tab = UI_box.getTab('Scene').menu;
		var drops:Array<PsychUIDropDownMenu> = [];

		dropField(drops, tab, col(0), row(0), span(1) - 20, 'Type:', DialogueData.SCENE_TYPES, () -> scene().scene, function(v) scene().scene = v);
		inputField(tab, col(1), row(0), span(1), 'Character:', () -> scene().character, function(v)
		{
			setField(scene(), 'character', v.trim());
			if(v.trim().length > 0) selectCharacter(v.trim());
		});
		portraitDropDown = dropField(drops, tab, col(2), row(0), span(1) - 20, 'Portrait:', [''], () -> scene().portrait, function(v) setField(scene(), 'portrait', v));

		var textInput:PsychUIInputText = inputField(tab, col(0), row(1), span(3), 'Text (Shift+Enter = new line):', () -> scene().text, function(v) setField(scene(), 'text', v));
		textInput.onPressEnter = function(e)
		{
			if(e.shiftKey)
			{
				textInput.text += '\n';
				textInput.caretIndex++;
			}
			else PsychUIInputText.focusOn = null;
		};

		stepperField(tab, col(0), row(2), 'Speed (0 = style):', 0.005, 0, 1, 3, () -> (scene().speed != null) ? scene().speed : 0, function(v) setField(scene(), 'speed', (v > 0) ? v : null));
		inputField(tab, col(1), row(2), span(1), 'Font (empty = default):', () -> scene().font, function(v) setField(scene(), 'font', v.trim()));
		stepperField(tab, col(2), row(2), 'Size (0 = default):', 1, 0, 200, 0, () -> (scene().size != null) ? scene().size : 0, function(v) setField(scene(), 'size', (v > 0) ? Std.int(v) : null));

		dropField(drops, tab, col(0), row(3), span(1) - 20, 'Advance:', SKIP_MODES, function()
		{
			var skip:Dynamic = scene().skipDialog;
			return (skip == true) ? SKIP_MODES[1] : ((skip != null && skip != false) ? SKIP_MODES[2] : SKIP_MODES[0]);
		}, function(v)
		{
			var old:Dynamic = scene().skipDialog;
			var value:Dynamic = null;
			if(v == SKIP_MODES[1]) value = true;
			else if(v == SKIP_MODES[2]) value = (Std.isOfType(old, Float) || Std.isOfType(old, Int)) ? old : 1;
			setField(scene(), 'skipDialog', value);
		});
		stepperField(tab, col(1), row(3), 'Delay (s):', 0.05, 0, 30, 2, function()
		{
			var skip:Dynamic = scene().skipDialog;
			return (Std.isOfType(skip, Float) || Std.isOfType(skip, Int)) ? skip : 0;
		}, function(v)
		{
			var skip:Dynamic = scene().skipDialog;
			if(Std.isOfType(skip, Float) || Std.isOfType(skip, Int)) setField(scene(), 'skipDialog', v);
		});

		dropField(drops, tab, col(0), row(4), span(1) - 20, 'Effects:', FX_LABELS, function()
		{
			var fx:Dynamic = scene().fx;
			if(fx == null) return 'None';
			var mode:String = Std.isOfType(fx, Array) ? Std.string((fx:Array<Dynamic>)[0]) : Std.string(fx);
			return (FX_MODES.indexOf(mode) > -1) ? FX_LABELS[FX_MODES.indexOf(mode)] : mode;
		}, function(v) setFxPart(0, (v == 'None') ? null : ((FX_LABELS.indexOf(v) > -1) ? FX_MODES[FX_LABELS.indexOf(v)] : v)));
		inputField(tab, col(1), row(4), span(1), 'Value 1:', () -> fxPart(1), function(v) setFxPart(1, parseValue(v)));
		inputField(tab, col(2), row(4), span(1), 'Value 2:', () -> fxPart(2), function(v) setFxPart(2, parseValue(v)));

		stepperField(tab, col(0), row(5), 'Pitch (0 = char):', 0.05, 0, 4, 2, () -> (scene().voicePitch != null) ? scene().voicePitch : 0, function(v) setField(scene(), 'voicePitch', (v > 0) ? v : null));
		stepperField(tab, col(1), row(5), 'Count (0 = char):', 1, 0, 20, 0, () -> (scene().voiceStep != null) ? scene().voiceStep : 0, function(v) setField(scene(), 'voiceStep', (v > 0) ? Std.int(v) : null));

		header(tab, row(6) - 16, 'Fade / Wait / Free / Ending');
		inputField(tab, col(0), row(6.5), span(1), 'Fade Target (IDs):', function()
		{
			var target:Dynamic = scene().target;
			return Std.isOfType(target, Array) ? (target:Array<Dynamic>).join(',') : stringOf(target);
		}, function(v)
		{
			var parts:Array<String> = [for (part in v.split(',')) if(part.trim().length > 0) part.trim()];
			setField(scene(), 'target', (parts.length > 1) ? parts : (parts.length == 1 ? parts[0] : null));
		});
		stepperField(tab, col(1), row(6.5), 'Alpha:', 0.05, 0, 1, 2, () -> (scene().alpha != null) ? scene().alpha : 1, function(v) scene().alpha = v);
		stepperField(tab, col(2), row(6.5), 'Duration (s):', 0.1, 0, 60, 2, () -> (scene().duration != null) ? scene().duration : 1, function(v) scene().duration = v);
		inputField(tab, col(0), row(7.5), span(2), 'Free Scene Name (Custom):', () -> scene().custom, function(v) setField(scene(), 'custom', v.trim()));
		checkField(tab, col(0), row(8.3), 'Keep Text', () -> scene().keepText == true, function(v) setField(scene(), 'keepText', v ? true : null));
		checkField(tab, col(1), row(8.3), 'Fade (Ending)', () -> scene().fade == true, function(v) setField(scene(), 'fade', v ? true : null));

		header(tab, row(9.2) - 10, 'Scenes');
		button(tab, col(0), row(9.4), 'Duplicate', function() insertScene(copy(scene()), curScene + 1), span(1), BLUE);
		button(tab, col(1), row(9.4), 'Add', function() insertScene({scene: 'normal', character: charId, portrait: '', text: ''}, curScene + 1), span(1), GREEN);
		button(tab, col(2), row(9.4), 'Remove', removeScene, span(1), RED);
		button(tab, col(0), row(10.1), 'Move Up', function() moveScene(-1), span(1));
		button(tab, col(1), row(10.1), 'Move Down', function() moveScene(1), span(1));

		drops.reverse();
		for (drop in drops) tab.add(drop);
	}

	function fxPart(index:Int):String
	{
		var fx:Dynamic = scene().fx;
		if(fx == null) return '';
		if(!Std.isOfType(fx, Array)) return (index == 0) ? Std.string(fx) : '';
		return stringOf((fx:Array<Dynamic>)[index]);
	}

	function setFxPart(index:Int, value:Dynamic)
	{
		var fx:Dynamic = scene().fx;
		var list:Array<Dynamic> = Std.isOfType(fx, Array) ? (fx:Array<Dynamic>).copy() : (fx != null ? [fx] : [null]);
		while(list.length <= index) list.push(null);
		list[index] = value;
		if(list[0] == null)
		{
			Reflect.deleteField(scene(), 'fx');
			return;
		}
		while(list.length > 1 && list[list.length - 1] == null) list.pop();
		scene().fx = (list.length == 1) ? list[0] : list;
	}

	function audioOf(field:String, create:Bool):DialogueAudio
	{
		var audio:DialogueAudio = Reflect.field(scene(), field);
		if(audio == null && create)
		{
			audio = {name: ''};
			Reflect.setField(scene(), field, audio);
		}
		return audio;
	}

	function audioUI(tab:FlxSpriteGroup, drops:Array<PsychUIDropDownMenu>, start:Float, field:String, title:String, folder:String, extra:Bool)
	{
		header(tab, row(start) - 16, title);
		checkField(tab, col(0), row(start) - 4, 'Change Music/Sounds', () -> audioOf(field, false) != null, function(v)
		{
			if(v) audioOf(field, true);
			else Reflect.deleteField(scene(), field);
		});
		inputField(tab, col(0), row(start + 0.7), span(2), 'File in $folder (empty = stop):', () -> (audioOf(field, false) != null) ? audioOf(field, false).name : '', function(v) audioOf(field, true).name = v.trim());
		stepperField(tab, col(2), row(start + 0.7), 'Volume:', 0.05, 0, 1, 2, function()
		{
			var audio:DialogueAudio = audioOf(field, false);
			return (audio != null && audio.volume != null) ? audio.volume : (field == 'track' ? 0.4 : 1);
		}, function(v) audioOf(field, true).volume = v);
		dropField(drops, tab, col(0), row(start + 1.7), span(1) - 20, 'Fade:', FADE_MODES, function()
		{
			var audio:DialogueAudio = audioOf(field, false);
			return (audio != null && audio.fade != null) ? audio.fade : 'None';
		}, function(v) setField(audioOf(field, true), 'fade', (v == 'None') ? null : v));
		stepperField(tab, col(1), row(start + 1.7), 'Fade Time (s):', 0.1, 0, 30, 2, function()
		{
			var audio:DialogueAudio = audioOf(field, false);
			return (audio != null && audio.fadeTime != null) ? audio.fadeTime : 0;
		}, function(v) setField(audioOf(field, true), 'fadeTime', (v > 0) ? v : null));
		stepperField(tab, col(2), row(start + 1.7), 'Pitch:', 0.05, 0.05, 4, 2, function()
		{
			var audio:DialogueAudio = audioOf(field, false);
			return (audio != null && audio.pitch != null) ? audio.pitch : 1;
		}, function(v) setField(audioOf(field, true), 'pitch', (v != 1) ? v : null));
		if(!extra) return;
		stepperField(tab, col(0), row(start + 2.7), 'Delay (s):', 0.1, 0, 30, 2, function()
		{
			var audio:DialogueAudio = audioOf(field, false);
			return (audio != null && audio.delay != null) ? audio.delay : 0;
		}, function(v) setField(audioOf(field, true), 'delay', (v > 0) ? v : null));
		stepperField(tab, col(1), row(start + 2.7), 'Stop After (0 = Infinite):', 0.1, 0, 60, 2, function()
		{
			var audio:DialogueAudio = audioOf(field, false);
			return (audio != null && audio.life != null) ? audio.life : 0;
		}, function(v) setField(audioOf(field, true), 'life', (v > 0) ? v : null));
	}

	function addAudioUI()
	{
		var tab = UI_box.getTab('Audio').menu;
		var drops:Array<PsychUIDropDownMenu> = [];
		audioUI(tab, drops, 0.4, 'track', 'Track (Loop)', 'music/', false);
		audioUI(tab, drops, 3.6, 'sfx', 'Sound', 'sounds/', true);
		header(tab, row(7.6) - 16, 'All Dialogue');
		inputField(tab, col(0), row(7.9), span(2), 'Music (if not present):', () -> data.music, function(v) setField(data, 'music', v.trim()));
		var note:FlxText = new FlxText(col(0), row(8.6), span(3), 'Without Change Music/Sounds, both will not\nchange next scene.');
		note.alpha = 0.7;
		tab.add(note);
		drops.reverse();
		for (drop in drops) tab.add(drop);
	}

	function animation():DialogueAnimation
	{
		var list:Array<DialogueAnimation> = character().animations;
		return (list.length > 0) ? list[Std.int(FlxMath.bound(curAnim, 0, list.length - 1))] : null;
	}

	function addCharacterUI()
	{
		var tab = UI_box.getTab('Character').menu;
		var drops:Array<PsychUIDropDownMenu> = [];
		var charInput:PsychUIInputText = null;
		charInput = inputField(tab, col(0), row(0), span(1), 'Char ID:', () -> charId, function(v) {}, false);
		button(tab, col(1), row(0) - 2, 'Edit', function() {
			selectCharacter(charInput.text);
			changed(true);
			showMessage('Editing character: $charId');
		}, span(1));
		button(tab, col(2), row(0) - 2, 'Load File', loadCharacter, span(1));

		inputField(tab, col(0), row(1), span(1), 'Display Name:', () -> character().name, function(v) character().name = v);
		inputField(tab, col(1), row(1), span(2), 'Portrait (images/):', () -> character().portrait, function(v) character().portrait = v.trim());

		stepperField(tab, col(0), row(2), 'Scale X:', 0.05, 0.05, 10, 2, () -> pointOf(character().scale, 0, 1), function(v) character().scale = setPoint(character().scale, 0, v, 1));
		stepperField(tab, col(1), row(2), 'Scale Y:', 0.05, 0.05, 10, 2, () -> pointOf(character().scale, 1, 1), function(v) character().scale = setPoint(character().scale, 1, v, 1));
		checkField(tab, col(2), row(2) - 2, 'Flip X', () -> character().flipX == true, function(v) character().flipX = v);

		stepperField(tab, col(0), row(3), 'X:', 5, -3000, 3000, 0, () -> pointOf(character().position, 0, 0), function(v) character().position = setPoint(character().position, 0, v, 0));
		stepperField(tab, col(1), row(3), 'Y:', 5, -3000, 3000, 0, () -> pointOf(character().position, 1, 0), function(v) character().position = setPoint(character().position, 1, v, 0));
		stepperField(tab, col(2), row(3), 'Size (0 = style):', 1, 0, 200, 0, () -> (character().textSize != null) ? character().textSize : 0, function(v) setField(character(), 'textSize', (v > 0) ? Std.int(v) : null));

		colorField(tab, col(0), row(4), span(1), 'Box Color:', () -> character().boxColor, function(v) setField(character(), 'boxColor', v.trim()));
		colorField(tab, col(1), row(4), span(1), 'Name Color:', () -> character().nameColor, function(v) setField(character(), 'nameColor', v.trim()));
		inputField(tab, col(2), row(4), span(1), 'Font (empty = style):', () -> character().font, function(v) setField(character(), 'font', v.trim()));
		var colorNote:FlxText = new FlxText(col(0), row(4) + 18, span(3), 'Colors: hex, bf/dad/gf, char name (JSON)');
		colorNote.alpha = 0.7;
		tab.add(colorNote);

		stepperField(tab, col(0), row(5.3), 'Nametag Width:', 5, 0, 1280, 0, () -> (character().nametagWidth != null) ? character().nametagWidth : 300, function(v) character().nametagWidth = v);
		stepperField(tab, col(1), row(5.3), 'Nametag X:', 5, -1280, 1280, 0, () -> pointOf(character().nametagPosition, 0, 50), function(v) character().nametagPosition = setPoint(character().nametagPosition, 0, v, 0));
		stepperField(tab, col(2), row(5.3), 'Nametag Y:', 5, -720, 720, 0, () -> pointOf(character().nametagPosition, 1, -80), function(v) character().nametagPosition = setPoint(character().nametagPosition, 1, v, 0));
		stepperField(tab, col(1), row(6.3), 'Name X:', 5, -1280, 1280, 0, () -> pointOf(character().namePosition, 0, 70), function(v) character().namePosition = setPoint(character().namePosition, 0, v, 0));
		stepperField(tab, col(2), row(6.3), 'Name Y:', 5, -720, 720, 0, () -> pointOf(character().namePosition, 1, -75), function(v) character().namePosition = setPoint(character().namePosition, 1, v, 0));
		inputField(tab, col(0), row(6.3), span(1), 'Voice (sounds/):', () -> character().voice, function(v) character().voice = v.trim());
		stepperField(tab, col(0), row(7.3), 'Voice every N letters:', 1, 1, 20, 0, () -> (character().voiceStep != null) ? character().voiceStep : 1, function(v) character().voiceStep = Std.int(v));
		stepperField(tab, col(1), row(7.3), 'Pitch:', 0.05, 0.1, 4, 2, () -> (character().voicePitch != null) ? character().voicePitch : 1, function(v) character().voicePitch = v);

		header(tab, row(8.3) - 16, 'Animations (Ctrl+Arrows = offset, Shift = 10x)');
		animDropDown = dropField(drops, tab, col(0), row(8.5), span(1) - 20, 'Animation:', [''], function()
		{
			var anim:DialogueAnimation = animation();
			return (anim != null) ? anim.name : '';
		}, function(v)
		{
			for (i => anim in character().animations) if(anim.name == v) curAnim = i;
			previewAnimation();
		});
		inputField(tab, col(1), row(8.5), span(1), 'Name:', () -> (animation() != null) ? animation().name : '', function(v) if(animation() != null) animation().name = v.trim());
		inputField(tab, col(2), row(8.5), span(1), 'Prefix (.xml):', () -> (animation() != null) ? animation().prefix : '', function(v) if(animation() != null) animation().prefix = v);
		stepperField(tab, col(0), row(9.5), 'FPS:', 1, 1, 120, 0, () -> (animation() != null && animation().fps != null) ? animation().fps : 24, function(v) if(animation() != null) animation().fps = v);
		checkField(tab, col(1), row(9.5) - 2, 'Loop', () -> animation() != null && animation().loop == true, function(v) if(animation() != null) animation().loop = v);
		button(tab, col(0), row(10.2), 'Add Anim', function()
		{
			character().animations.push({name: 'anim' + character().animations.length, prefix: '', fps: 24, loop: false, offsets: [0, 0]});
			curAnim = character().animations.length - 1;
			changed(true);
		}, span(1), GREEN);
		button(tab, col(1), row(10.2), 'Remove Anim', function()
		{
			if(animation() == null) return;
			character().animations.remove(animation());
			curAnim = 0;
			changed(true);
		}, span(1), RED);

		drops.reverse();
		for (drop in drops) tab.add(drop);
	}

	static function pointOf(point:Array<Float>, index:Int, fallback:Float):Float
		return (point != null && point.length > index) ? point[index] : fallback;

	static function setPoint(point:Array<Float>, index:Int, value:Float, fallback:Float):Array<Float>
	{
		if(point == null) point = [fallback, fallback];
		while(point.length < 2) point.push(fallback);
		point[index] = value;
		return point;
	}

	function background():DialogueBackground
		return (data.backgrounds.length > 0) ? data.backgrounds[Std.int(FlxMath.bound(curBackground, 0, data.backgrounds.length - 1))] : null;

	function addStyleUI()
	{
		var tab = UI_box.getTab('Style').menu;
		var drops:Array<PsychUIDropDownMenu> = [];
		var styleInput:PsychUIInputText = null;
		styleInput = inputField(tab, col(0), row(0), span(1), 'Style file name:', () -> styleName, function(v) {}, false);
		button(tab, col(1), row(0) - 2, 'Use Style', function()
		{
			var name:String = styleInput.text.trim();
			if(name.length < 1) return;
			data.style = name;
			setDialogueStyle(name);
		}, span(1));
		stepperField(tab, col(2), row(0), 'Box X:', 5, -1280, 1280, 0, () -> (style.boxX != null) ? style.boxX : ((preview != null && preview.box != null) ? preview.box.x : 0), function(v) style.boxX = v);

		inputField(tab, col(0), row(1), span(1), 'Box image:', () -> style.box, function(v) setField(style, 'box', v.trim()));
		inputField(tab, col(1), row(1), span(1), 'Overlay image:', () -> style.overlay, function(v) setField(style, 'overlay', v.trim()));
		stepperField(tab, col(2), row(1), 'Box Y:', 5, -720, 720, 0, () -> (style.boxY != null) ? style.boxY : 430, function(v) style.boxY = v);

		inputField(tab, col(0), row(2), span(1), 'Text Font:', () -> style.font, function(v) setField(style, 'font', v.trim()));
		stepperField(tab, col(1), row(2), 'Text Size:', 1, 1, 200, 0, () -> (style.textSize != null) ? style.textSize : 40, function(v) style.textSize = Std.int(v));
		stepperField(tab, col(2), row(2), 'Centered Size:', 1, 1, 200, 0, () -> (style.singleTextSize != null) ? style.singleTextSize : 40, function(v) style.singleTextSize = Std.int(v));

		stepperField(tab, col(0), row(3), 'Text X:', 5, -1280, 1280, 0, () -> pointOf(style.textOffset, 0, 50), function(v) style.textOffset = setPoint(style.textOffset, 0, v, 0));
		stepperField(tab, col(1), row(3), 'Text Y:', 5, -720, 720, 0, () -> pointOf(style.textOffset, 1, 45), function(v) style.textOffset = setPoint(style.textOffset, 1, v, 0));
		stepperField(tab, col(2), row(3), 'Text Width:', 10, 10, 1280, 0, () -> (style.textWidth != null) ? style.textWidth : 1100, function(v) style.textWidth = Std.int(v));

		stepperField(tab, col(0), row(4), 'Speed:', 0.005, 0.001, 1, 3, () -> (style.speed != null) ? style.speed : 0.05, function(v) style.speed = v);
		stepperField(tab, col(1), row(4), 'Voice Volume:', 0.05, 0, 1, 2, () -> (style.voiceVolume != null) ? style.voiceVolume : 0.75, function(v) style.voiceVolume = v);
		stepperField(tab, col(2), row(4), 'Voice Gap (s):', 0.01, 0, 1, 2, () -> (style.minVoiceGap != null) ? style.minVoiceGap : 0.05, function(v) style.minVoiceGap = v);

		inputField(tab, col(0), row(5), span(1), 'Name Font:', () -> style.nameFont, function(v) setField(style, 'nameFont', v.trim()));
		stepperField(tab, col(1), row(5), 'Name Size:', 1, 1, 200, 0, () -> (style.nameSize != null) ? style.nameSize : 75, function(v) style.nameSize = Std.int(v));
		colorField(tab, col(2), row(5), span(1), 'Nametag Color:', () -> style.nametagColor, function(v) setField(style, 'nametagColor', v.trim()));

		stepperField(tab, col(0), row(6), 'Text Border:', 0.5, 0, 10, 1, () -> (style.borderSize != null) ? style.borderSize : 2, function(v) style.borderSize = v);
		colorField(tab, col(1), row(6), span(1), 'Border Color:', () -> style.borderColor, function(v) setField(style, 'borderColor', v.trim()));
		inputField(tab, col(2), row(6), span(1), 'Skip Key:', () -> style.skipKey, function(v) setField(style, 'skipKey', v.trim().toUpperCase()));

		inputField(tab, col(0), row(7), span(2), 'Hint Text:', () -> style.hint, function(v) setField(style, 'hint', v));
		inputField(tab, col(2), row(7), span(1), 'Hint Font:', () -> style.hintFont, function(v) setField(style, 'hintFont', v.trim()));
		inputField(tab, col(0), row(8), span(2), 'Skip Text:', () -> style.skipHint, function(v) setField(style, 'skipHint', v));
		inputField(tab, col(2), row(8), span(1), 'Skip Font:', () -> style.skipHintFont, function(v) setField(style, 'skipHintFont', v.trim()));

		header(tab, row(9) - 16, 'Backgrounds ("black" = black screen on top)');
		backgroundDropDown = dropField(drops, tab, col(0), row(9.2), span(1) - 20, 'Background:', [''], function()
		{
			var bg:DialogueBackground = background();
			return (bg != null) ? bg.id : '';
		}, function(v)
		{
			for (i => bg in data.backgrounds) if(bg.id == v) curBackground = i;
		});
		inputField(tab, col(1), row(9.2), span(1), 'ID:', () -> (background() != null) ? background().id : '', function(v) if(background() != null) background().id = v.trim());
		inputField(tab, col(2), row(9.2), span(1), 'Image/Color:', () -> (background() != null) ? background().image : '', function(v) if(background() != null) setField(background(), 'image', v.trim()));
		colorField(tab, col(0), row(10.2), span(1), 'Background Color:', () -> (background() != null) ? background().color : '', function(v) if(background() != null) setField(background(), 'color', v.trim()));
		stepperField(tab, col(1), row(10.2), 'Start Alpha:', 0.05, 0, 1, 2, () -> (background() != null && background().alpha != null) ? background().alpha : 1, function(v) if(background() != null) background().alpha = v);
		button(tab, col(0), row(10.9), 'Add BG', function()
		{
			data.backgrounds.push({id: 'bg' + data.backgrounds.length, color: '000000', alpha: 1});
			curBackground = data.backgrounds.length - 1;
			changed(true);
		}, span(1), GREEN);
		button(tab, col(1), row(10.9), 'Remove BG', function()
		{
			if(background() == null) return;
			data.backgrounds.remove(background());
			curBackground = 0;
			changed(true);
		}, span(1), RED);

		drops.reverse();
		for (drop in drops) tab.add(drop);
	}

	function setDialogueStyle(name:String)
	{
		styleName = name;
		DialogueData.styleOverrides.remove(name);
		style = copy(DialogueData.style(name));
		DialogueData.styleOverrides.set(name, style);
		changed(true);
		showMessage('Using style: $name');
	}

	function changed(rebuild:Bool)
	{
		unsaved = true;
		if(rebuild) rebuildQueued = true;
	}

	function refreshFields()
	{
		refreshing = true;
		var anims:Array<String> = [for (anim in character().animations) anim.name];
		animDropDown.list = (anims.length > 0) ? anims : [''];
		var sceneChar:DialogueCharacterData = (scene().character != null) ? DialogueData.character(scene().character) : null;
		var portraits:Array<String> = (sceneChar != null && sceneChar.animations != null) ? [for (anim in sceneChar.animations) anim.name] : [];
		portraitDropDown.list = (portraits.length > 0) ? portraits : [''];
		var bgs:Array<String> = [for (bg in data.backgrounds) bg.id];
		backgroundDropDown.list = (bgs.length > 0) ? bgs : [''];
		for (field in fields) field.refresh();
		refreshing = false;
		updateInfo();
	}

	function updateInfo()
	{
		var lines:Array<String> = ['Scene ${curScene + 1} / ${data.scenes.length}   Character: $charId   Style: $styleName${unsaved ? "   (UNSAVED)" : ""}'];
		for (i in Std.int(Math.max(0, curScene - 2))...Std.int(Math.min(data.scenes.length, curScene + 4)))
		{
			var s:DialogueScene = data.scenes[i];
			var summary:String = '${i + 1}. [${s.scene}]';
			if(s.character != null) summary += ' ${s.character}' + ((s.portrait != null && s.portrait.length > 0) ? ' (${s.portrait})' : '');
			if(s.text != null) summary += ': ' + ((s.text.length > 60) ? s.text.substr(0, 60).replace('\n', ' ') + '...' : s.text.replace('\n', ' '));
			if(s.custom != null) summary += ' "${s.custom}"';
			lines.push(((i == curScene) ? '> ' : '  ') + summary);
		}
		infoText.text = lines.join('\n');
	}

	function rebuildPreview()
	{
		rebuildQueued = false;
		if(preview != null)
		{
			remove(preview, true);
			preview.destroy();
		}
		for (id => info in editedCharacters) DialogueData.characterOverrides.set(id, info);
		data.style = styleName;
		preview = new DialogueCutscene(data, camPreview, 'preview');
		preview.inputEnabled = false;
		preview.playAudio = previewAudio;
		preview.playVoices = !muteVoices;
		preview.onCustom = function(custom:String, s:DialogueScene)
		{
			showMessage('Free scene "$custom": handled by the song script (onDialogueCustom)');
			if(s.duration == null) new FlxTimer().start(1, (_) -> if(preview != null) preview.customDone());
		};
		preview.onFinish = function(faded:Bool) showMessage('Dialogue ended. SPACE to replay.');
		add(preview);
		preview.jumpTo(curScene);
	}

	function previewAnimation()
	{
		if(preview == null) return;
		var port:FlxSprite = preview.portraits.get(charId);
		var anim:DialogueAnimation = animation();
		if(port == null || anim == null || !port.animation.exists(anim.name)) return;
		for (key => other in preview.portraits) other.visible = (key == charId);
		port.animation.play(anim.name, true);
		var offsets:Array<Float> = (anim.offsets != null) ? anim.offsets : [0, 0];
		port.offset.set(pointOf(offsets, 0, 0), pointOf(offsets, 1, 0));
	}

	function changeScene(add:Int)
	{
		curScene = FlxMath.wrap(curScene + add, 0, data.scenes.length - 1);
		var s:DialogueScene = scene();
		if(s.character != null && DialogueData.character(s.character) != null) selectCharacter(s.character);
		refreshFields();
		rebuildPreview();
	}

	function insertScene(s:DialogueScene, index:Int)
	{
		data.scenes.insert(index, s);
		curScene = index;
		unsaved = true;
		refreshFields();
		rebuildPreview();
	}

	function removeScene()
	{
		if(data.scenes.length <= 1)
		{
			showMessage('Dialogue must have one scene.', true);
			return;
		}
		data.scenes.splice(curScene, 1);
		curScene = Std.int(Math.min(curScene, data.scenes.length - 1));
		unsaved = true;
		refreshFields();
		rebuildPreview();
	}

	function moveScene(dir:Int)
	{
		var target:Int = curScene + dir;
		if(target < 0 || target >= data.scenes.length) return;
		var s:DialogueScene = data.scenes[curScene];
		data.scenes[curScene] = data.scenes[target];
		data.scenes[target] = s;
		curScene = target;
		unsaved = true;
		refreshFields();
	}

	override function update(elapsed:Float)
	{
		if(transitioning)
		{
			super.update(elapsed);
			return;
		}

		if(FlxG.mouse.justPressed || FlxG.mouse.justPressedRight)
			FlxG.sound.play(Paths.sound('chartingSounds/ClickDown'), 0.75);
		if(FlxG.mouse.justReleased || FlxG.mouse.justReleasedRight)
			FlxG.sound.play(Paths.sound('chartingSounds/ClickUp'), 0.75);

		if(PsychUIInputText.focusOn == null)
		{
			ClientPrefs.toggleVolumeKeys(true);
			if(FlxG.keys.pressed.CONTROL)
			{
				if(FlxG.keys.justPressed.S) saveDialogue();
				else updateOffsetKeys();
			}
			else if(FlxG.keys.justPressed.ESCAPE)
			{
				exitEditor();
				super.update(elapsed);
				return;
			}
			else updateKeys();
		}
		else ClientPrefs.toggleVolumeKeys(false);

		if(rebuildQueued)
		{
			refreshFields();
			rebuildPreview();
		}
		super.update(elapsed);
	}

	function updateKeys()
	{
		if(FlxG.keys.justPressed.A) changeScene(-1);
		else if(FlxG.keys.justPressed.D) changeScene(1);
		else if(FlxG.keys.justPressed.SPACE) rebuildPreview();
		else if(FlxG.keys.justPressed.ENTER && preview != null) preview.advance();

		var animMove:Int = (FlxG.keys.justPressed.S ? 1 : 0) - (FlxG.keys.justPressed.W ? 1 : 0);
		var sceneChar:DialogueCharacterData = (scene().character != null) ? DialogueData.character(scene().character) : null;
		if(animMove != 0 && sceneChar != null && sceneChar.animations != null && sceneChar.animations.length > 0)
		{
			var names:Array<String> = [for (anim in sceneChar.animations) anim.name];
			var index:Int = names.indexOf(scene().portrait);
			scene().portrait = names[FlxMath.wrap(index + animMove, 0, names.length - 1)];
			changed(true);
		}

		var move:Array<Float> = arrowMove();
		var moveX:Float = move[0];
		var moveY:Float = move[1];
		if(moveX == 0 && moveY == 0) return;

		if(UI_box.selectedName == 'Style')
		{
			if(preview == null || preview.box == null) return;
			style.boxX = preview.box.x + moveX;
			style.boxY = preview.box.y + moveY;
			unsaved = true;
			for (obj in [preview.box, preview.overlay, preview.nametag, preview.nameText, preview.text, preview.hint])
				if(obj != null) obj.setPosition(obj.x + moveX, obj.y + moveY);
			showMessage('Box: [${style.boxX}, ${style.boxY}]');
			refreshFields();
		}
		else
		{
			var info:DialogueCharacterData = character();
			info.position = setPoint(info.position, 0, pointOf(info.position, 0, 0) + moveX, 0);
			info.position = setPoint(info.position, 1, pointOf(info.position, 1, 0) + moveY, 0);
			unsaved = true;
			var port:FlxSprite = (preview != null) ? preview.portraits.get(charId) : null;
			if(port != null) port.setPosition(info.position[0], info.position[1]);
			refreshFields();
		}
	}

	function arrowMove():Array<Float>
	{
		var step:Float = FlxG.keys.pressed.SHIFT ? 10 : 1;
		return [(FlxG.keys.justPressed.RIGHT ? step : 0) - (FlxG.keys.justPressed.LEFT ? step : 0),
			(FlxG.keys.justPressed.DOWN ? step : 0) - (FlxG.keys.justPressed.UP ? step : 0)];
	}

	function updateOffsetKeys()
	{
		var move:Array<Float> = arrowMove();
		if(move[0] == 0 && move[1] == 0) return;

		var anim:DialogueAnimation = null;
		if(UI_box.selectedName == 'Character') anim = animation();
		else if(character().animations != null)
			for (other in character().animations)
				if(other.name == scene().portrait) anim = other;
		if(anim == null) return;

		anim.offsets = setPoint(anim.offsets, 0, pointOf(anim.offsets, 0, 0) - move[0], 0);
		anim.offsets = setPoint(anim.offsets, 1, pointOf(anim.offsets, 1, 0) - move[1], 0);
		unsaved = true;
		if(UI_box.selectedName == 'Character') previewAnimation();
		else
		{
			var port:FlxSprite = (preview != null) ? preview.portraits.get(charId) : null;
			if(port != null) port.offset.set(anim.offsets[0], anim.offsets[1]);
		}
		showMessage('"${anim.name}" Offsets: ${anim.offsets}');
	}

	function exitEditor()
	{
		var leave:Void->Void = function()
		{
			@:privateAccess EditorHelper.cancelEditorMusicTimer();
			DialogueData.characterOverrides.clear();
			DialogueData.styleOverrides.clear();
			transitioning = true;
		};
		if(!unsaved)
		{
			leave();
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			EditorHelper.returnToPreviousState();
		}
		else openSubState(new ExitConfirmationPrompt(leave));
	}

	function showMessage(text:String, ?error:Bool = false)
	{
		messageText.text = text;
		messageText.color = error ? FlxColor.RED : FlxColor.WHITE;
		messageText.alpha = 1;
		FlxTween.cancelTweensOf(messageText);
		FlxTween.tween(messageText, {alpha: 0}, 1, {startDelay: 2.5});
	}

	var upperBox:PsychUIBox;
	var antialiasButton:PsychUIButton;
	function addUpperMenu()
	{
		upperBox = new PsychUIBox(0, 0, 80, 120, ['File']);
		upperBox.scrollFactor.set();
		upperBox.isMinimized = true;
		upperBox.minimizeOnFocusLost = true;
		upperBox.canMove = false;
		upperBox.bg.visible = false;
		upperBox.cameras = [camHUD];
		add(upperBox);

		var entries:Array<Array<Dynamic>> = [
			['  Save (Ctrl+S)', saveDialogue],
			['  Load from JSON', loadDialogue],
			['  Load Template', newDialogue],
			['  Antialiasing: ON', toggleAntialiasing],
			['  Exit (Esc)', exitEditor]
		];
		var menu = upperBox.getTab('File').menu;
		var panel:FlxSprite = new FlxSprite().makeGraphic(200, entries.length * 20 + 2, FlxColor.BLACK);
		panel.alpha = 0.8;
		menu.add(panel);
		for (i => entry in entries)
		{
			var action:Void->Void = entry[1];
			var entryButton:PsychUIButton = new PsychUIButton(0, i * 20, entry[0], function() {
				upperBox.isMinimized = true;
				action();
			}, 200);
			entryButton.text.alignment = LEFT;
			if(i == entries.length - 1) entryButton.text.color = FlxColor.RED;
			if(i == 3) antialiasButton = entryButton;
			menu.add(entryButton);
		}
		refreshAntialiasButton();
	}

	function toggleAntialiasing()
	{
		data.antialiasing = (data.antialiasing == false) ? null : false;
		if(data.antialiasing == null) Reflect.deleteField(data, 'antialiasing');
		refreshAntialiasButton();
		changed(true);
	}

	function refreshAntialiasButton()
	{
		if(antialiasButton != null) antialiasButton.text.text = '  Antialiasing: ' + ((data.antialiasing == false) ? 'OFF' : 'ON');
	}

	function newDialogue()
	{
		var reset:Void->Void = function()
		{
			loadTemplate();
			refreshAntialiasButton();
			refreshFields();
			rebuildPreview();
			showMessage('Template Loaded.');
		};
		if(unsaved) openSubState(new Prompt('Changes were not saved.\nAre you sure?', reset));
		else reset();
	}

	function loadDialogue()
	{
		if(!fileDialog.completed) return;
		fileDialog.open('dialogue.json', 'Load Dialogue', null, function()
		{
			try
			{
				var loaded:Dynamic = Json.parse(fileDialog.data);
				if(DialogueData.validFile(loaded))
				{
					editedCharacters.clear();
					DialogueData.characterOverrides.clear();
					DialogueData.styleOverrides.clear();
					setDialogue(loaded);
					unsaved = false;
					refreshAntialiasButton();
					refreshFields();
					rebuildPreview();
					showMessage('Loaded: ' + Path.withoutDirectory(fileDialog.path));
					return;
				}
			}
			catch(e:Dynamic) {}
			showMessage('ERROR: Invalid Dialogue file', true);
		});
	}

	function loadCharacter()
	{
		if(!fileDialog.completed) return;
		fileDialog.open(null, 'Load Dialogue Character', null, function()
		{
			try
			{
				var loaded:DialogueCharacterData = cast Json.parse(fileDialog.data);
				if(loaded != null && loaded.portrait != null)
				{
					var id:String = Path.withoutExtension(Path.withoutDirectory(fileDialog.path));
					if(loaded.animations == null) loaded.animations = [];
					editedCharacters.set(id, loaded);
					DialogueData.characterOverrides.set(id, loaded);
					charId = id;
					curAnim = 0;
					changed(true);
					showMessage('Loaded Character: $id');
					return;
				}
			}
			catch(e:Dynamic) {}
			showMessage('ERROR: Invalid Dialogue character', true);
		});
	}

	function saveDialogue()
	{
		if(!fileDialog.completed) return;
		data.style = styleName;
		fileDialog.save('dialogue.json', Json.stringify(data, '\t'), function()
		{
			var saved:Int = saveExtras(fileDialog.path);
			unsaved = false;
			updateInfo();
			showMessage('Saved: ' + Path.withoutDirectory(fileDialog.path) + ', style, $saved character' + (saved == 1 ? '' : 's'));
		}, null, function() showMessage('ERROR: Dialogue not saved.', true));
	}

	function saveExtras(dialoguePath:String):Int
	{
		#if sys
		if(dialoguePath == null || dialoguePath.length < 1) return 0;
		var normalized:String = dialoguePath.replace('\\', '/');
		var dataIndex:Int = normalized.lastIndexOf('/data/');
		var root:String = (dataIndex > -1) ? normalized.substr(0, dataIndex) + '/data/' : Path.directory(normalized) + '/';
		var charFolder:String = root + DialogueData.CHARACTER_FOLDER;
		var styleFolder:String = root + DialogueData.STYLE_FOLDER;

		var saved:Int = 0;
		try
		{
			if(!FileSystem.exists(styleFolder)) FileSystem.createDirectory(styleFolder);
			File.saveContent('$styleFolder$styleName.json', Json.stringify(style, '\t'));
			if(!FileSystem.exists(charFolder)) FileSystem.createDirectory(charFolder);
			for (id => info in editedCharacters)
			{
				File.saveContent('$charFolder$id.json', Json.stringify(info, '\t'));
				saved++;
			}
		}
		catch(e:Dynamic)
		{
			showMessage('ERROR: Could not save style/characters: $e', true);
		}
		return saved;
		#else
		return 0;
		#end
	}

	override function destroy()
	{
		DialogueData.characterOverrides.clear();
		DialogueData.styleOverrides.clear();
		super.destroy();
	}
}
