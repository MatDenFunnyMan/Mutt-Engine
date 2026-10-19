package funkin.editors.content;

import funkin.data.Song;
import funkin.data.WeekData;
import funkin.ui.states.FreeplayState;

class EditorSongs
{
	static var songWeek:Map<String, String> = new Map<String, String>();
	static var difficultyFolders:Map<String, String> = new Map<String, String>();
	static var looseDifficulties:Map<String, Array<String>> = new Map<String, Array<String>>();
	static final HIDDEN_BASE_SONGS:Array<String> = ['ridge', 'smash'];

	public static function songList():Array<String>
	{
		WeekData.reloadWeekFiles(false);

		songWeek.clear();
		looseDifficulties.clear();

		var currentMod:String = (Mods.currentModDirectory != null) ? Mods.currentModDirectory : '';
		var modSongs:Array<String> = [];
		var otherSongs:Array<String> = [];
		var known:Array<String> = [];

		for (weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if(week == null || week.songs == null) continue;

			var target:Array<String> = (currentMod.length > 0 && week.folder == currentMod) ? modSongs : otherSongs;
			for (song in week.songs)
			{
				var songName:String = song[0];
				if(songName == null || songName.length < 1) continue;
				var formatted:String = Paths.formatToSongPath(songName);
				if(known.contains(formatted)) continue;
				known.push(formatted);
				target.push(songName);
				songWeek.set(songName, weekName);
			}
		}

		for (loose in looseSongs(known))
			((currentMod.length > 0 && loose[1] == currentMod) ? modSongs : otherSongs).push(loose[0]);

		return modSongs.concat(otherSongs);
	}

	static function looseSongs(known:Array<String>):Array<Array<String>>
	{
		var result:Array<Array<String>> = [];
		#if sys
		var roots:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'data/songs/').concat(Mods.directoriesWithFile(Paths.getSharedPath(), 'data/'));
		for (root in roots)
		{
			if(!FileSystem.exists(root) || !FileSystem.isDirectory(root)) continue;
			if(!root.endsWith('/')) root += '/';
			for (entry in FileSystem.readDirectory(root))
			{
				if(!FileSystem.isDirectory(root + entry)) continue;
				var formatted:String = Paths.formatToSongPath(entry);
				if(known.contains(formatted)) continue;
				if(!root.startsWith(Paths.mods()) && HIDDEN_BASE_SONGS.contains(formatted)) continue;
				if(formatted.endsWith('-erect') && known.contains(formatted.substr(0, formatted.length - '-erect'.length))) continue;

				var diffs:Array<String> = chartDifficulties(formatted);
				if(diffs.length < 1) continue;

				known.push(formatted);
				looseDifficulties.set(formatted, diffs);
				result.push([entry, modOf(root)]);
			}
		}
		#end
		return result;
	}

	static function chartDifficulties(song:String):Array<String>
	{
		var saved:Array<String> = Difficulty.list;
		Difficulty.resetList();
		var found:Array<String> = [];
		for (i in 0...Difficulty.list.length)
			if(Song.findChartPath(song + Difficulty.getFilePath(i), song) != null) found.push(Difficulty.list[i]);
		Difficulty.list = saved;
		return found;
	}

	static function modOf(root:String):String
	{
		var mods:String = Paths.mods();
		if(!root.startsWith(mods)) return '';
		var rest:String = root.substr(mods.length);
		var slash:Int = rest.indexOf('/');
		var name:String = (slash > 0) ? rest.substr(0, slash) : '';
		return (name == 'data') ? '' : name;
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
		var loose:Array<String> = (songName != null) ? looseDifficulties.get(Paths.formatToSongPath(songName)) : null;
		if(loose != null && weekOf(songName) == null)
		{
			Difficulty.list = loose.copy();
			difficultyFolders.clear();
			return Difficulty.list.copy();
		}

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
