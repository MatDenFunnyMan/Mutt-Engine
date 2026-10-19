package funkin.game.notes;

import funkin.data.Song.ExtraCharacterData;

typedef ExtraStrumline =
{
	var strums:FlxTypedGroup<StrumNote>;
	var scale:Float;
	var player:Bool;
}

class ExtraStrumlineLayout
{
	public static inline final ROW_SCALE:Float = 0.8;

	public static function playable(data:ExtraCharacterData):Bool
		return (data.playable != null) ? data.playable : data.parent == 'bf';

	public static function isPlayer(data:ExtraCharacterData, opponentMode:Bool):Bool
		return playable(data) != (opponentMode && data.parent != 'gf');

	public static function speedMultiplier(data:ExtraCharacterData, chartSpeed:Float):Float
	{
		if(data.usesChartScroll == true || data.scrollSpeed == null || data.scrollSpeed <= 0 || chartSpeed <= 0) return 1;
		return data.scrollSpeed / chartSpeed;
	}

	public static function sharesMainRow(list:Array<ExtraCharacterData>):Bool
	{
		if(list == null || ClientPrefs.data.middleScroll) return false;
		var visible:Int = 0;
		for (data in list)
			if(data.visible != false) visible++;
		return visible == 1;
	}

	static function column(data:ExtraCharacterData, opponentMode:Bool):Int
	{
		if(ClientPrefs.data.middleScroll)
			return isPlayer(data, opponentMode) ? 1 : (data.parent == 'dad' ? 0 : 2);

		var playerSide:Bool = data.parent == 'bf' || (data.parent == 'gf' && playable(data));
		return playerSide ? 2 : 0;
	}

	static function thirdX(column:Int):Float
		return FlxG.width * (1 + column * 2) / 6;

	static function parentX(column:Int, arrowWidth:Float):Float
	{
		if(ClientPrefs.data.middleScroll)
		{
			if(column != 1) return thirdX(column);
			return PlayState.STRUM_X_MIDDLESCROLL + 50 + FlxG.width / 2 + Note.swagWidth * 1.5 + arrowWidth / 2;
		}
		var left:Float = PlayState.STRUM_X + 50 + Note.swagWidth * 1.5 + arrowWidth / 2;
		return (column == 0) ? left : left + FlxG.width / 2;
	}

	static function placeLine(strums:Array<StrumNote>, centerX:Float, spacing:Float)
	{
		for (i => strum in strums)
			strum.x = centerX + spacing * (i - 1.5) - strum.width / 2;
	}

	public static function fitMainRow(opponentStrums:FlxTypedGroup<StrumNote>, playerStrums:FlxTypedGroup<StrumNote>):Float
	{
		for (group in [opponentStrums, playerStrums])
		{
			if(group == null || group.length < 1) continue;
			placeLine(group.members, thirdX(group == opponentStrums ? 0 : 2), Note.swagWidth * ROW_SCALE);
			for (strum in group.members)
				strum.scale.set(strum.scale.x * ROW_SCALE, strum.scale.y * ROW_SCALE);
		}
		return ROW_SCALE;
	}

	public static function create(list:Array<ExtraCharacterData>, opponentMode:Bool, fadeIn:Bool):Array<ExtraStrumline>
	{
		var lines:Array<ExtraStrumline> = [];
		if(list == null || list.length < 1) return lines;

		var mainRow:Bool = sharesMainRow(list);
		var rowCounts:Array<Int> = [0, 0, 0];
		var columns:Array<Int> = [];
		var rowOf:Array<Int> = [];
		for (data in list)
		{
			var col:Int = column(data, opponentMode);
			var row:Int = 1;
			if(data.visible != false)
			{
				if(mainRow) row = 0;
				else row = ++rowCounts[col];
			}
			columns.push(col);
			rowOf.push(row);
		}

		var downScroll:Bool = ClientPrefs.data.downScroll;
		var mainY:Float = downScroll ? (FlxG.height - 150) : 50;
		var maxRows:Int = Std.int(Math.max(1, Math.max(rowCounts[0], Math.max(rowCounts[1], rowCounts[2]))));
		var rowStep:Float = Math.min(Note.swagWidth, (FlxG.height - 200) / maxRows) * (downScroll ? -1 : 1);
		for (index => data in list)
		{
			var player:Bool = isPlayer(data, opponentMode);
			var lineScale:Float = ROW_SCALE * ((data.scale != null && data.scale > 0) ? data.scale : 1);
			var spacing:Float = (data.spacing != null && data.spacing > 0) ? data.spacing : Note.swagWidth * lineScale;
			var y:Float = mainY + rowStep * rowOf[index];
			if(data.hudY != null) y += downScroll ? -data.hudY : data.hudY;

			var targetAlpha:Float = (data.alpha != null) ? Math.max(0, Math.min(1, data.alpha)) : 1;
			if(!player)
			{
				if(!ClientPrefs.data.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.data.middleScroll) targetAlpha *= 0.35;
			}

			var strums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
			for (i in 0...4)
			{
				var babyArrow:StrumNote = new StrumNote(0, y, i, player ? 1 : 0, !isPlayer(data, false));
				babyArrow.downScroll = downScroll;
				babyArrow.scale.set(babyArrow.scale.x * lineScale, babyArrow.scale.y * lineScale);
				babyArrow.visible = data.visible != false;
				strums.add(babyArrow);
			}

			var centerX:Float = (rowOf[index] == 0) ? thirdX(1) : parentX(columns[index], strums.members[0].width);
			if(data.hudX != null) centerX += data.hudX;
			placeLine(strums.members, centerX, spacing);

			for (i => babyArrow in strums.members)
			{
				if(fadeIn)
				{
					babyArrow.alpha = 0;
					FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
				}
				else babyArrow.alpha = targetAlpha;
			}
			lines.push({strums: strums, scale: lineScale, player: player});
		}
		return lines;
	}
}
