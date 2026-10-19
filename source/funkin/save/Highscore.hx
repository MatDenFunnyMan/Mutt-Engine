package funkin.save;

class Highscore
{
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();
	public static var songMisses:Map<String, Int> = new Map<String, Int>();
	public static var songClears:Map<String, Float> = new Map<String, Float>();
	public static var songRanks:Map<String, String> = new Map<String, String>();

	public static function resetSong(song:String, diff:Int = 0):Void
	{
		var daSong:String = formatSong(song, diff);
		setScore(daSong, 0);
		setRating(daSong, 0);
		setMisses(daSong, 0);
		songClears.remove(daSong);
		songRanks.remove(daSong);
		FlxG.save.data.songClears = songClears;
		FlxG.save.data.songRanks = songRanks;
		FlxG.save.flush();
	}

	public static function resetWeek(week:String, diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);
		setWeekScore(daWeek, 0);
	}

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1, ?misses:Int = -1, ?clear:Float = -1, ?rank:String = null):Void
	{
		if(song == null) return;
		var daSong:String = formatSong(song, diff);

		if (songScores.exists(daSong))
		{
			if (songScores.get(daSong) < score)
			{
				setScore(daSong, score);
				if(rating >= 0) setRating(daSong, rating);
				if(misses >= 0) setMisses(daSong, misses);
				if(clear >= 0) setClear(daSong, clear, rank);
			}
		}
		else
		{
			setScore(daSong, score);
			if(rating >= 0) setRating(daSong, rating);
			if(misses >= 0) setMisses(daSong, misses);
			if(clear >= 0) setClear(daSong, clear, rank);
		}
	}

	public static function saveWeekScore(week:String, score:Int = 0, ?diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);

		if (weekScores.exists(daWeek))
		{
			if (weekScores.get(daWeek) < score)
				setWeekScore(daWeek, score);
		}
		else setWeekScore(daWeek, score);
	}

	/**
	 * YOU SHOULD FORMAT SONG WITH formatSong() BEFORE TOSSING IN SONG VARIABLE
	 */
	static function setScore(song:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songScores.set(song, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}
	static function setWeekScore(week:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		weekScores.set(week, score);
		FlxG.save.data.weekScores = weekScores;
		FlxG.save.flush();
	}

	static function setRating(song:String, rating:Float):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songRating.set(song, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	static function setMisses(song:String, misses:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songMisses.set(song, misses);
		FlxG.save.data.songMisses = songMisses;
		FlxG.save.flush();
	}

	static function setClear(song:String, clear:Float, rank:String):Void
	{
		songClears.set(song, clear);
		if(rank != null) songRanks.set(song, rank);
		else songRanks.remove(song);
		FlxG.save.data.songClears = songClears;
		FlxG.save.data.songRanks = songRanks;
		FlxG.save.flush();
	}

	public static function formatSong(song:String, diff:Int):String
	{
		return Paths.formatToSongPath(song) + Difficulty.getFilePath(diff);
	}

	private static function resolveDiff(diff:Dynamic):Int
	{
		if (Std.isOfType(diff, String)) {
			var diffStr:String = cast(diff, String).toLowerCase();
			for (i in 0...Difficulty.list.length)
				if (Difficulty.list[i].toLowerCase() == diffStr)
					return i;
			return 0;
		}
		var idx:Int = Std.int(diff);
		if (idx < 0 || idx >= Difficulty.list.length) return 0;
		return idx;
	}

	public static function getScore(song:String, diff:Dynamic):Int
	{
		var daSong:String = formatSong(song, resolveDiff(diff));
		if (!songScores.exists(daSong))
			return 0;

		return songScores.get(daSong);
	}

	public static function getRating(song:String, diff:Dynamic):Float
	{
		var daSong:String = formatSong(song, resolveDiff(diff));
		if (!songRating.exists(daSong))
			return 0;

		return songRating.get(daSong);
	}

	public static function getMisses(song:String, diff:Dynamic):Int
	{
		var daSong:String = formatSong(song, resolveDiff(diff));
		if (!songMisses.exists(daSong))
			return -1;

		return songMisses.get(daSong);
	}

	public static function getWeekScore(week:String, diff:Int):Int
	{
		var daWeek:String = formatSong(week, diff);
		if (!weekScores.exists(daWeek))
			setWeekScore(daWeek, 0);

		return weekScores.get(daWeek);
	}

	public static function load():Void
	{
		if (FlxG.save.data.weekScores != null)
			weekScores = FlxG.save.data.weekScores;

		if (FlxG.save.data.songScores != null)
			songScores = FlxG.save.data.songScores;

		if (FlxG.save.data.songRating != null)
			songRating = FlxG.save.data.songRating;

		if (FlxG.save.data.songMisses != null)
			songMisses = FlxG.save.data.songMisses;

		if (FlxG.save.data.songClears != null)
			songClears = FlxG.save.data.songClears;

		if (FlxG.save.data.songRanks != null)
			songRanks = FlxG.save.data.songRanks;
	}
}