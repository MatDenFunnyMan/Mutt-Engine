package funkin.modding;

import openfl.utils.Assets;
import flixel.util.FlxSave;
import haxe.Json;

typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	all:Array<String>
};

class Mods
{
	static public var currentModDirectory:String = '';
	public static final ignoreModFolders:Array<String> = [
		'content',
		'states',
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'achievements'
	];

	private static var globalMods:Array<String> = [];

	inline public static function getGlobalMods()
		return globalMods;

	inline public static function clearGlobalMods()
		globalMods = [];

	inline public static function pushGlobalMods()
	{
		globalMods = [];
		for(mod in parseList().enabled)
		{
			var pack:Dynamic = getPack(mod);
			if(pack != null && pack.runsGlobally) globalMods.push(mod);
		}
		return globalMods;
	}

	inline public static function getModDirectories():Array<String>
	{
		var list:Array<String> = [];
		#if MODS_ALLOWED
		var modsFolder:String = Paths.mods();
		if(FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder))
			{
				var path = haxe.io.Path.join([modsFolder, folder]);
				if (FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder.toLowerCase()) && !list.contains(folder))
					list.push(folder);
			}
		}
		#end
		return list;
	}
	
	inline public static function mergeAllTextsNamed(path:String, ?defaultDirectory:String = null, allowDuplicates:Bool = false)
	{
		if(defaultDirectory == null) defaultDirectory = Paths.getSharedPath();
		defaultDirectory = defaultDirectory.trim();
		if(!defaultDirectory.endsWith('/')) defaultDirectory += '/';
		if(!defaultDirectory.startsWith('assets/')) defaultDirectory = 'assets/$defaultDirectory';

		var mergedList:Array<String> = [];
		var paths:Array<String> = directoriesWithFile(defaultDirectory, path);

		var defaultPath:String = defaultDirectory + path;
		if(paths.contains(defaultPath))
		{
			paths.remove(defaultPath);
			paths.insert(0, defaultPath);
		}

		for (file in paths)
		{
			var list:Array<String> = CoolUtil.coolTextFile(file);
			for (value in list)
				if((allowDuplicates || !mergedList.contains(value)) && value.length > 0)
					mergedList.push(value);
		}
		return mergedList;
	}

	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true)
	{
		var foldersToCheck:Array<String> = [];
		var routed:String = Paths.routeKey(fileToFind);

		if(routed != null && FileSystem.exists('assets/$routed'))
			foldersToCheck.push('assets/$routed');

		if(FileSystem.exists(path + fileToFind))
			foldersToCheck.push(path + fileToFind);

		if(Paths.currentLevel != null && Paths.currentLevel != path)
		{
			var newPth:String = 'assets/' + Paths.routeLevelKey(fileToFind, Paths.currentLevel);
			if(!foldersToCheck.contains(newPth) && FileSystem.exists(newPth))
				foldersToCheck.push(newPth);

			var pth:String = Paths.getFolderPath(fileToFind, Paths.currentLevel);
			if(!foldersToCheck.contains(pth) && FileSystem.exists(pth))
				foldersToCheck.push(pth);
		}

		#if MODS_ALLOWED
		if(mods)
		{
			for(mod in Mods.getGlobalMods())
			{
				if(routed != null)
				{
					var newFolder:String = Paths.mods(mod + '/' + routed);
					if(FileSystem.exists(newFolder) && !foldersToCheck.contains(newFolder)) foldersToCheck.push(newFolder);
				}

				var folder:String = Paths.mods(mod + '/' + fileToFind);
				if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}

			if(routed != null)
			{
				var newFolder:String = Paths.mods(routed);
				if(FileSystem.exists(newFolder) && !foldersToCheck.contains(newFolder)) foldersToCheck.push(newFolder);
			}

			var folder:String = Paths.mods(fileToFind);
			if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);

			if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			{
				if(routed != null)
				{
					var newFolder:String = Paths.mods(Mods.currentModDirectory + '/' + routed);
					if(FileSystem.exists(newFolder) && !foldersToCheck.contains(newFolder)) foldersToCheck.push(newFolder);
				}

				var folder:String = Paths.mods(Mods.currentModDirectory + '/' + fileToFind);
				if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}
		}
		#end
		return foldersToCheck;
	}

	public static function getPack(?folder:String = null):Dynamic
	{
		#if MODS_ALLOWED
		if(folder == null) folder = Mods.currentModDirectory;

		var path = Paths.mods(folder + '/pack.json');
		if(FileSystem.exists(path)) {
			try {
				#if sys
				var rawJson:String = File.getContent(path);
				#else
				var rawJson:String = Assets.getText(path);
				#end
				if(rawJson != null && rawJson.length > 0) return tjson.TJSON.parse(rawJson);
			} catch(e:Dynamic) {
				trace(e);
			}
		}
		#end
		return null;
	}

	public static function getWindowTitle(?folder:String = null):String
	{
		#if MODS_ALLOWED
		var pack:Dynamic = getPack(folder);
		if(pack != null)
		{
			var change:Dynamic = pack.changeTitle;
			if(change != null && change == false)
				return funkin.Main.windowTitle;

			if(pack.windowTitle != null && Std.string(pack.windowTitle).length > 0)
				return Std.string(pack.windowTitle);

			if(pack.name != null && Std.string(pack.name).length > 0)
				return Std.string(pack.name);
		}
		#end
		return funkin.Main.windowTitle;
	}

	public static var updatedOnState:Bool = false;
	inline public static function parseList():ModsList {
		if(!updatedOnState) updateModList();
		var list:ModsList = {enabled: [], disabled: [], all: []};

		#if MODS_ALLOWED
		try {
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				if(mod.trim().length < 1) continue;

				var dat = mod.split("|");
				list.all.push(dat[0]);
				if (dat[1] == "1")
					list.enabled.push(dat[0]);
				else
					list.disabled.push(dat[0]);
			}
		} catch(e) {
			trace(e);
		}
		#end
		return list;
	}
	
	private static function updateModList()
	{
		#if MODS_ALLOWED
		var list:Array<Array<Dynamic>> = [];
		var added:Array<String> = [];
		try {
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				var dat:Array<String> = mod.split("|");
				var folder:String = dat[0];
				if(folder.trim().length > 0 && FileSystem.exists(Paths.mods(folder)) && FileSystem.isDirectory(Paths.mods(folder)) && !added.contains(folder))
				{
					added.push(folder);
					list.push([folder, (dat[1] == "1")]);
				}
			}
		} catch(e) {
			trace(e);
		}
		
		for (folder in getModDirectories())
		{
			if(folder.trim().length > 0 && FileSystem.exists(Paths.mods(folder)) && FileSystem.isDirectory(Paths.mods(folder)) &&
			!ignoreModFolders.contains(folder.toLowerCase()) && !added.contains(folder))
			{
				added.push(folder);
				list.push([folder, true]);
			}
		}

		var fileStr:String = '';
		for (values in list)
		{
			if(fileStr.length > 0) fileStr += '\n';
			fileStr += values[0] + '|' + (values[1] ? '1' : '0');
		}

		File.saveContent('modsList.txt', fileStr);
		updatedOnState = true;
		#end
	}

	public static function loadTopMod()
	{
		Mods.currentModDirectory = '';
		
		#if MODS_ALLOWED
		var list:Array<String> = Mods.parseList().enabled;
		if(list != null && list[0] != null)
			Mods.currentModDirectory = list[0];
		#end
	}

	public static function setActiveMod(modName:String):Bool
	{
		#if MODS_ALLOWED
		var modPath = Paths.mods(modName);
		if(FileSystem.exists(modPath) && FileSystem.isDirectory(modPath))
		{
			currentModDirectory = modName;
			
			var save:FlxSave = new FlxSave();
			save.bind('funkin', CoolUtil.getSavePath());
			if(save != null && save.data != null)
				save.data.currentMod = modName;
			save.flush();
			
			return true;
		}
		#end
		return false;
	}

	public static function loadSavedMod()
	{
		#if MODS_ALLOWED
		var save:FlxSave = new FlxSave();
		save.bind('funkin', CoolUtil.getSavePath());
		if(save != null && save.data != null && save.data.currentMod != null)
		{
			var savedMod:String = save.data.currentMod;
			if(savedMod != '' && FileSystem.exists(Paths.mods(savedMod)))
				currentModDirectory = savedMod;
		}
		#end
	}

	public static function getModName(folder:String):String
	{
		var pack:Dynamic = getPack(folder);
		if(pack != null && pack.name != null)
			return pack.name;
		return folder;
	}
}