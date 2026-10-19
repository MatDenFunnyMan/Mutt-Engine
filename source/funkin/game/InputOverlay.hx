package funkin.game;

import funkin.game.notes.StrumNote;
import funkin.input.InputFormatter;

class InputOverlay extends FlxSpriteGroup
{
	static inline final PANEL_X:Float = 28;
	static inline final CELL:Int = 40;
	static inline final BAR_WIDTH:Int = 100;
	static inline final BAR_HEIGHT:Int = 9;
	static inline final ROW_HEIGHT:Float = 52;
	static inline final BAR_SPEED:Float = 24;
	static inline final MS_FADE:Float = 2.2;
	static final BINDS:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];

	var strums:FlxTypedGroup<StrumNote>;
	var cells:Array<FlxSprite> = [];
	var bars:Array<FlxSprite> = [];
	var msTexts:Array<FlxText> = [];
	var stats:Array<FlxText> = [];
	var held:Array<Bool> = [];
	var holdTime:Array<Float> = [];
	var barFill:Array<Float> = [];
	var inputTimes:Array<Float> = [];
	var songTimes:Array<Float> = [];
	var inputPeak:Int = 0;

	public function new(strums:FlxTypedGroup<StrumNote>)
	{
		super();
		this.strums = strums;
		scrollFactor.set();

		var lanes:Int = BINDS.length;
		var startY:Float = (FlxG.height - lanes * ROW_HEIGHT) * 0.5 + (ROW_HEIGHT - CELL) * 0.5;
		var barX:Float = PANEL_X + CELL + 12;
		var msX:Float = barX + BAR_WIDTH + 10;
		var statsY:Float = startY + lanes * ROW_HEIGHT + 6;

		var panelX:Float = PANEL_X - 14;
		var panelY:Float = startY - 12;
		var panel:FlxSprite = new FlxSprite(panelX, panelY).makeGraphic(Std.int(msX + 84 - panelX + 14), Std.int(statsY + 80 - panelY + 10), FlxColor.BLACK);
		panel.alpha = 0.5;
		add(panel);

		for (i in 0...lanes)
		{
			var y:Float = startY + i * ROW_HEIGHT;

			var track:FlxSprite = new FlxSprite(barX, y + (CELL - BAR_HEIGHT) * 0.5).makeGraphic(BAR_WIDTH, BAR_HEIGHT, FlxColor.WHITE);
			track.alpha = 0.18;
			add(track);

			var bar:FlxSprite = new FlxSprite(barX, track.y).makeGraphic(BAR_WIDTH, BAR_HEIGHT, FlxColor.WHITE);
			bar.origin.x = 0;
			bar.scale.x = 0;
			bar.visible = false;
			add(bar);
			bars.push(bar);

			var cell:FlxSprite = new FlxSprite(PANEL_X, y).makeGraphic(CELL, CELL, FlxColor.WHITE);
			cell.alpha = 0.26;
			add(cell);
			cells.push(cell);

			var key:FlxText = new FlxText(PANEL_X, y + (CELL - 20) * 0.5, CELL, keyName(BINDS[i]), 17);
			key.setFormat(Paths.font('vcr.ttf'), 17, FlxColor.BLACK, CENTER);
			add(key);

			var ms:FlxText = new FlxText(msX, y + (CELL - 18) * 0.5, 84, '', 16);
			ms.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			ms.borderSize = 2;
			ms.alpha = 0;
			add(ms);
			msTexts.push(ms);

			held.push(false);
			holdTime.push(0);
			barFill.push(0);
		}

		for (i in 0...4)
		{
			var stat:FlxText = new FlxText(PANEL_X, statsY + i * 20, 240, '', 16);
			stat.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			stat.borderSize = 2;
			stat.alpha = 0.85;
			add(stat);
			stats.push(stat);
		}
	}

	static function keyName(bind:String):String
	{
		if(Controls.instance != null && Controls.instance.controllerMode)
		{
			var buttons = ClientPrefs.gamepadBinds.get(bind);
			if(buttons != null) for (button in buttons) if(button != NONE) return InputFormatter.getGamepadName(button);
		}
		var keys = ClientPrefs.keyBinds.get(bind);
		if(keys != null) for (key in keys) if(key != NONE) return InputFormatter.getKeyName(key);
		return '?';
	}

	public function registerNote()
		songTimes.push(Conductor.songPosition);

	function isHeld(lane:Int):Bool
	{
		var strum:StrumNote = (strums != null && lane < strums.length) ? strums.members[lane] : null;
		if(strum == null || strum.animation.curAnim == null) return false;
		return strum.animation.curAnim.name != 'static';
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		var songPosition:Float = Conductor.songPosition;

		for (i in 0...cells.length)
		{
			var down:Bool = isHeld(i);
			if(down && !held[i])
			{
				holdTime[i] = 0;
				inputTimes.push(songPosition);
				msTexts[i].alpha = 1;
			}
			held[i] = down;

			cells[i].alpha = down ? 1 : 0.26;
			cells[i].scale.set(down ? 1.1 : 1, down ? 1.1 : 1);

			barFill[i] += ((down ? 1 : 0) - barFill[i]) * Math.min(elapsed * BAR_SPEED, 1);
			bars[i].scale.x = barFill[i];
			bars[i].visible = barFill[i] > 0.001;

			if(down)
			{
				holdTime[i] += elapsed;
				msTexts[i].text = Math.round(holdTime[i] * 1000) + ' ms';
			}
			else if(msTexts[i].alpha > 0)
				msTexts[i].alpha = Math.max(0, msTexts[i].alpha - elapsed * MS_FADE);
		}

		prune(inputTimes, songPosition);
		prune(songTimes, songPosition);
		if(inputTimes.length > inputPeak) inputPeak = inputTimes.length;

		stats[0].text = 'SONG  ${songTimes.length} NPS';
		stats[1].text = 'INPUT ${inputTimes.length} NPS';
		stats[2].text = 'MAX   $inputPeak NPS';
		var bpm:Float = Conductor.bpm;
		var rounded:Int = Math.round(bpm);
		stats[3].text = 'BPM   ' + (Math.abs(bpm - rounded) < 0.005 ? Std.string(rounded) : Std.string(Math.round(bpm * 100) / 100));
	}

	static function prune(list:Array<Float>, songPosition:Float)
	{
		var cutoff:Float = songPosition - 1000;
		var count:Int = 0;
		while(count < list.length && list[count] < cutoff) count++;
		if(count > 0) list.splice(0, count);
	}
}
