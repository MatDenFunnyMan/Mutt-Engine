package funkin.editors.content;

import flixel.FlxBasic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxDestroyUtil;

import funkin.editors.content.Prompt.BasePrompt;
import funkin.ui.HealthIcon;
import funkin.ui.HealthIcon.IconAnimData;
import funkin.ui.HealthIcon.IconAnimFile;

class IconAnimationPrompt extends BasePrompt
{
	static inline final BOX_W:Int = 700;
	static inline final BOX_H:Int = 440;
	static inline final PREVIEW_SIZE:Int = 220;
	static inline final NO_PREFIX:String = '(none)';
	static final STATE_LABELS:Array<String> = ['Neutral', 'Losing', 'Winning', 'Beating'];

	public var onSaved:Void->Void;

	var iconKey:String;
	var isPlayer:Bool;
	var atlas:FlxAtlasFrames;
	var prefixes:Array<String> = [];
	var data:Array<IconAnimData> = [null, null, null, null];
	var curState:Int = 0;
	var loadingFields:Bool = false;

	var previewBg:FlxSprite;
	var preview:FlxSprite;
	var summaryText:FlxText;
	var statusText:FlxText;

	var stateDrop:PsychUIDropDownMenu;
	var prefixDrop:PsychUIDropDownMenu;
	var indicesInput:PsychUIInputText;
	var fpsStepper:PsychUINumericStepper;
	var loopCheck:PsychUICheckBox;
	var offsetXStepper:PsychUINumericStepper;
	var offsetYStepper:PsychUINumericStepper;

	var fileDialog:FileDialogHandler = new FileDialogHandler();

	public function new(iconKey:String, ?isPlayer:Bool = false)
	{
		this.iconKey = iconKey;
		this.isPlayer = isPlayer;
		super(BOX_W, BOX_H, 'Icon Animations');
	}

	override function create()
	{
		super.create();

		closeCallback = function() PsychUIInputText.focusOn = null;

		atlas = Paths.getSparrowAtlas(iconKey, null, false);
		prefixes = collectPrefixes(atlas);
		loadData();

		var leftX:Float = bg.x + 25;
		var topY:Float = bg.y + 70;
		var labelX:Float = bg.x + 275;
		var fieldX:Float = bg.x + 385;

		previewBg = new FlxSprite(leftX, topY).makeGraphic(PREVIEW_SIZE, PREVIEW_SIZE, 0xFF222222);
		addUI(previewBg);

		preview = new FlxSprite();
		preview.frames = atlas;
		preview.antialiasing = ClientPrefs.data.antialiasing;
		addUI(preview);

		summaryText = new FlxText(leftX, topY + PREVIEW_SIZE + 10, PREVIEW_SIZE + 20, '', 12);
		summaryText.setFormat(Paths.font('vcr.ttf'), 12, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		summaryText.borderSize = 1;
		addUI(summaryText);

		addUI(makeLabel(labelX, topY, 'State:'));
		addUI(makeLabel(labelX, topY + 40, 'XML Prefix:'));
		addUI(makeLabel(labelX, topY + 80, 'Indices:'));
		addUI(makeLabel(labelX, topY + 120, 'Framerate:'));
		addUI(makeLabel(labelX, topY + 160, 'Offset X/Y:'));

		indicesInput = new PsychUIInputText(fieldX, topY + 80, 260, '', 8);
		indicesInput.onChange = function(_, _) onFieldChanged();
		addUI(indicesInput);

		fpsStepper = new PsychUINumericStepper(fieldX, topY + 120, 1, 24, 1, 240, 0);
		fpsStepper.onValueChange = onFieldChanged;
		addUI(fpsStepper);

		loopCheck = new PsychUICheckBox(fieldX + 110, topY + 119, 'Loop', 60);
		loopCheck.onClick = onFieldChanged;
		addUI(loopCheck);

		offsetXStepper = new PsychUINumericStepper(fieldX, topY + 160, 1, 0, -500, 500, 0);
		offsetXStepper.onValueChange = onFieldChanged;
		addUI(offsetXStepper);

		offsetYStepper = new PsychUINumericStepper(fieldX + 110, topY + 160, 1, 0, -500, 500, 0);
		offsetYStepper.onValueChange = onFieldChanged;
		addUI(offsetYStepper);

		var hint:FlxText = new FlxText(labelX, topY + 200, 385, 'Indices: "0,1,2" or "0-5". Leave empty to use every frame of the prefix.\n\nSave the file next to the icon:\n' + iconFilePath(), 8);
		hint.setFormat(null, 8, 0xFFBBBBBB, LEFT);
		addUI(hint);

		statusText = new FlxText(bg.x, bg.y + BOX_H - 76, BOX_W, '', 12);
		statusText.setFormat(Paths.font('vcr.ttf'), 12, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		statusText.borderSize = 1;
		addUI(statusText);

		var btnY:Float = bg.y + BOX_H - 44;
		addUI(new PsychUIButton(bg.x + BOX_W * 0.5 - 160, btnY, 'Save JSON', saveFile, 150, 24));
		addUI(new PsychUIButton(bg.x + BOX_W * 0.5 + 10, btnY, 'Close', function() close(), 150, 24));

		prefixDrop = new PsychUIDropDownMenu(fieldX, topY + 40, [''], function(_, _) onFieldChanged(), 260);
		prefixDrop.list = [NO_PREFIX].concat(prefixes);
		addUI(prefixDrop);

		stateDrop = new PsychUIDropDownMenu(fieldX, topY, [''], function(_, label:String) selectState(STATE_LABELS.indexOf(label)), 160);
		stateDrop.autoSort = false;
		stateDrop.list = STATE_LABELS.copy();
		addUI(stateDrop);

		selectState(0);
	}

	override function destroy()
	{
		fileDialog = FlxDestroyUtil.destroy(fileDialog);
		super.destroy();
	}

	function addUI(obj:FlxBasic)
	{
		obj.cameras = cameras;
		add(obj);
	}

	function makeLabel(x:Float, y:Float, label:String):FlxText
	{
		var txt:FlxText = new FlxText(x, y + 2, 110, label, 14);
		txt.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		txt.borderSize = 1;
		return txt;
	}

	function iconFilePath():String
	{
		var path:String = Paths.getPath('images/$iconKey.png', IMAGE);
		return path.substr(0, path.length - 4) + '.json';
	}

	static function collectPrefixes(frames:FlxAtlasFrames):Array<String>
	{
		var result:Array<String> = [];
		if(frames == null || frames.frames == null) return result;

		var digits:EReg = ~/\d+$/;
		for (frame in frames.frames)
		{
			if(frame == null || frame.name == null) continue;

			var prefix:String = digits.replace(frame.name, '');
			if(prefix.length > 0 && !result.contains(prefix)) result.push(prefix);
		}
		return result;
	}

	function loadData()
	{
		var file:IconAnimFile = HealthIcon.readAnimFile(iconKey);
		if(file != null)
		{
			for (anim in file.animations)
			{
				if(anim == null) continue;

				var state:Int = HealthIcon.stateFromName(anim.state);
				if(state < 0 || anim.prefix == null || anim.prefix.length < 1) continue;

				data[state] = {
					state: HealthIcon.STATE_NAMES[state],
					prefix: anim.prefix,
					indices: (anim.indices != null) ? anim.indices.copy() : [],
					fps: (anim.fps != null) ? anim.fps : 24,
					loop: (anim.loop != false),
					offsets: (anim.offsets != null && anim.offsets.length > 1) ? [anim.offsets[0], anim.offsets[1]] : [0, 0]
				};
			}
			return;
		}

		for (state => list in HealthIcon.STATE_PREFIXES)
		{
			for (prefix in list)
			{
				if(!prefixes.contains(prefix)) continue;

				data[state] = {
					state: HealthIcon.STATE_NAMES[state],
					prefix: prefix,
					indices: [],
					fps: 24,
					loop: true,
					offsets: [0, 0]
				};
				break;
			}
		}
	}

	function selectState(state:Int)
	{
		if(state < 0 || state >= STATE_LABELS.length) state = 0;
		curState = state;

		loadingFields = true;
		stateDrop.selectedLabel = STATE_LABELS[state];

		var anim:IconAnimData = data[state];
		if(anim != null)
		{
			prefixDrop.selectedLabel = anim.prefix;
			if(prefixDrop.selectedLabel == null) prefixDrop.selectedLabel = NO_PREFIX;
			indicesInput.text = (anim.indices != null) ? anim.indices.join(',') : '';
			fpsStepper.value = (anim.fps != null) ? anim.fps : 24;
			loopCheck.checked = (anim.loop != false);
			offsetXStepper.value = anim.offsets[0];
			offsetYStepper.value = anim.offsets[1];
		}
		else
		{
			prefixDrop.selectedLabel = NO_PREFIX;
			indicesInput.text = '';
			fpsStepper.value = 24;
			loopCheck.checked = true;
			offsetXStepper.value = 0;
			offsetYStepper.value = 0;
		}
		loadingFields = false;

		refreshPreview();
		refreshSummary();
	}

	function onFieldChanged()
	{
		if(loadingFields) return;

		var prefix:String = prefixDrop.selectedLabel;
		if(prefix == null || prefix == NO_PREFIX)
			data[curState] = null;
		else
		{
			data[curState] = {
				state: HealthIcon.STATE_NAMES[curState],
				prefix: prefix,
				indices: parseIndices(indicesInput.text),
				fps: fpsStepper.value,
				loop: loopCheck.checked,
				offsets: [offsetXStepper.value, offsetYStepper.value]
			};
		}

		refreshPreview();
		refreshSummary();
	}

	static function parseIndices(text:String):Array<Int>
	{
		var indices:Array<Int> = [];
		if(text == null) return indices;

		for (rawPart in text.split(','))
		{
			var part:String = rawPart.trim();
			if(part.length < 1) continue;

			if(part.contains('-'))
			{
				var range:Array<String> = part.split('-');
				var start:Null<Int> = Std.parseInt(range[0].trim());
				var end:Null<Int> = Std.parseInt(range[1].trim());
				if(start == null || start < 0) start = 0;
				if(end == null || end < start) end = start;
				for (i in start...end + 1) indices.push(i);
			}
			else
			{
				var index:Null<Int> = Std.parseInt(part);
				if(index != null && index > -1) indices.push(index);
			}
		}
		return indices;
	}

	function refreshPreview()
	{
		preview.animation.destroyAnimations();
		statusText.text = '';

		var anim:IconAnimData = data[curState];
		if(anim == null)
		{
			preview.visible = false;
			return;
		}

		if(anim.indices != null && anim.indices.length > 0)
			preview.animation.addByIndices('preview', anim.prefix, anim.indices, '', anim.fps, anim.loop, isPlayer);
		else
			preview.animation.addByPrefix('preview', anim.prefix, anim.fps, anim.loop, isPlayer);

		if(!preview.animation.exists('preview'))
		{
			preview.visible = false;
			showStatus('No frames found for this prefix/indices.', true);
			return;
		}

		preview.visible = true;
		preview.animation.play('preview', true);

		preview.scale.set(1, 1);
		preview.updateHitbox();
		var fit:Float = Math.min(1, (PREVIEW_SIZE - 20) / Math.max(preview.frameWidth, preview.frameHeight));
		preview.scale.set(fit, fit);
		preview.updateHitbox();
		preview.x = previewBg.x + (PREVIEW_SIZE - preview.width) / 2;
		preview.y = previewBg.y + (PREVIEW_SIZE - preview.height) / 2;
		preview.offset.x += anim.offsets[0];
		preview.offset.y += anim.offsets[1];
	}

	function refreshSummary()
	{
		var lines:Array<String> = [];
		for (state => label in STATE_LABELS)
		{
			var anim:IconAnimData = data[state];
			var mark:String = (state == curState) ? '> ' : '  ';
			lines.push(mark + label + ': ' + (anim != null ? anim.prefix : '-'));
		}
		summaryText.text = lines.join('\n');
	}

	function showStatus(text:String, isError:Bool = false)
	{
		statusText.text = text;
		statusText.color = isError ? 0xFFFF5555 : FlxColor.WHITE;
	}

	function saveFile()
	{
		if(data[HealthIcon.STATE_NEUTRAL] == null)
		{
			showStatus('The Neutral state needs a prefix.', true);
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			return;
		}

		var animations:Array<Dynamic> = [];
		for (anim in data)
		{
			if(anim == null) continue;

			var out:Dynamic = {
				state: anim.state,
				prefix: anim.prefix,
				fps: anim.fps,
				loop: anim.loop,
				offsets: anim.offsets
			};
			if(anim.indices != null && anim.indices.length > 0) out.indices = anim.indices;
			animations.push(out);
		}

		var json:String = PsychJsonPrinter.print({animations: animations}, ['offsets', 'indices']);
		var parts:Array<String> = iconKey.split('/');
		fileDialog.save(parts[parts.length - 1] + '.json', json,
			function() {
				showStatus('Saved to: ' + fileDialog.path);
				if(onSaved != null) onSaved();
			}, null,
			function() showStatus('Error on saving the icon animations!', true));
	}
}
