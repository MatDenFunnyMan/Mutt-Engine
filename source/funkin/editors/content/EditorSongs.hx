package funkin.editors.content;

import funkin.data.Song;
import funkin.data.WeekData;
import funkin.ui.states.FreeplayState;

class EditorSongs
{
	static var songWeek:Map<String, String> = new Map<String, String>();
	static var difficultyFolders:Map<String, String> = new Map<String, String>();

	public static function songList():Array<String>
	{
		WeekData.reloadWeekFiles(false);

		var list:Array<String> = [];
		songWeek.clear();

		for (weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if(week == null || week.songs == null) continue;

			for (song in week.songs)
			{
				var songName:String = song[0];
				if(songName == null || songName.length < 1 || list.contains(songName)) continue;
				list.push(songName);
				songWeek.set(songName, weekName);
			}
		}
		return list;
	}

	public static function weekOf(songName:String):String
	{
		if(songName == null) return null;

		var cached:String = songWeek.get(songName);
		if(cached != null) return cached;

		if(WeekData.weeksList.length < 1) WeekData.reloadWeekFiles(false);

		var formatted:String = Paths.formatToSongPath(songName);
		for (weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if(week == null || week.songs == null) continue;

			for (song in week.songs)
			{
				if(song[0] != null && Paths.formatToSongPath(song[0]) == formatted)
				{
					songWeek.set(songName, weekName);
					return weekName;
				}
			}
		}
		return null;
	}

	public static function baseSongOf(songName:String):String
	{
		if(songName == null || weekOf(songName) != null) return songName;

		var formatted:String = Paths.formatToSongPath(songName);
		if(!formatted.endsWith('-erect')) return songName;

		var base:String = formatted.substr(0, formatted.length - '-erect'.length);
		var baseWeek:String = weekOf(base);
		if(baseWeek == null) return songName;

		var week:WeekData = WeekData.weeksLoaded.get(baseWeek);
		for (song in week.songs)
			if(song[0] != null && Paths.formatToSongPath(song[0]) == base) return song[0];
		return songName;
	}

	public static function difficulties(songName:String):Array<String>
	{
		var baseSong:String = baseSongOf(songName);
		var weekName:String = weekOf(baseSong);
		var week:WeekData = (weekName != null) ? WeekData.weeksLoaded.get(weekName) : null;

		if(week != null) Difficulty.loadFromWeek(week);
		else Difficulty.resetList();

		difficultyFolders.clear();
		var formatted:String = Paths.formatToSongPath(baseSong);
		var erectFolder:String = formatted + '-erect';
		for (diff in FreeplayState.ERECT_DIFFICULTIES)
		{
			var suffix:String = FreeplayState.difficultySuffix(diff);
			var index:Int = indexOf(diff);
			if(index > -1 && Song.findChartPath(formatted + suffix, formatted) != null) continue;
			if(Song.findChartPath(erectFolder + suffix, erectFolder) == null) continue;

			if(index < 0) Difficulty.list.push(diff);
			difficultyFolders.set(Paths.formatToSongPath(diff), erectFolder);
		}

		return Difficulty.list.copy();
	}

	public static function indexOf(name:String):Int
	{
		var key:String = Paths.formatToSongPath(name);
		for (i in 0...Difficulty.list.length)
			if(Paths.formatToSongPath(Difficulty.list[i]) == key) return i;
		return -1;
	}

	public static function songFolder(songName:String, index:Int):String
	{
		var diff:String = Difficulty.list[index];
		var folder:String = (diff != null) ? difficultyFolders.get(Paths.formatToSongPath(diff)) : null;
		return (folder != null) ? folder : baseSongOf(songName);
	}

	public static function chartFile(songName:String, index:Int):String
		return Paths.formatToSongPath(songFolder(songName, index)) + Difficulty.getFilePath(index);

	public static function loadChart(songName:String, diffName:String):Bool
	{
		difficulties(songName);
		var index:Int = indexOf(diffName);
		if(index < 0) return false;

		var previous = PlayState.SONG;
		try
		{
			Song.loadFromJson(chartFile(songName, index), songFolder(songName, index));
		}
		catch(e:Dynamic)
		{
			PlayState.SONG = previous;
			return false;
		}

		PlayState.storyDifficulty = index;
		PlayState.isStoryMode = false;
		return true;
	}
}
