package funkin.editors;

import funkin.data.Song;
import funkin.data.StageData;
import funkin.game.Character;
import funkin.graphics.shaders.ShaderLoader;
import funkin.graphics.shaders.CameraShaders;
import funkin.editors.content.Prompt;
import funkin.editors.content.FileDialogHandler.FileReferenceCustom;

import flixel.addons.display.FlxRuntimeShader;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSpriteUtil;

import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;

typedef ShaderEditorObject = {
	var name:String;
	var sprite:FlxSprite;
	var character:Bool;
}

class ShaderEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	public static inline final RTX_SHADER:String = 'RTXLighting';

	static inline final MIN_ZOOM:Float = 0.1;
	static inline final MAX_ZOOM:Float = 2;
	static inline final BOX_WIDTH:Int = 250;
	static inline final RTX_BOX_WIDTH:Int = 320;
	static inline final DROPDOWN_WIDTH:Int = 150;
	static inline final PICKER_SIZE:Int = 150;
	static inline final BAR_WIDTH:Int = 16;
	static inline final WHEEL_SIZE:Int = 90;
	static inline final RTX_DEFAULT_DISTANCE:Float = 20;

	static final RTX_COLOR_FIELDS:Array<String> = ['overlayColor', 'satinColor', 'innerShadowColor'];
	static final RTX_COLOR_LABELS:Array<String> = ['Overlay', 'Satin', 'Inner Shadow'];
	static final CHARACTER_LABELS:Map<String, String> = ['boyfriend' => 'Boyfriend', 'dad' => 'Opponent', 'gf' => 'Girlfriend'];

	var camGame:FlxCamera;
	var camHUD:FlxCamera;

	var stageJson:StageFile;
	var lastLoadedStage:String;
	var quickSavePath:String = null;
	var quickSaveFromLoad:Bool = true;
	var unsavedProgress:Bool = false;

	var gf:Character;
	var dad:Character;
	var boyfriend:Character;
	var extraCharacters:Array<Character> = [];
	var stageObjects:Array<ShaderEditorObject> = [];
	var characterList:Array<String> = [];

	var shaderEntries:Array<Dynamic> = [];
	var shaderPreviews:Array<FlxRuntimeShader> = [];
	var curShaderEntry:Int = -1;
	var shaderUniforms:Array<ShaderUniform> = [];
	var showShaders:Bool = true;
	var rtxMode:Bool = false;
	var hudVisible:Bool = true;

	var stageBox:PsychUIBox;
	var shaderBox:PsychUIBox;
	var rtxBox:PsychUIBox;

	var stageDropDown:PsychUIDropDownMenu;
	var oppDropDown:PsychUIDropDownMenu;
	var gfDropDown:PsychUIDropDownMenu;
	var bfDropDown:PsychUIDropDownMenu;

	var shaderEntryDropDown:PsychUIDropDownMenu;
	var shaderTargetDropDown:PsychUIDropDownMenu;
	var shaderFileDropDown:PsychUIDropDownMenu;
	var shaderUniformDropDown:PsychUIDropDownMenu;
	var shaderNameInput:PsychUIInputText;
	var shaderValueInput:PsychUIInputText;
	var shaderEnabledCheckbox:PsychUICheckBox;
	var shaderValueText:FlxText;

	var rtxTarget:String = 'boyfriend';
	var rtxColorIndex:Int = 0;
	var rtxCharacterDropDown:PsychUIDropDownMenu;
	var rtxAnimationDropDown:PsychUIDropDownMenu;
	var rtxInfoText:FlxText;
	var rtxSummaryText:FlxText;
	var rtxColorRadio:PsychUIRadioGroup;
	var rtxHexInput:PsychUIInputText;
	var rtxAlphaInput:PsychUIInputText;
	var rtxAngleSlider:PsychUISlider;
	var rtxDistanceSlider:PsychUISlider;
	var pickerSprite:FlxSprite;
	var pickerDot:FlxSprite;
	var hueSprite:FlxSprite;
	var hueLine:FlxSprite;
	var alphaSprite:FlxSprite;
	var alphaLine:FlxSprite;
	var swatchSprite:FlxSprite;
	var wheelSprite:FlxSprite;
	var wheelDot:FlxSprite;
	var pickerHue:Float = 0;
	var pickerSaturation:Float = 0;
	var pickerBrightness:Float = 0;
	var pickerAlpha:Float = 0;
	var pickerDragging:Int = 0;

	var selectionSprites:FlxSpriteGroup = new FlxSpriteGroup();
	var showSelection:Bool = true;
	var camDragging:Bool = false;
	var skipMouseDelta:Bool = false;

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	var outputTxt:FlxText;
	var outputTime:Float = 0;

	var _file:FileReference;

	public function new(stageToLoad:String = 'stage')
	{
		lastLoadedStage = stageToLoad;
		super();
	}

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		#if DISCORD_ALLOWED
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		DiscordClient.changePresence('Shader Editor', 'Stage: ' + lastLoadedStage);
		#end

		var stages:Array<String> = stageList();
		if(!stages.contains(lastLoadedStage) && stages.length > 0 && stages[0].length > 0) lastLoadedStage = stages[0];
		stageJson = StageData.getStageFile(lastLoadedStage);
		quickSavePath = stageFilePath(lastLoadedStage);
		quickSaveFromLoad = true;
		FlxG.camera.follow(null, LOCKON, 0);
		loadJsonAssetDirectory();

		characterList = findCharacters();
		gf = new Character(0, 0, metaCharacter('gf', 'gf'));
		dad = new Character(0, 0, metaCharacter('dad', 'dad'));
		boyfriend = new Character(0, 0, metaCharacter('boyfriend', 'bf'), true);

		for (i in 0...4)
		{
			var spr:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.LIME);
			spr.alpha = 0.8;
			selectionSprites.add(spr);
		}

		createUI();
		buildStage();
		loadShaderEntries();
		resetCamera();
		addHelpScreen();

		FlxG.mouse.visible = true;
		if(FlxG.sound.music != null && FlxG.sound.music.playing)
			FlxG.sound.music.fadeOut(0.6, 0);
		EditorHelper.scheduleEditorMusic(10);

		super.create();
	}

	function metaCharacter(field:String, fallback:String):String
	{
		var name:Dynamic = (stageJson._editorMeta != null) ? Reflect.field(stageJson._editorMeta, field) : null;
		return (name != null && Std.string(name).length > 0) ? Std.string(name) : fallback;
	}

	function loadJsonAssetDirectory()
	{
		var directory:String = 'shared';
		var weekDir:String = stageJson.directory;
		if (weekDir != null && weekDir.length > 0) directory = weekDir;
		Paths.setCurrentLevel(directory);
	}

	function stageFilePath(name:String):String
	{
		var path:String = Paths.getPath('stages/$name.json', TEXT, null, true);
		return FileSystem.exists(path) ? path : null;
	}

	function stageList():Array<String>
	{
		var list:Array<String> = [];
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'stages/'))
			for (file in FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
				{
					var name:String = file.substr(0, file.length - '.json'.length);
					if(StageData.editorHiddenStages.contains(name)) continue;
					if(!list.contains(name)) list.push(name);
				}
		if(list.length < 1) list.push('');
		return list;
	}

	function findCharacters():Array<String>
	{
		var list:Array<String> = Mods.mergeAllTextsNamed('data/characterList.txt');
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'characters/'))
			for (file in FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
				{
					var name:String = file.substr(0, file.length - 5);
					if(!list.contains(name)) list.push(name);
				}
		if(list.length < 1) list.push('');
		return list;
	}

	function createUI()
	{
		stageBox = new PsychUIBox(25, 10, BOX_WIDTH, 160, ['Stage', 'Characters']);
		stageBox.cameras = [camHUD];
		stageBox.scrollFactor.set();
		add(stageBox);
		addStageTab();
		addCharactersTab();
		stageBox.selectedName = 'Stage';

		shaderBox = new PsychUIBox(FlxG.width - BOX_WIDTH - 25, 10, BOX_WIDTH, 580, ['Shaders']);
		shaderBox.cameras = [camHUD];
		shaderBox.scrollFactor.set();
		add(shaderBox);
		addShadersTab();
		shaderBox.selectedName = 'Shaders';

		rtxBox = new PsychUIBox(FlxG.width - RTX_BOX_WIDTH - 25, 10, RTX_BOX_WIDTH, 620, ['Lighting Editor']);
		rtxBox.cameras = [camHUD];
		rtxBox.scrollFactor.set();
		add(rtxBox);
		addRtxTab();
		rtxBox.selectedName = 'Lighting Editor';
		refreshBoxes();

		var bg:FlxSprite = new FlxSprite(0, FlxG.height - 40).makeGraphic(1, 1, FlxColor.BLACK);
		bg.cameras = [camHUD];
		bg.alpha = 0.4;
		bg.scale.set(FlxG.width, 40);
		bg.updateHitbox();
		add(bg);

		var tipText:FlxText = new FlxText(0, FlxG.height - 32, 300, 'Press F1 for Help', 20);
		tipText.alignment = CENTER;
		tipText.cameras = [camHUD];
		tipText.scrollFactor.set();
		tipText.screenCenter(X);
		tipText.active = false;
		add(tipText);

		outputTxt = new FlxText(0, 0, 800, '', 24);
		outputTxt.alignment = CENTER;
		outputTxt.borderStyle = OUTLINE_FAST;
		outputTxt.borderSize = 1;
		outputTxt.cameras = [camHUD];
		outputTxt.screenCenter();
		outputTxt.alpha = 0;
		add(outputTxt);
	}

	function addStageTab()
	{
		var tab_group = stageBox.getTab('Stage').menu;

		stageDropDown = new PsychUIDropDownMenu(10, 30, [''], function(id:Int, name:String) {
			if(name.length < 1 || name == lastLoadedStage) return;
			if(unsavedProgress)
			{
				var previous:String = lastLoadedStage;
				openSubState(new Prompt('There\'s unsaved progress,\nload "$name" anyway?', function() loadStage(name), function() stageDropDown.selectedLabel = previous));
				return;
			}
			loadStage(name);
		});
		stageDropDown.list = stageList();
		stageDropDown.selectedLabel = lastLoadedStage;

		var reloadButton:PsychUIButton = new PsychUIButton(160, 10, 'Reload', function() loadStage(lastLoadedStage), 80);
		var saveButton:PsychUIButton = new PsychUIButton(160, 40, 'Save', saveStage, 80);

		var showCheckbox:PsychUICheckBox = new PsychUICheckBox(10, 70, 'Show Shaders', 100);
		showCheckbox.checked = showShaders;
		showCheckbox.onClick = function() {
			showShaders = showCheckbox.checked;
			rebuildShaderPreview();
		};

		var noteText:FlxText = new FlxText(10, 95, BOX_WIDTH - 20, 'Saving only changes the shaders of this stage.');
		noteText.color = FlxColor.GRAY;

		tab_group.add(new FlxText(stageDropDown.x, stageDropDown.y - 18, 60, 'Stage:'));
		tab_group.add(reloadButton);
		tab_group.add(saveButton);
		tab_group.add(showCheckbox);
		tab_group.add(noteText);
		tab_group.add(stageDropDown);
	}

	function addCharactersTab()
	{
		var tab_group = stageBox.getTab('Characters').menu;

		var objX:Float = 10;
		bfDropDown = new PsychUIDropDownMenu(objX, 30, characterList, function(id:Int, name:String) {
			boyfriend.changeCharacter(name);
			afterCharacterChange();
		}, DROPDOWN_WIDTH);
		gfDropDown = new PsychUIDropDownMenu(objX, 70, characterList, function(id:Int, name:String) {
			gf.changeCharacter(name);
			afterCharacterChange();
		}, DROPDOWN_WIDTH);
		oppDropDown = new PsychUIDropDownMenu(objX, 110, characterList, function(id:Int, name:String) {
			dad.changeCharacter(name);
			afterCharacterChange();
		}, DROPDOWN_WIDTH);

		tab_group.add(new FlxText(objX, 12, 200, 'Boyfriend (preview only):'));
		tab_group.add(new FlxText(objX, 52, 200, 'Girlfriend (preview only):'));
		tab_group.add(new FlxText(objX, 92, 200, 'Opponent (preview only):'));
		tab_group.add(oppDropDown);
		tab_group.add(gfDropDown);
		tab_group.add(bfDropDown);
		refreshCharacterDropDowns();
	}

	function refreshCharacterDropDowns()
	{
		if(bfDropDown == null) return;
		bfDropDown.selectedLabel = boyfriend.curCharacter;
		gfDropDown.selectedLabel = gf.curCharacter;
		oppDropDown.selectedLabel = dad.curCharacter;
	}

	function refreshBoxes()
	{
		stageBox.visible = stageBox.active = hudVisible;
		shaderBox.visible = shaderBox.active = hudVisible && !rtxMode;
		rtxBox.visible = rtxBox.active = hudVisible && rtxMode;
	}

	function afterCharacterChange()
	{
		repositionCharacters();
		rebuildShaderPreview();
		if(rtxMode) refreshRtxUI();
	}

	function addShadersTab()
	{
		var tab_group = shaderBox.getTab('Shaders').menu;

		var objX = 10;
		var objY = 20;
		tab_group.add(new FlxText(objX, objY - 18, 180, 'Shaders List:'));
		var entryY:Float = objY;

		objY += 30;
		tab_group.add(new PsychUIButton(objX, objY, 'Add', addShaderEntry, 70));
		tab_group.add(new PsychUIButton(objX + 75, objY, 'Remove', removeShaderEntry, 70));
		tab_group.add(new PsychUIButton(objX + 150, objY, 'Move Up', moveShaderEntryUp, 70));

		objY += 50;
		tab_group.add(new FlxText(objX, objY - 18, 180, 'Target:'));
		var targetY:Float = objY;
		tab_group.add(new PsychUIButton(objX + 170, objY, 'Focus', function() {
			var entry:Dynamic = currentShaderEntry();
			if(entry != null) focusOn(Std.string(entry.target));
		}, 55));

		objY += 40;
		tab_group.add(new FlxText(objX, objY - 18, 180, 'Shader File:'));
		var fileY:Float = objY;

		objY += 40;
		tab_group.add(new FlxText(objX, objY - 18, 180, 'Name (for Lua/HScript):'));
		shaderNameInput = new PsychUIInputText(objX, objY, 120, '', 8);
		shaderNameInput.customFilterPattern = ~/[^a-zA-Z0-9_\-]*/g;
		shaderNameInput.onChange = function(old:String, cur:String) {
			var entry:Dynamic = currentShaderEntry();
			if(entry == null) return;
			entry.name = shaderNameInput.text;
			unsavedProgress = true;
			refreshShaderEntryList();
			rebuildShaderPreview();
		};
		tab_group.add(shaderNameInput);

		objY += 25;
		shaderEnabledCheckbox = new PsychUICheckBox(objX, objY, 'Enabled', 80);
		shaderEnabledCheckbox.onClick = function() {
			var entry:Dynamic = currentShaderEntry();
			if(entry == null) return;
			entry.enabled = shaderEnabledCheckbox.checked;
			unsavedProgress = true;
			rebuildShaderPreview();
		};
		tab_group.add(shaderEnabledCheckbox);

		objY += 45;
		tab_group.add(new FlxText(objX, objY - 18, 180, 'Uniform:'));
		var uniformY:Float = objY;

		objY += 40;
		shaderValueText = new FlxText(objX, objY - 18, 180, 'Value:');
		tab_group.add(shaderValueText);
		shaderValueInput = new PsychUIInputText(objX, objY, DROPDOWN_WIDTH, '', 8);
		shaderValueInput.onChange = function(old:String, cur:String) {
			var entry:Dynamic = currentShaderEntry();
			var uniform:ShaderUniform = currentUniform();
			if(entry == null || uniform == null) return;
			if(entry.values == null) entry.values = {};
			var text:String = shaderValueInput.text.trim();
			if(text.length < 1)
			{
				Reflect.deleteField(entry.values, uniform.name);
				unsavedProgress = true;
				rebuildShaderPreview();
				return;
			}
			var value:Dynamic = ShaderLoader.parseText(uniform.type, text);
			if(value == null) return;
			Reflect.setField(entry.values, uniform.name, value);
			unsavedProgress = true;
			var preview:FlxRuntimeShader = shaderPreviews[curShaderEntry];
			if(preview != null) ShaderLoader.applyValue(preview, uniform, value);
		};
		tab_group.add(shaderValueInput);

		objY += 30;
		tab_group.add(new FlxText(objX, objY, BOX_WIDTH - 20, 'Value formats:\n\nfloat/int: 1/0.5\n\nvec2/3/4: 1, 0.5, 0\n\nbool: true / false\n\nsampler2D: image path\n\nEmpty = shader default\n\nShader Editor only allows initialization for basic shaders.\nFor complex shaders, it\'s recommended to use LUA/HX scripting.\n\ncamHUD/camOther shaders cannot be viewed from the editor.'));

		tab_group.add(new PsychUIButton(objX, 530, 'Lighting Editor', openRtxEditor, BOX_WIDTH - 20));

		shaderUniformDropDown = new PsychUIDropDownMenu(objX, uniformY, [''], function(id:Int, name:String) {
			showShaderValue();
		}, DROPDOWN_WIDTH);
		tab_group.add(shaderUniformDropDown);

		shaderFileDropDown = new PsychUIDropDownMenu(objX, fileY, [''], function(id:Int, name:String) {
			var entry:Dynamic = currentShaderEntry();
			if(entry == null || name.length < 1 || name == entry.shader) return;
			if(entry.name == null || entry.name == entry.shader) entry.name = name;
			entry.shader = name;
			entry.values = (name == RTX_SHADER) ? defaultRtxValues() : {};
			unsavedProgress = true;
			refreshShaderUI();
		}, DROPDOWN_WIDTH);
		tab_group.add(shaderFileDropDown);

		shaderTargetDropDown = new PsychUIDropDownMenu(objX, targetY, [''], function(id:Int, name:String) {
			var entry:Dynamic = currentShaderEntry();
			if(entry == null || name.length < 1) return;
			entry.target = name;
			unsavedProgress = true;
			refreshShaderEntryList();
			rebuildShaderPreview();
		}, DROPDOWN_WIDTH);
		tab_group.add(shaderTargetDropDown);

		shaderEntryDropDown = new PsychUIDropDownMenu(objX, entryY, [''], function(id:Int, name:String) {
			var dot:Int = name.indexOf('.');
			var index:Null<Int> = (dot > 0) ? Std.parseInt(name.substr(0, dot)) : null;
			if(index == null) return;
			curShaderEntry = index - 1;
			refreshShaderUI();
		}, DROPDOWN_WIDTH);
		tab_group.add(shaderEntryDropDown);
	}

	function currentShaderEntry():Dynamic
		return (curShaderEntry >= 0 && curShaderEntry < shaderEntries.length) ? shaderEntries[curShaderEntry] : null;

	function currentUniform():ShaderUniform
	{
		var label:String = shaderUniformDropDown.selectedLabel;
		if(label == null) return null;
		for (uniform in shaderUniforms)
			if(uniformLabel(uniform) == label) return uniform;
		return null;
	}

	inline function uniformLabel(uniform:ShaderUniform):String
		return '${uniform.name} (${uniform.type})';

	function shaderEntryName(entry:Dynamic):String
		return (entry.name != null && Std.string(entry.name).length > 0) ? Std.string(entry.name) : Std.string(entry.shader);

	function loadShaderEntries()
	{
		shaderEntries = [];
		if(stageJson.shaders != null)
		{
			for (entry in stageJson.shaders)
			{
				if(entry == null) continue;
				var values:Dynamic = {};
				if(entry.values != null)
					for (field in Reflect.fields(entry.values))
						Reflect.setField(values, field, Reflect.field(entry.values, field));
				shaderEntries.push({name: entry.name, shader: entry.shader, target: entry.target, enabled: entry.enabled != false, values: values});
			}
		}
		curShaderEntry = shaderEntries.length > 0 ? 0 : -1;
		refreshShaderUI();
	}

	function addShaderEntry()
	{
		var files:Array<String> = ShaderLoader.list();
		if(files.length < 1)
		{
			showOutput('No shaders found! Put .frag files in the shaders folder.', true);
			return;
		}
		var shader:String = files[0];
		shaderEntries.push({name: shader, shader: shader, target: 'camGame', enabled: true, values: (shader == RTX_SHADER) ? defaultRtxValues() : {}});
		curShaderEntry = shaderEntries.length - 1;
		unsavedProgress = true;
		refreshShaderUI();
	}

	function removeShaderEntry()
	{
		if(currentShaderEntry() == null) return;
		shaderEntries.splice(curShaderEntry, 1);
		curShaderEntry = Std.int(Math.min(curShaderEntry, shaderEntries.length - 1));
		unsavedProgress = true;
		refreshShaderUI();
	}

	function moveShaderEntryUp()
	{
		if(curShaderEntry < 1 || currentShaderEntry() == null) return;
		var entry:Dynamic = shaderEntries[curShaderEntry];
		shaderEntries[curShaderEntry] = shaderEntries[curShaderEntry - 1];
		shaderEntries[curShaderEntry - 1] = entry;
		curShaderEntry--;
		unsavedProgress = true;
		refreshShaderUI();
	}

	function characterTargets():Array<String>
	{
		var targets:Array<String> = ['boyfriend', 'dad', 'gf'];
		for (index in 0...extraCharacters.length)
			targets.push(StageData.extraCharacterType(Song.FIRST_EXTRA_SLOT + index));
		return targets;
	}

	function shaderTargets():Array<String>
	{
		var targets:Array<String> = ['camGame', 'camHUD', 'camOther'].concat(characterTargets());
		for (object in stageObjects)
			if(!object.character && object.name != null && !targets.contains(object.name))
				targets.push(object.name);
		return targets;
	}

	function refreshShaderEntryList()
	{
		var labels:Array<String> = [for (i => entry in shaderEntries) '${i + 1}. ${shaderEntryName(entry)} > ${entry.target}'];
		shaderEntryDropDown.list = labels.length > 0 ? labels : [''];
		shaderEntryDropDown.selectedIndex = curShaderEntry >= 0 ? curShaderEntry : 0;
	}

	function refreshShaderUI()
	{
		if(shaderEntryDropDown == null) return;
		refreshShaderEntryList();

		var entry:Dynamic = currentShaderEntry();
		var targets:Array<String> = shaderTargets();
		var files:Array<String> = ShaderLoader.list();
		if(entry != null)
		{
			if(!targets.contains(entry.target)) targets.push(entry.target);
			if(!files.contains(entry.shader)) files.push(entry.shader);
		}
		shaderTargetDropDown.list = targets;
		shaderFileDropDown.list = files.length > 0 ? files : [''];
		shaderUniforms = (entry != null) ? ShaderLoader.uniforms(entry.shader) : [];
		shaderUniformDropDown.list = shaderUniforms.length > 0 ? [for (uniform in shaderUniforms) uniformLabel(uniform)] : [''];

		if(entry != null)
		{
			shaderTargetDropDown.selectedLabel = entry.target;
			shaderFileDropDown.selectedLabel = entry.shader;
			shaderNameInput.text = (entry.name != null) ? entry.name : '';
			shaderEnabledCheckbox.checked = (entry.enabled != false);
		}
		else
		{
			shaderNameInput.text = '';
			shaderEnabledCheckbox.checked = false;
		}
		showShaderValue();
		rebuildShaderPreview();
	}

	function showShaderValue()
	{
		var entry:Dynamic = currentShaderEntry();
		var uniform:ShaderUniform = currentUniform();
		shaderValueText.text = (uniform != null) ? 'Value (${uniform.type}):' : 'Value:';
		var value:Dynamic = (entry != null && uniform != null && entry.values != null) ? Reflect.field(entry.values, uniform.name) : null;
		shaderValueInput.text = ShaderLoader.formatValue(value);
	}

	function targetSprite(target:String):FlxSprite
	{
		switch(target)
		{
			case 'boyfriend' | 'bf':
				return boyfriend;
			case 'dad':
				return dad;
			case 'gf':
				return gf;
			case extraTarget if(StageData.extraSlotFromType(extraTarget) > 0):
				var index:Int = StageData.extraSlotFromType(extraTarget) - Song.FIRST_EXTRA_SLOT;
				return (index >= 0 && index < extraCharacters.length) ? extraCharacters[index] : null;
		}
		for (object in stageObjects)
			if(!object.character && object.name == target) return object.sprite;
		return null;
	}

	function rebuildShaderPreview()
	{
		for (object in stageObjects)
			if(object.sprite != null) object.sprite.shader = null;
		for (char in [gf, dad, boyfriend].concat(extraCharacters))
			if(char != null) char.shader = null;
		if(camGame != null) CameraShaders.reset(camGame);
		shaderPreviews = [];
		if(!ClientPrefs.data.shaders || !showShaders) return;

		for (entry in shaderEntries)
		{
			var shader:FlxRuntimeShader = (entry.enabled != false) ? ShaderLoader.create(entry.shader) : null;
			shaderPreviews.push(shader);
			if(shader == null) continue;
			ShaderLoader.applyValues(shader, entry.shader, entry.values);
			var target:String = Std.string(entry.target);
			switch(target)
			{
				case 'camGame':
					CameraShaders.add(camGame, shaderEntryName(entry), shader);
				case 'camHUD' | 'camOther':
				default:
					var sprite:FlxSprite = targetSprite(target);
					if(sprite != null) sprite.shader = shader;
			}
		}
	}

	function buildStage()
	{
		for (object in stageObjects)
			if(!object.character) FlxDestroyUtil.destroy(object.sprite);
		stageObjects = [];

		syncExtraCharacters();
		repositionCharacters();
		gf.visible = !stageJson.hide_girlfriend;
		boyfriend.visible = (stageJson.hide_boyfriend != true);
		dad.visible = (stageJson.hide_opponent != true);

		var list:Map<String, FlxSprite> = [];
		if(stageJson.objects != null && stageJson.objects.length > 0)
		{
			list = StageData.addObjectsToState(stageJson.objects, gf, dad, boyfriend, null, false, [for (char in extraCharacters) (char:FlxSprite)]);
			var byID:Array<ShaderEditorObject> = [];
			for (name => spr in list)
				byID[spr.ID] = {name: name, sprite: spr, character: Std.isOfType(spr, Character)};
			for (object in byID)
				if(object != null) stageObjects.push(object);
		}

		var insertAt:Int = stageObjects.length;
		for (i => object in stageObjects)
		{
			if(!object.character) continue;
			insertAt = i;
			break;
		}
		for (name in ['gf', 'dad', 'boyfriend'])
		{
			if(list.exists(name)) continue;
			stageObjects.insert(insertAt, {name: name, sprite: targetSprite(name), character: true});
			insertAt++;
		}
		for (index => char in extraCharacters)
		{
			var name:String = StageData.extraCharacterType(Song.FIRST_EXTRA_SLOT + index);
			if(list.exists(name)) continue;
			var last:Int = -1;
			for (i => object in stageObjects)
				if(object.character) last = i;
			stageObjects.insert(last + 1, {name: name, sprite: char, character: true});
		}
	}

	function syncExtraCharacters()
	{
		var slots:Array<StageCharacterSlot> = (stageJson.extra_characters != null) ? stageJson.extra_characters : [];
		var previews:Array<Dynamic> = (stageJson._editorMeta != null && stageJson._editorMeta.extras != null) ? stageJson._editorMeta.extras : [];
		while(extraCharacters.length > slots.length)
			FlxDestroyUtil.destroy(extraCharacters.pop());

		for (index in 0...slots.length)
		{
			var preview:Dynamic = (index < previews.length && previews[index] != null) ? previews[index] : null;
			var name:String = (preview != null && preview.character != null && Std.string(preview.character).length > 0) ? Std.string(preview.character) : dad.curCharacter;
			var isPlayer:Bool = (preview != null && preview.side == 'bf');
			var char:Character = extraCharacters[index];
			if(char == null)
			{
				char = new Character(0, 0, name, isPlayer);
				extraCharacters[index] = char;
			}
			else if(char.curCharacter != name || char.isPlayer != isPlayer)
			{
				char.isPlayer = isPlayer;
				char.changeCharacter(name);
			}
		}
	}

	function repositionCharacters()
	{
		placeCharacter(gf, stageJson.girlfriend);
		placeCharacter(dad, stageJson.opponent);
		placeCharacter(boyfriend, stageJson.boyfriend);
		var slots:Array<StageCharacterSlot> = (stageJson.extra_characters != null) ? stageJson.extra_characters : [];
		for (index => char in extraCharacters)
			if(index < slots.length && slots[index] != null && slots[index].position != null)
				placeCharacter(char, slots[index].position);
	}

	function placeCharacter(char:Character, position:Array<Dynamic>)
	{
		if(char == null) return;
		var posX:Float = (position != null && position.length > 1) ? position[0] : 0;
		var posY:Float = (position != null && position.length > 1) ? position[1] : 0;
		char.setPosition(posX + char.positionArray[0], posY + char.positionArray[1]);
	}

	function loadStage(name:String)
	{
		lastLoadedStage = name;
		stageJson = StageData.getStageFile(name);
		quickSavePath = stageFilePath(name);
		quickSaveFromLoad = true;
		loadJsonAssetDirectory();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Shader Editor', 'Stage: ' + lastLoadedStage);
		#end

		gf.changeCharacter(metaCharacter('gf', 'gf'));
		dad.changeCharacter(metaCharacter('dad', 'dad'));
		boyfriend.changeCharacter(metaCharacter('boyfriend', 'bf'));
		refreshCharacterDropDowns();

		buildStage();
		loadShaderEntries();
		stageDropDown.list = stageList();
		stageDropDown.selectedLabel = lastLoadedStage;
		resetCamera();
		unsavedProgress = false;
		if(rtxMode) refreshRtxUI();
		showOutput('Loaded "$name".');
	}

	function resetCamera()
	{
		FlxG.camera.zoom = stageJson.defaultZoom;
		var point:FlxPoint = boyfriend.getMidpoint();
		point.x -= boyfriend.cameraPosition[0] + 100;
		point.y += boyfriend.cameraPosition[1] - 100;
		if(stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
		{
			point.x += stageJson.camera_boyfriend[0];
			point.y += stageJson.camera_boyfriend[1];
		}
		FlxG.camera.scroll.set(point.x - FlxG.width / 2, point.y - FlxG.height / 2);
		point.put();
	}

	function focusOn(target:String)
	{
		var sprite:FlxSprite = targetSprite(target);
		if(sprite == null)
		{
			if(ShaderLoader.isCameraTarget(target)) resetCamera();
			return;
		}
		var bounds:FlxRect = visibleBounds(sprite);
		FlxG.camera.scroll.set(bounds.x + bounds.width / 2 - FlxG.width / 2, bounds.y + bounds.height / 2 - FlxG.height / 2);
		bounds.put();
	}

	function visibleBounds(sprite:FlxSprite):FlxRect
	{
		if(Std.isOfType(sprite, Character))
		{
			var char:Character = cast sprite;
			#if flxanimate
			if(char.isAnimateAtlas && char.atlas != null && char.atlas.width > 0 && char.atlas.height > 0)
				return FlxRect.get(char.atlas.x + char.atlas.relativeX + FlxG.camera.scroll.x * char.scrollFactor.x,
					char.atlas.y + char.atlas.relativeY + FlxG.camera.scroll.y * char.scrollFactor.y, char.atlas.width, char.atlas.height);
			#end
			return FlxRect.get(char.x, char.y, Math.max(1, char.width), Math.max(1, char.height));
		}
		return FlxRect.get(sprite.x - sprite.offset.x, sprite.y - sprite.offset.y, Math.max(1, sprite.frameWidth * Math.abs(sprite.scale.x)), Math.max(1, sprite.frameHeight * Math.abs(sprite.scale.y)));
	}

	function defaultRtxValues():Dynamic
	{
		return {
			overlayColor: [0.0, 0.0, 0.0, 0.0],
			satinColor: [0.0, 0.0, 0.0, 0.0],
			innerShadowColor: [0.0, 0.0, 0.0, 0.0],
			innerShadowAngle: 0.0,
			innerShadowDistance: RTX_DEFAULT_DISTANCE
		};
	}

	function addRtxTab()
	{
		var tab_group = rtxBox.getTab('Lighting Editor').menu;
		var objX:Float = 10;

		tab_group.add(new FlxText(objX, 2, 200, 'Character:'));
		tab_group.add(new PsychUIButton(objX + 170, 20, 'Focus', function() focusOn(rtxTarget), 55));

		rtxInfoText = new FlxText(objX, 48, RTX_BOX_WIDTH - 20, '');
		tab_group.add(rtxInfoText);

		tab_group.add(new PsychUIButton(objX, 82, 'Remove RTX', function() {
			var index:Int = rtxEntryIndex();
			if(index < 0) return;
			shaderEntries.splice(index, 1);
			curShaderEntry = Std.int(Math.min(curShaderEntry, shaderEntries.length - 1));
			unsavedProgress = true;
			refreshShaderUI();
			refreshRtxUI();
		}, 90));
		tab_group.add(new PsychUIButton(objX + 100, 82, 'Reset Values', function() {
			var index:Int = rtxEntryIndex();
			if(index < 0) return;
			shaderEntries[index].values = defaultRtxValues();
			unsavedProgress = true;
			rebuildShaderPreview();
			refreshRtxUI();
		}, 90));

		rtxColorRadio = new PsychUIRadioGroup(objX, 115, RTX_COLOR_LABELS, 12, 0, true, 76);
		rtxColorRadio.checked = rtxColorIndex;
		rtxColorRadio.onClick = function() {
			rtxColorIndex = rtxColorRadio.checked;
			loadPickerColor();
		};
		tab_group.add(rtxColorRadio);

		var pickerY:Float = 145;
		pickerSprite = new FlxSprite(objX, pickerY).makeGraphic(PICKER_SIZE, PICKER_SIZE, FlxColor.WHITE, true);
		tab_group.add(pickerSprite);

		hueSprite = new FlxSprite(objX + PICKER_SIZE + 6, pickerY).makeGraphic(BAR_WIDTH, PICKER_SIZE, FlxColor.WHITE, true);
		hueSprite.pixels.lock();
		for (py in 0...PICKER_SIZE)
		{
			var color:FlxColor = FlxColor.fromHSB((py / PICKER_SIZE) * 360, 1, 1);
			for (px in 0...BAR_WIDTH) hueSprite.pixels.setPixel32(px, py, color);
		}
		hueSprite.pixels.unlock();
		hueSprite.dirty = true;
		tab_group.add(hueSprite);

		alphaSprite = new FlxSprite(hueSprite.x + BAR_WIDTH + 6, pickerY).makeGraphic(BAR_WIDTH, PICKER_SIZE, FlxColor.WHITE, true);
		tab_group.add(alphaSprite);

		pickerDot = new FlxSprite().makeGraphic(8, 8, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(pickerDot, 4, 4, 3, FlxColor.TRANSPARENT, {thickness: 1.5, color: FlxColor.WHITE});
		tab_group.add(pickerDot);

		hueLine = new FlxSprite().makeGraphic(BAR_WIDTH + 4, 2, FlxColor.WHITE);
		tab_group.add(hueLine);
		alphaLine = new FlxSprite().makeGraphic(BAR_WIDTH + 4, 2, FlxColor.WHITE);
		tab_group.add(alphaLine);

		var sideX:Float = alphaSprite.x + BAR_WIDTH + 10;
		tab_group.add(new FlxText(sideX, pickerY, 80, 'Hex:'));
		rtxHexInput = new PsychUIInputText(sideX, pickerY + 16, 70, '#000000', 8);
		rtxHexInput.maxLength = 7;
		rtxHexInput.onChange = function(old:String, cur:String) {
			var clean:String = cur.replace('#', '').trim();
			if(clean.length != 6) return;
			var value:Null<Int> = Std.parseInt('0x' + clean);
			if(value == null) return;
			var color:FlxColor = FlxColor.fromInt(0xFF000000 | value);
			pickerHue = color.hue;
			pickerSaturation = color.saturation;
			pickerBrightness = color.brightness;
			redrawPicker();
			storePickerColor(false);
		};
		tab_group.add(rtxHexInput);

		tab_group.add(new FlxText(sideX, pickerY + 42, 80, 'Strength (0-1):'));
		rtxAlphaInput = new PsychUIInputText(sideX, pickerY + 58, 70, '0', 8);
		rtxAlphaInput.maxLength = 5;
		rtxAlphaInput.onChange = function(old:String, cur:String) {
			var value:Float = Std.parseFloat(cur.trim());
			if(Math.isNaN(value)) return;
			pickerAlpha = FlxMath.bound(value, 0, 1);
			redrawAlphaBar();
			redrawSwatch();
			storePickerColor(true);
		};
		tab_group.add(rtxAlphaInput);

		swatchSprite = new FlxSprite(sideX, pickerY + 90).makeGraphic(70, 40, FlxColor.WHITE, true);
		tab_group.add(swatchSprite);

		rtxSummaryText = new FlxText(objX, pickerY + PICKER_SIZE + 8, RTX_BOX_WIDTH - 20, '');
		tab_group.add(rtxSummaryText);

		var wheelY:Float = pickerY + PICKER_SIZE + 58;
		tab_group.add(new FlxText(objX, wheelY - 16, 200, 'Inner Shadow Direction:'));
		wheelSprite = new FlxSprite(objX, wheelY).makeGraphic(WHEEL_SIZE, WHEEL_SIZE, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(wheelSprite, WHEEL_SIZE / 2, WHEEL_SIZE / 2, WHEEL_SIZE / 2 - 2, 0xFF303030, {thickness: 2, color: FlxColor.WHITE});
		FlxSpriteUtil.drawCircle(wheelSprite, WHEEL_SIZE / 2, WHEEL_SIZE / 2, 3, FlxColor.WHITE);
		tab_group.add(wheelSprite);
		wheelDot = new FlxSprite().makeGraphic(10, 10, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(wheelDot, 5, 5, 4, FlxColor.YELLOW);
		tab_group.add(wheelDot);

		var sliderX:Float = objX + WHEEL_SIZE + 45;
		rtxAngleSlider = new PsychUISlider(sliderX, wheelY - 6, null, 0, 0, 360, 130);
		rtxAngleSlider.label = 'Angle (degrees)';
		rtxAngleSlider.decimals = 0;
		rtxAngleSlider.onChange = function(value:Float) setRtxAngle(value);
		tab_group.add(rtxAngleSlider);

		rtxDistanceSlider = new PsychUISlider(sliderX, wheelY + 46, null, RTX_DEFAULT_DISTANCE, 0, 50, 130);
		rtxDistanceSlider.label = 'Distance (pixels)';
		rtxDistanceSlider.decimals = 1;
		rtxDistanceSlider.onChange = function(value:Float) setRtxValue('innerShadowDistance', value);
		tab_group.add(rtxDistanceSlider);

		var animY:Float = wheelY + WHEEL_SIZE + 30;
		tab_group.add(new FlxText(objX, animY - 18, 200, 'Preview Animation:'));

		var credits:FlxText = new FlxText(objX, animY + 32, RTX_BOX_WIDTH - 20, 'Overlay brightens, Satin multiplies, Inner Shadow lights the edges facing the direction.\nRTX Lighting shader by TheZoroForce240.');
		credits.color = FlxColor.GRAY;
		tab_group.add(credits);

		tab_group.add(new PsychUIButton(objX, animY + 80, 'Back to Shaders', closeRtxEditor, RTX_BOX_WIDTH - 20));

		rtxAnimationDropDown = new PsychUIDropDownMenu(objX, animY, [''], function(id:Int, name:String) {
			var char:Character = cast targetSprite(rtxTarget);
			if(char != null && name.length > 0) char.playAnim(name, true);
		}, DROPDOWN_WIDTH);
		tab_group.add(rtxAnimationDropDown);

		rtxCharacterDropDown = new PsychUIDropDownMenu(objX, 20, [''], function(id:Int, name:String) {
			var targets:Array<String> = characterTargets();
			if(id < 0 || id >= targets.length) return;
			rtxTarget = targets[id];
			refreshRtxUI();
			focusOn(rtxTarget);
		}, DROPDOWN_WIDTH);
		rtxCharacterDropDown.autoSort = false;
		tab_group.add(rtxCharacterDropDown);
	}

	function characterLabel(target:String):String
	{
		if(CHARACTER_LABELS.exists(target)) return CHARACTER_LABELS.get(target);
		return 'Char ' + StageData.extraSlotFromType(target);
	}

	function openRtxEditor()
	{
		if(ShaderLoader.source(RTX_SHADER) == null)
		{
			showOutput('$RTX_SHADER.frag not found in the shaders folder!', true);
			return;
		}
		var entry:Dynamic = currentShaderEntry();
		if(entry != null && entry.shader == RTX_SHADER && characterTargets().contains(Std.string(entry.target)))
			rtxTarget = Std.string(entry.target);
		if(!characterTargets().contains(rtxTarget)) rtxTarget = 'boyfriend';

		rtxMode = true;
		refreshBoxes();
		refreshRtxUI();
		focusOn(rtxTarget);
	}

	function closeRtxEditor()
	{
		rtxMode = false;
		refreshBoxes();
		pickerDragging = 0;
		var index:Int = rtxEntryIndex();
		if(index >= 0) curShaderEntry = index;
		refreshShaderUI();
	}

	function rtxEntryIndex():Int
	{
		var found:Int = -1;
		for (i => entry in shaderEntries)
			if(entry != null && entry.shader == RTX_SHADER && Std.string(entry.target) == rtxTarget) found = i;
		return found;
	}

	function ensureRtxEntry():Int
	{
		var index:Int = rtxEntryIndex();
		if(index >= 0) return index;
		var name:String = 'rtx_' + rtxTarget;
		shaderEntries.push({name: name, shader: RTX_SHADER, target: rtxTarget, enabled: true, values: defaultRtxValues()});
		index = shaderEntries.length - 1;
		curShaderEntry = index;
		refreshShaderUI();
		return index;
	}

	function rtxValues():Dynamic
	{
		var index:Int = rtxEntryIndex();
		return (index >= 0 && shaderEntries[index].values != null) ? shaderEntries[index].values : defaultRtxValues();
	}

	function rtxColor(field:String):Array<Float>
	{
		var value:Dynamic = Reflect.field(rtxValues(), field);
		var color:Array<Float> = [0, 0, 0, 0];
		if(Std.isOfType(value, Array))
		{
			var list:Array<Dynamic> = value;
			for (i in 0...4)
				if(i < list.length) color[i] = Std.parseFloat(Std.string(list[i]));
		}
		for (i in 0...4)
			if(Math.isNaN(color[i])) color[i] = 0;
		return color;
	}

	function rtxFloat(field:String, fallback:Float):Float
	{
		var value:Dynamic = Reflect.field(rtxValues(), field);
		if(value == null) return fallback;
		var number:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(number) ? fallback : number;
	}

	function setRtxValue(field:String, value:Dynamic)
	{
		var index:Int = ensureRtxEntry();
		var entry:Dynamic = shaderEntries[index];
		if(entry.values == null) entry.values = defaultRtxValues();
		Reflect.setField(entry.values, field, value);
		unsavedProgress = true;

		var preview:FlxRuntimeShader = shaderPreviews[index];
		if(preview != null) ShaderLoader.applyValue(preview, {name: field, type: field.endsWith('Color') ? 'vec4' : 'float'}, value);
		refreshRtxInfo();
	}

	function setRtxAngle(degrees:Float)
	{
		degrees = ((degrees % 360) + 360) % 360;
		setRtxValue('innerShadowAngle', roundValue(degrees * Math.PI / 180, 4));
		if(!rtxAngleSlider.movingHandle) rtxAngleSlider.value = Math.round(degrees);
		placeWheelDot(degrees);
	}

	inline function roundValue(value:Float, decimals:Int):Float
	{
		var mult:Float = Math.pow(10, decimals);
		return Math.round(value * mult) / mult;
	}

	function refreshRtxUI()
	{
		if(rtxCharacterDropDown == null) return;
		var targets:Array<String> = characterTargets();
		if(!targets.contains(rtxTarget)) rtxTarget = 'boyfriend';
		rtxCharacterDropDown.list = [for (target in targets) characterLabel(target)];
		rtxCharacterDropDown.selectedIndex = targets.indexOf(rtxTarget);

		var char:Character = cast targetSprite(rtxTarget);
		var anims:Array<String> = (char != null && char.animationsArray != null) ? [for (anim in char.animationsArray) anim.anim] : [];
		rtxAnimationDropDown.list = anims.length > 0 ? anims : [''];

		var degrees:Float = rtxFloat('innerShadowAngle', 0) * 180 / Math.PI;
		degrees = ((degrees % 360) + 360) % 360;
		rtxAngleSlider.value = Math.round(degrees);
		placeWheelDot(degrees);
		rtxDistanceSlider.value = rtxFloat('innerShadowDistance', RTX_DEFAULT_DISTANCE);
		loadPickerColor();
		refreshRtxInfo();
	}

	function refreshRtxInfo()
	{
		var index:Int = rtxEntryIndex();
		var label:String = characterLabel(rtxTarget);
		var info:String = (index >= 0) ? 'RTX is on for $label.' : 'No RTX on $label yet: change a value to add it.';
		if(!ClientPrefs.data.shaders) info += '\nShaders are disabled in the Options!';
		else if(!showShaders) info += '\n"Show Shaders" is off in the Stage tab.';
		else if(index >= 0)
		{
			for (i => entry in shaderEntries)
				if(i > index && entry != null && entry.enabled != false && Std.string(entry.target) == rtxTarget)
				{
					info += '\nEntry #${i + 1} also targets $label and replaces RTX!';
					break;
				}
		}
		rtxInfoText.text = info;

		var lines:Array<String> = [];
		for (i => field in RTX_COLOR_FIELDS)
		{
			var color:Array<Float> = rtxColor(field);
			var hex:String = '#' + StringTools.hex(FlxColor.fromRGBFloat(color[0], color[1], color[2]).rgb, 6);
			lines.push('${RTX_COLOR_LABELS[i]}: $hex, strength ${roundValue(color[3], 2)}');
		}
		rtxSummaryText.text = lines.join('\n');
	}

	function loadPickerColor()
	{
		var color:Array<Float> = rtxColor(RTX_COLOR_FIELDS[rtxColorIndex]);
		var flxColor:FlxColor = FlxColor.fromRGBFloat(color[0], color[1], color[2]);
		pickerHue = flxColor.hue;
		pickerSaturation = flxColor.saturation;
		pickerBrightness = flxColor.brightness;
		pickerAlpha = color[3];
		rtxAlphaInput.text = Std.string(roundValue(pickerAlpha, 2));
		rtxHexInput.text = '#' + StringTools.hex(flxColor.rgb, 6);
		redrawPicker();
	}

	function storePickerColor(fromStepper:Bool)
	{
		var color:FlxColor = FlxColor.fromHSB(pickerHue, pickerSaturation, pickerBrightness);
		if(!fromStepper && PsychUIInputText.focusOn != rtxHexInput) rtxHexInput.text = '#' + StringTools.hex(color.rgb, 6);
		if(!fromStepper && pickerAlpha <= 0)
		{
			pickerAlpha = 1;
			rtxAlphaInput.text = '1';
			redrawAlphaBar();
		}
		setRtxValue(RTX_COLOR_FIELDS[rtxColorIndex], [roundValue(color.redFloat, 3), roundValue(color.greenFloat, 3), roundValue(color.blueFloat, 3), roundValue(pickerAlpha, 3)]);
		redrawSwatch();
	}

	function redrawPicker()
	{
		var bitmap = pickerSprite.pixels;
		bitmap.lock();
		for (py in 0...PICKER_SIZE)
			for (px in 0...PICKER_SIZE)
				bitmap.setPixel32(px, py, FlxColor.fromHSB(pickerHue, px / (PICKER_SIZE - 1), 1 - py / (PICKER_SIZE - 1)));
		bitmap.unlock();
		pickerSprite.dirty = true;
		redrawAlphaBar();
		redrawSwatch();
		placePickerMarkers();
	}

	function redrawAlphaBar()
	{
		var color:FlxColor = FlxColor.fromHSB(pickerHue, pickerSaturation, pickerBrightness);
		var bitmap = alphaSprite.pixels;
		bitmap.lock();
		for (py in 0...PICKER_SIZE)
		{
			var strength:Float = 1 - py / (PICKER_SIZE - 1);
			for (px in 0...BAR_WIDTH)
			{
				var checker:FlxColor = (((px >> 2) + (py >> 2)) % 2 == 0) ? 0xFF808080 : 0xFF404040;
				bitmap.setPixel32(px, py, FlxColor.interpolate(checker, color, strength));
			}
		}
		bitmap.unlock();
		alphaSprite.dirty = true;
		placePickerMarkers();
	}

	function redrawSwatch()
	{
		var color:FlxColor = FlxColor.fromHSB(pickerHue, pickerSaturation, pickerBrightness);
		var bitmap = swatchSprite.pixels;
		bitmap.lock();
		for (py in 0...Std.int(swatchSprite.frameHeight))
			for (px in 0...Std.int(swatchSprite.frameWidth))
			{
				var checker:FlxColor = (((px >> 3) + (py >> 3)) % 2 == 0) ? 0xFF808080 : 0xFF404040;
				bitmap.setPixel32(px, py, FlxColor.interpolate(checker, color, pickerAlpha));
			}
		bitmap.unlock();
		swatchSprite.dirty = true;
	}

	function placePickerMarkers()
	{
		pickerDot.setPosition(pickerSprite.x + pickerSaturation * PICKER_SIZE - 4, pickerSprite.y + (1 - pickerBrightness) * PICKER_SIZE - 4);
		hueLine.setPosition(hueSprite.x - 2, hueSprite.y + (pickerHue / 360) * PICKER_SIZE - 1);
		alphaLine.setPosition(alphaSprite.x - 2, alphaSprite.y + (1 - pickerAlpha) * PICKER_SIZE - 1);
	}

	function placeWheelDot(degrees:Float)
	{
		var radius:Float = WHEEL_SIZE / 2 - 8;
		var radians:Float = degrees * Math.PI / 180;
		wheelDot.setPosition(wheelSprite.x + WHEEL_SIZE / 2 + Math.cos(radians) * radius - 5, wheelSprite.y + WHEEL_SIZE / 2 + Math.sin(radians) * radius - 5);
	}

	function updateRtxMouse()
	{
		if(!rtxBox.visible || rtxBox.isMinimized) return;

		if(FlxG.mouse.justPressed)
		{
			if(FlxG.mouse.overlaps(pickerSprite, camHUD)) pickerDragging = 1;
			else if(FlxG.mouse.overlaps(hueSprite, camHUD)) pickerDragging = 2;
			else if(FlxG.mouse.overlaps(alphaSprite, camHUD)) pickerDragging = 3;
			else if(FlxG.mouse.overlaps(wheelSprite, camHUD)) pickerDragging = 4;
			else pickerDragging = 0;
		}
		else if(!FlxG.mouse.pressed) pickerDragging = 0;

		if(pickerDragging == 0 || !FlxG.mouse.pressed) return;

		var mouse:FlxPoint = FlxG.mouse.getScreenPosition(camHUD);
		switch(pickerDragging)
		{
			case 1:
				pickerSaturation = FlxMath.bound((mouse.x - pickerSprite.x) / PICKER_SIZE, 0, 1);
				pickerBrightness = FlxMath.bound(1 - (mouse.y - pickerSprite.y) / PICKER_SIZE, 0, 1);
				placePickerMarkers();
				redrawAlphaBar();
				storePickerColor(false);
			case 2:
				pickerHue = FlxMath.bound((mouse.y - hueSprite.y) / PICKER_SIZE, 0, 1) * 359.9;
				redrawPicker();
				storePickerColor(false);
			case 3:
				pickerAlpha = roundValue(FlxMath.bound(1 - (mouse.y - alphaSprite.y) / PICKER_SIZE, 0, 1), 2);
				rtxAlphaInput.text = Std.string(pickerAlpha);
				placePickerMarkers();
				redrawSwatch();
				storePickerColor(true);
			case 4:
				var degrees:Float = Math.atan2(mouse.y - (wheelSprite.y + WHEEL_SIZE / 2), mouse.x - (wheelSprite.x + WHEEL_SIZE / 2)) * 180 / Math.PI;
				degrees = Math.round(((degrees % 360) + 360) % 360);
				setRtxAngle(degrees);
		}
		mouse.put();
	}

	function addHelpScreen()
	{
		#if FLX_DEBUG
		var btn = 'F3';
		#else
		var btn = 'F2';
		#end

		var str:Array<String> = [
			"E/Q - Camera Zoom In/Out",
			"J/K/L/I - Move Camera",
			"Mouse Drag / Mouse Wheel - Move Camera / Zoom",
			"R - Reset Camera",
			"Ctrl + S - Save the stage's shaders",
			"P - Reload Stage",
			"",
			'$btn - Toggle HUD',
			"F12 - Toggle Target Rectangle",
			"Hold Shift - Move Camera 4x faster",
			"Hold Control - Move Camera 4x slower"
		];

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.6;
		helpBg.cameras = [camHUD];
		helpBg.active = helpBg.visible = false;
		add(helpBg);

		helpTexts = new FlxSpriteGroup();
		helpTexts.cameras = [camHUD];
		for (i => txt in str)
		{
			if(txt.length < 1) continue;
			var helpText:FlxText = new FlxText(0, 0, 680, txt, 16);
			helpText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.borderColor = FlxColor.BLACK;
			helpText.scrollFactor.set();
			helpText.borderSize = 1;
			helpText.screenCenter();
			helpText.y += ((i - str.length / 2) * 32) + 16;
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	public function showOutput(txt:String, isError:Bool = false)
	{
		outputTxt.color = isError ? FlxColor.RED : FlxColor.WHITE;
		outputTxt.text = txt;
		outputTime = 3;
		if(isError) FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
		else FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function cleanEntries():Array<Dynamic>
	{
		var list:Array<Dynamic> = [];
		for (entry in shaderEntries)
		{
			if(entry == null) continue;
			var values:Dynamic = {};
			if(entry.values != null)
				for (field in Reflect.fields(entry.values))
					Reflect.setField(values, field, Reflect.field(entry.values, field));
			list.push({name: entry.name, shader: entry.shader, target: entry.target, enabled: entry.enabled != false, values: values});
		}
		return list;
	}

	function saveStage()
	{
		if(_file != null) return;

		var data:Dynamic = null;
		var toFile:Bool = (quickSavePath != null && FileSystem.exists(quickSavePath) && (!quickSaveFromLoad || EditorHelper.isModPath(quickSavePath)));
		if(toFile)
		{
			try { data = haxe.Json.parse(File.getContent(quickSavePath)); }
			catch(e:Dynamic) { data = null; }
		}
		if(data == null)
		{
			toFile = false;
			data = haxe.Json.parse(haxe.Json.stringify(stageJson));
		}

		var entries:Array<Dynamic> = cleanEntries();
		if(entries.length > 0) data.shaders = entries;
		else Reflect.deleteField(data, 'shaders');
		stageJson.shaders = (entries.length > 0) ? entries : null;

		var text:String = haxe.format.JsonPrinter.print(data, null, '\t');
		if(toFile)
		{
			try
			{
				File.saveContent(quickSavePath, text);
				unsavedProgress = false;
				showOutput('Shaders saved to: $quickSavePath');
			}
			catch(e:Dynamic)
			{
				showOutput('Error on saving stage!', true);
			}
			return;
		}

		_file = new FileReferenceCustom();
		_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.addEventListener(Event.CANCEL, onSaveCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file.save(text, '$lastLoadedStage.json');
	}

	function clearFile()
	{
		if(_file == null) return;
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	function onSaveComplete(_):Void
	{
		if(_file == null) return;
		var savedPath:String = @:privateAccess cast(_file, FileReferenceCustom)._trackSavedPath;
		if(savedPath != null)
		{
			quickSavePath = savedPath;
			quickSaveFromLoad = false;
		}
		clearFile();
		unsavedProgress = false;
		showOutput('Stage saved!');
	}

	function onSaveCancel(_):Void
		clearFile();

	function onSaveError(_):Void
	{
		clearFile();
		showOutput('Error on saving stage!', true);
	}

	public function UIEvent(id:String, sender:Dynamic) {}

	override function onFocus()
	{
		super.onFocus();
		skipMouseDelta = true;
	}

	function mouseOverUI():Bool
	{
		if(stageBox.visible && FlxG.mouse.overlaps(stageBox, camHUD)) return true;
		if(shaderBox.visible && FlxG.mouse.overlaps(shaderBox, camHUD)) return true;
		if(rtxBox.visible && FlxG.mouse.overlaps(rtxBox, camHUD)) return true;
		return false;
	}

	override function update(elapsed:Float)
	{
		for (object in stageObjects)
			if(object.sprite != null && object.sprite.active) object.sprite.update(elapsed);

		super.update(elapsed);

		outputTime = Math.max(0, outputTime - elapsed);
		outputTxt.alpha = outputTime;

		updateRtxMouse();

		if(PsychUIInputText.focusOn != null) return;

		if(FlxG.keys.justPressed.ESCAPE)
		{
			if(helpBg.visible)
			{
				helpBg.visible = helpTexts.visible = false;
				return;
			}
			if(rtxMode)
			{
				closeRtxEditor();
				return;
			}
			if(!unsavedProgress)
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				EditorHelper.returnToPreviousState();
			}
			else openSubState(new ExitConfirmationPrompt());
			return;
		}

		if(FlxG.keys.justPressed.F1)
			helpBg.visible = helpTexts.visible = !helpBg.visible;

		if(FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveStage();
		else if(FlxG.keys.justPressed.P) loadStage(lastLoadedStage);

		#if FLX_DEBUG
		if(FlxG.keys.justPressed.F3)
		#else
		if(FlxG.keys.justPressed.F2)
		#end
		{
			hudVisible = !hudVisible;
			refreshBoxes();
		}

		if(FlxG.keys.justPressed.F12) showSelection = !showSelection;

		var shiftMult:Float = FlxG.keys.pressed.SHIFT ? 4 : 1;
		var ctrlMult:Float = FlxG.keys.pressed.CONTROL ? 0.25 : 1;

		var camX:Float = 0;
		var camY:Float = 0;
		var camMove:Float = elapsed * 500 * shiftMult * ctrlMult;
		if(FlxG.keys.pressed.J) camX -= camMove;
		if(FlxG.keys.pressed.K) camY += camMove;
		if(FlxG.keys.pressed.L) camX += camMove;
		if(FlxG.keys.pressed.I) camY -= camMove;

		var mouseDX:Int = FlxG.mouse.deltaScreenX;
		var mouseDY:Int = FlxG.mouse.deltaScreenY;
		if(skipMouseDelta)
		{
			if(mouseDX != 0 || mouseDY != 0) skipMouseDelta = false;
			mouseDX = 0;
			mouseDY = 0;
		}

		var overUI:Bool = mouseOverUI();
		if(FlxG.mouse.justPressed) camDragging = !overUI && pickerDragging == 0;
		else if(!FlxG.mouse.pressed) camDragging = false;

		if(camDragging && (mouseDX != 0 || mouseDY != 0))
		{
			camX -= mouseDX / FlxG.camera.zoom;
			camY -= mouseDY / FlxG.camera.zoom;
		}
		FlxG.camera.scroll.x += camX;
		FlxG.camera.scroll.y += camY;

		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) resetCamera();
		else if(FlxG.keys.pressed.E && FlxG.camera.zoom < MAX_ZOOM)
			FlxG.camera.zoom = Math.min(MAX_ZOOM, FlxG.camera.zoom + elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
		else if(FlxG.keys.pressed.Q && FlxG.camera.zoom > MIN_ZOOM)
			FlxG.camera.zoom = Math.max(MIN_ZOOM, FlxG.camera.zoom - elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);

		if(!overUI && FlxG.mouse.wheel != 0)
			FlxG.camera.zoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, FlxG.camera.zoom + FlxG.mouse.wheel * 0.1));
	}

	override function draw()
	{
		if(persistentDraw || subState == null)
		{
			for (object in stageObjects)
				if(object.sprite != null && object.sprite.visible) object.sprite.draw();

			if(showSelection)
			{
				var target:String = rtxMode ? rtxTarget : (currentShaderEntry() != null ? Std.string(currentShaderEntry().target) : null);
				var sprite:FlxSprite = (target != null) ? targetSprite(target) : null;
				if(sprite != null && sprite.visible) drawSelection(sprite);
			}
		}
		super.draw();
	}

	function drawSelection(spr:FlxSprite)
	{
		if(!spr.isOnScreen(FlxG.camera)) return;

		var lineSize:Int = Std.int(Math.max(2, Math.floor(3 / FlxG.camera.zoom)));
		var bounds:FlxRect = visibleBounds(spr);
		var sprX:Float = bounds.x;
		var sprY:Float = bounds.y;
		var sprWidth:Int = Std.int(bounds.width);
		var sprHeight:Int = Std.int(bounds.height);
		bounds.put();
		for (num => sel in selectionSprites.members)
		{
			sel.x = sprX;
			sel.y = sprY;
			switch(num)
			{
				case 0:
					sel.setGraphicSize(sprWidth, lineSize);
				case 1:
					sel.setGraphicSize(sprWidth, lineSize);
					sel.y += sprHeight - lineSize;
				case 2:
					sel.setGraphicSize(lineSize, sprHeight);
				case 3:
					sel.setGraphicSize(lineSize, sprHeight);
					sel.x += sprWidth - lineSize;
			}
			sel.updateHitbox();
			sel.scrollFactor.set(spr.scrollFactor.x, spr.scrollFactor.y);
		}
		selectionSprites.draw();
	}

	override function destroy()
	{
		for (object in stageObjects)
			if(!object.character) FlxDestroyUtil.destroy(object.sprite);
		stageObjects = [];
		for (char in [gf, dad, boyfriend].concat(extraCharacters))
			FlxDestroyUtil.destroy(char);
		extraCharacters = [];
		selectionSprites = FlxDestroyUtil.destroy(selectionSprites);
		super.destroy();
	}
}
