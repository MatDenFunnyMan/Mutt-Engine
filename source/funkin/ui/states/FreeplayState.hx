package funkin.ui.states;

import funkin.data.WeekData;
import funkin.data.MetaData;
import funkin.save.Highscore;
import funkin.data.Song;
import funkin.backend.StateManager;

import funkin.ui.freeplay.FreeplayPlayer;
import funkin.ui.freeplay.FreeplaySongRow;
import funkin.ui.freeplay.FreeplayDifficulty;
import funkin.ui.freeplay.FreeplayScorePanel;
import funkin.ui.freeplay.FreeplayCard;
import funkin.ui.results.ResultsRank;
import funkin.ui.results.ResultsRank.RankData;

import funkin.ui.options.GameplayChangersSubstate;
import funkin.ui.states.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.addons.display.FlxBackdrop;
import flixel.tweens.FlxEase.EaseFunction;
import flixel.system.FlxAssets;
import flixel.util.FlxDestroyUtil;

import openfl.display.BlendMode;
import openfl.media.Sound;
#if lime_vorbis
import haxe.io.Bytes;
import lime.media.AudioBuffer;
import lime.media.vorbis.VorbisFile;
import lime.utils.UInt8Array;
#end
#if target.threaded
import sys.thread.Deque;
import sys.thread.Thread;
#end

class FreeplayState extends MusicBeatState
{
	public static final ERECT_DIFFICULTIES:Array<String> = ['Erect', 'Nightmare'];

	static inline final ROW_X:Float = 62;
	static inline final ROW_Y:Float = 386;
	static inline final ROW_SPACING:Float = 130;
	static inline final ROW_SPACING_FAR:Float = 100;
	static inline final ROW_INDENT:Float = 90;
	static inline final ROW_INDENT_FAR:Float = 40;
	static inline final ROW_SCALE_FAR:Float = 0.65;
	static inline final ROW_ALPHA_FAR:Float = 0.6;
	static inline final DRAW_DISTANCE:Int = 4;

	static inline final PREVIEW_DELAY:Float = 0.1;
	static inline final PREVIEW_LENGTH:Float = 15;
	static inline final PREVIEW_FADE:Float = 1;
	static inline final PREVIEW_VOLUME:Float = 0.8;

	static inline final HINT_X:Float = 591;
	static inline final HINT_Y:Float = 56;
	static inline final HINT_PERIOD:Float = 2.4;
	static inline final HINT_MIN_ALPHA:Float = 0.3;
	static inline final RANDOM_COLOR:Int = 0xFF808080;
	static inline final CONFIRM_DELAY:Float = 0.8;
	static inline final MOUSE_HIDE_TIME:Float = 2;
	static inline final MENU_MUSIC_DIM:Float = 0.5;
	static inline final FLASH_TIME:Float = 0.5;
	static inline final REVEAL_DELAY:Float = 0.5;
	static inline final BACKDROP_SCALE:Float = 2;
	static inline final BACKDROP_ALPHA:Float = 0.3;
	static inline final BACKDROP_SPEED:Float = 24;
	static inline final BACKDROP_RESUME_TIME:Float = 1.5;
	static inline final VORBIS_HOLE:Int = -3;
	static inline final MAX_VORBIS_HOLES:Int = 16;

	var songs:Array<SongMetadata> = [];
	var allSongs:Array<SongMetadata> = [];
	var randomSong:SongMetadata;

	private static var curSelected:Int = 1;
	private static var curPlayerId:String = 'bf';
	private static var lastDifficultyName:String = Difficulty.getDefault();
	var lerpSelected:Float = 0;
	var curDifficulty:Int = 0;
	var player:FreeplayPlayer;
	var canSwitchPlayer:Bool = false;

	var bg:FlxSprite;
	var intendedColor:Int;
	var rows:FlxTypedGroup<FreeplaySongRow>;
	var visibleRows:Array<FreeplaySongRow> = [];
	var difficultySelector:FreeplayDifficulty;
	var scorePanel:FreeplayScorePanel;
	var card:FreeplayCard;
	var busy:Bool = false;
	var musicDimTween:FlxTween;
	var menuOpen:Bool = false;

	public static var completedRank:Null<ResultsRank> = null;
	static var completedSong:String = null;
	static var lastPlayedSong:String = null;
	static var lastPlayedFolder:String = null;
	static var lastPlayedDifficulty:String = null;
	static var lastPlayedRank:Null<ResultsRank> = null;
	var pendingResult:Null<ResultsRank> = null;
	var revealRow:FreeplaySongRow = null;
	var revealOldRank:Null<ResultsRank> = null;
	var revealNewRank:Null<ResultsRank> = null;
	var revealZoom:Float = 1;
	var revealZoomTween:FlxTween;
	var rankDim:FlxSprite;
	var sparks:FlxSprite;
	var sparksAdd:FlxSprite;
	var mouseIdleTime:Float = 0;
	var switchHint:FlxText;
	var hintTime:Float = 0;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var tabList:Array<String> = [];
	private static var curTab:Int = 0;
	var tabBG:FlxSprite;
	var tabText:FlxText;
	var tabHint:FlxText;
	var isMultiModMode:Bool = false;

	var previewTimer:FlxTimer;
	var previewKey:String = null;
	var previewSound:Sound = null;
	var previewCached:Bool = false;
	var previewStartTime:Float = 0;
	var previewEndTime:Float = -1;
	var previewFading:Bool = false;
	var previewRequest:Int = 0;
	var backdrop:FlxBackdrop;
	var backdropSpeed:Float = 1;
	var backdropTween:FlxTween;
	var pendingClipKey:String = null;
	#if (lime_vorbis && target.threaded)
	var clipQueue:Deque<PreviewClip> = new Deque<PreviewClip>();
	#end

	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;
	var stopMusicPlay:Bool = false;

	function getCurrentModMode():String
	{
		var save = FlxG.save;

		if(save != null && save.data != null && save.data.modMode != null)
		{
			var mode:String = save.data.modMode;
			if(mode == 'MODS + FNF SONGS' || mode == 'ALL MODS' || mode == 'DISABLE MODS')
				return mode;
		}

		if(Mods.currentModDirectory != null && Mods.currentModDirectory != '')
			return 'SINGLE MOD';

		return 'DISABLE MODS';
	}

	override function create()
	{
		Paths.clearStoredMemory();

		#if MODS_ALLOWED
		var currentMode = getCurrentModMode();
		if(currentMode == 'ALL MODS' || currentMode == 'MODS + FNF SONGS')
		{
			Mods.currentModDirectory = '';
			Mods.clearGlobalMods();
		}
		#end

		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if MODS_ALLOWED
		if(currentMode == 'MODS + FNF SONGS' || currentMode == 'ALL MODS' || currentMode == 'DISABLE MODS')
		{
			lime.app.Application.current.window.title = Main.windowTitle;
		}
		#end

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		DiscordClient.changePresence("In the Menus", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new funkin.ui.states.ErrorState("THERE ARE NO SONGS AVAILABLE IN FREEPLAY!\n\nMAKE A WEEK IN the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new funkin.editors.WeekEditorState()),
				function() StateManager.switchState('MainMenuState')));
			return;
		}

		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

			#if MODS_ALLOWED
			var shouldSkip = false;

			switch(currentMode)
			{
				case 'SINGLE MOD':
					if(Mods.currentModDirectory != '' && leWeek.folder == '')
						shouldSkip = true;

				case 'ALL MODS':
					if(leWeek.folder == '')
						shouldSkip = true;

				case 'MODS + FNF SONGS':
					shouldSkip = false;

				case 'DISABLE MODS':
					if(leWeek.folder != '')
						shouldSkip = true;
			}

			if(shouldSkip) continue;
			#end

			WeekData.setDirectoryFromWeek(leWeek);
			Difficulty.loadFromWeek(leWeek);
			var weekDifficulties:Array<String> = Difficulty.list.copy();
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]), weekDifficulties);
			}
		}
		#if MODS_ALLOWED
		var _modeAfterLoad = getCurrentModMode();
		if(_modeAfterLoad == 'ALL MODS' || _modeAfterLoad == 'MODS + FNF SONGS')
		{
			Mods.currentModDirectory = '';
			Mods.clearGlobalMods();
		}
		else
		{
			Mods.loadTopMod();
		}
		#else
		Mods.loadTopMod();
		#end

		if(allSongs.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new funkin.ui.states.ErrorState("THERE ARE NO SONGS AVAILABLE IN FREEPLAY!\n\nMAKE A WEEK IN the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new funkin.editors.WeekEditorState()),
				function() StateManager.switchState('MainMenuState')));
			return;
		}

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		backdrop = new FlxBackdrop(Paths.image('freeplay/backdrop'));
		backdrop.scale.set(BACKDROP_SCALE, BACKDROP_SCALE);
		backdrop.updateHitbox();
		backdrop.alpha = BACKDROP_ALPHA;
		backdrop.antialiasing = false;
		add(backdrop);

		randomSong = new SongMetadata(Language.getPhrase('freeplay_random', 'Random'), -1, '', RANDOM_COLOR);
		randomSong.isRandom = true;
		randomSong.folder = '';

		rows = new FlxTypedGroup<FreeplaySongRow>();
		add(rows);

		randomSong.row = new FreeplaySongRow(randomSong.songName, '', true);
		rows.add(randomSong.row);
		for (song in allSongs)
		{
			Mods.currentModDirectory = song.folder;
			song.row = new FreeplaySongRow(song.songName, song.songCharacter);
			rows.add(song.row);
		}
		WeekData.setDirectoryFromWeek();

		var _freeplayModMode = getCurrentModMode();
		isMultiModMode = (_freeplayModMode == 'ALL MODS' || _freeplayModMode == 'MODS + FNF SONGS');

		if(isMultiModMode)
		{
			tabList = ['All Songs'];
			if(_freeplayModMode == 'MODS + FNF SONGS')
				tabList.push('Friday Night Funkin\'');
			var modDirs:Array<String> = [];
			for(song in allSongs)
				if(song.folder != '' && !modDirs.contains(song.folder))
					modDirs.push(song.folder);
			modDirs.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : 1);
			for(dir in modDirs)
				tabList.push(dir);
			if(curTab >= tabList.length) curTab = 0;
		}

		var owners:Array<FreeplayPlayer> = [];
		for (song in allSongs)
			for (other in FreeplayPlayer.LIST)
				if(other.ownsSong(song.player) && !owners.contains(other))
					owners.push(other);
		canSwitchPlayer = owners.length > 1;

		player = FreeplayPlayer.get(curPlayerId);
		if(!owners.contains(player) && owners.length > 0) player = owners[0];
		curPlayerId = player.id;

		difficultySelector = new FreeplayDifficulty(player.selectorAsset);
		add(difficultySelector);

		scorePanel = new FreeplayScorePanel(player);
		add(scorePanel);

		card = new FreeplayCard();
		card.onIntroDone = onDJIntroDone;
		add(card);
		card.show(player);

		switchHint = new FlxText(0, HINT_Y, 0, Language.getPhrase('freeplay_switch_character', 'Press [TAB] to Switch Characters'), 24);
		switchHint.setFormat(Paths.font('5by7.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		switchHint.borderSize = 2;
		switchHint.x = Std.int(HINT_X - switchHint.width / 2);
		switchHint.antialiasing = ClientPrefs.data.antialiasing;
		switchHint.visible = canSwitchPlayer;
		add(switchHint);

		if(isMultiModMode)
		{
			tabBG = new FlxSprite(0, 152).makeGraphic(1, 1, FlxColor.BLACK);
			tabBG.origin.set(0, 0);
			tabBG.alpha = 0.6;
			add(tabBG);

			tabText = new FlxText(0, 156, 0, '', 20);
			tabText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT);
			tabText.scrollFactor.set();
			add(tabText);

			tabHint = new FlxText(0, 182, 0, 'Press Q/E to switch MODS', 16);
			tabHint.setFormat(Paths.font('vcr.ttf'), 16, 0xFF808080, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			tabHint.scrollFactor.set();
			add(tabHint);

			updateTabText();
		}

		rankDim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		rankDim.alpha = 0;
		add(rankDim);

		sparks = new FlxSprite();
		sparks.frames = Paths.getSparrowAtlas('freeplay/sparks');
		sparks.animation.addByPrefix('sparks', 'sparks', 24, false);
		sparks.animation.finishCallback = function(_) sparks.visible = sparksAdd.visible = false;
		sparks.blend = BlendMode.ADD;
		sparks.scale.set(0.5, 0.5);
		sparks.updateHitbox();
		sparks.visible = false;
		add(sparks);

		sparksAdd = new FlxSprite();
		sparksAdd.frames = Paths.getSparrowAtlas('freeplay/sparksadd');
		sparksAdd.animation.addByPrefix('sparks add', 'sparks add', 24, false);
		sparksAdd.blend = BlendMode.ADD;
		sparksAdd.scale.set(0.5, 0.5);
		sparksAdd.updateHitbox();
		sparksAdd.visible = false;
		add(sparksAdd);


		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		refreshSongList();
		if(curSelected >= songs.length) curSelected = (songs.length > 1) ? 1 : 0;
		lerpSelected = curSelected;
		prepareResult();

		var firstSong:SongMetadata = songs[curSelected];
		bg.color = firstSong.isRandom ? RANDOM_COLOR : firstSong.color;
		intendedColor = bg.color;

		if(pendingResult != null)
		{
			if(FlxG.sound.music != null && FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		}
		else if (FlxG.sound.music == null || !FlxG.sound.music.playing || FlxG.sound.music.volume <= 0)
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			FlxG.sound.music.volume = 1;
		}
		else
		{
			FlxG.sound.music.pause();
			FlxG.sound.music.resume();
		}

		changeSelection(0, false);
		if(revealRow != null) startReveal();
		updateRows();
		super.create();
		Paths.clearUnusedMemory();

		this.persistentUpdate = true;
	}

	override function closeSubState()
	{
		dimMenuMusic(false);
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	function dimMenuMusic(dim:Bool)
	{
		menuOpen = dim;
		if(musicDimTween != null) musicDimTween.cancel();
		var group = FlxG.sound.defaultMusicGroup;
		musicDimTween = FlxTween.num(group.volume, dim ? MENU_MUSIC_DIM : 1, 0.3, null, function(value:Float) group.volume = value);
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int, ?difficulties:Array<String>)
	{
		var song:SongMetadata = new SongMetadata(songName, weekNum, songCharacter, color);
		song.loadFreeplayData(difficulties != null ? difficulties : Difficulty.defaultList);
		allSongs.push(song);
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	public static function difficultySuffix(name:String):String
	{
		var formatted:String = Paths.formatToSongPath(name);
		if(formatted == Paths.formatToSongPath(Difficulty.getDefault()))
			return '';
		return Paths.variantSuffix(formatted);
	}

	override function update(elapsed:Float)
	{
		if(WeekData.weeksList.length < 1 || songs.length < 1)
			return;

		#if (lime_vorbis && target.threaded)
		var clip:PreviewClip = clipQueue.pop(false);
		while(clip != null)
		{
			receiveClip(clip);
			clip = clipQueue.pop(false);
		}
		#end
		updatePreview();
		backdrop.velocity.set(BACKDROP_SPEED * backdropSpeed, BACKDROP_SPEED * backdropSpeed);

		if(switchHint.visible)
		{
			hintTime += elapsed;
			var wave:Float = 0.5 + 0.5 * Math.cos(hintTime * Math.PI * 2 / HINT_PERIOD);
			switchHint.alpha = HINT_MIN_ALPHA + (1 - HINT_MIN_ALPHA) * wave;
		}

		updateMouse(elapsed);
		if(!busy && !menuOpen) handleInput(elapsed);

		updateRows(elapsed);
		super.update(elapsed);
	}

	function handleInput(elapsed:Float)
	{
		var shiftMult:Int = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

		if(songs.length > 1)
		{
			if(FlxG.keys.justPressed.HOME)
			{
				curSelected = 0;
				changeSelection();
				holdTime = 0;
			}
			else if(FlxG.keys.justPressed.END)
			{
				curSelected = songs.length - 1;
				changeSelection();
				holdTime = 0;
			}
			if (controls.UI_UP_P)
			{
				changeSelection(-shiftMult);
				holdTime = 0;
			}
			if (controls.UI_DOWN_P)
			{
				changeSelection(shiftMult);
				holdTime = 0;
			}

			if(controls.UI_DOWN || controls.UI_UP)
			{
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
			}

			if(FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
				changeSelection(-shiftMult * FlxG.mouse.wheel, false);
			}
		}

		if (controls.UI_LEFT_P)
			changeDiff(-1, true);
		else if (controls.UI_RIGHT_P)
			changeDiff(1, true);
		difficultySelector.setPressed(controls.UI_LEFT, controls.UI_RIGHT);

		if(FlxG.keys.justPressed.TAB && canSwitchPlayer)
			switchPlayer();

		if(isMultiModMode && (FlxG.keys.justPressed.Q || FlxG.keys.justPressed.E))
		{
			curTab = FlxMath.wrap(curTab + (FlxG.keys.justPressed.Q ? -1 : 1), 0, tabList.length - 1);
			updateTab();
		}

		if (controls.BACK)
		{
			var wasPreviewing:Bool = (previewKey != null);
			stopPreview();
			persistentUpdate = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(wasPreviewing) FlxG.sound.playMusic(Paths.music('freakyMenu'));
			StateManager.switchState('MainMenuState');
		}
		else if(FlxG.keys.justPressed.CONTROL)
		{
			dimMenuMusic(true);
			SubStateManager.open(this, 'GameplayChangersSubstate', () -> new GameplayChangersSubstate());
		}
		else if (controls.ACCEPT)
		{
			if(songs[curSelected].isRandom)
				pickRandomSong();
			else
				startSong(songs[curSelected]);
		}
		else if(controls.RESET && !songs[curSelected].isRandom)
		{
			var song:SongMetadata = songs[curSelected];
			var diffName:String = Difficulty.getString(curDifficulty, false);
			dimMenuMusic(true);
			SubStateManager.open(this, 'ResetScoreSubState', () -> new ResetScoreSubState(song.getResetName(diffName), curDifficulty, song.songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
	}

	function updateMouse(elapsed:Float)
	{
		if(FlxG.mouse.justMoved || FlxG.mouse.justPressed)
		{
			FlxG.mouse.visible = true;
			mouseIdleTime = 0;
		}
		else
		{
			mouseIdleTime += elapsed;
			if(mouseIdleTime > MOUSE_HIDE_TIME) FlxG.mouse.visible = false;
		}

		if(!busy && !menuOpen && FlxG.mouse.justPressed && canSwitchPlayer && card.containsMouse())
			switchPlayer();
	}

	function startSong(song:SongMetadata)
	{
		var diffName:String = Difficulty.getString(curDifficulty, false);
		var songLowercase:String = song.getSongFolder(diffName);
		var poop:String = songLowercase + difficultySuffix(diffName);
		Mods.currentModDirectory = song.folder;

		if(Song.findChartPath(poop, songLowercase) == null)
		{
			var difficultyName:String = Difficulty.getString(curDifficulty);
			var chartPath:String = Paths.json('${songLowercase}/${poop}');
			//missingText.text = 'ERROR WHILE LOADING CHART:\n\nSong: ${songs[curSelected].songName}\nDifficulty: $difficultyName\n\nChart file not found!\n\nPath: $chartPath';
			missingText.text = 'SORRY, THIS SONG IS NOT AVAILABLE IN THE DEMO.\n\nThe only playable song is "Concrete Jungle"\nCOMING SOON! THANKS FOR PLAYING :)';
			missingText.screenCenter(Y);
			missingText.visible = true;
			missingTextBG.visible = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		busy = true;
		stopPreview();
		lastPlayedSong = song.songName;
		lastPlayedFolder = songLowercase;
		lastPlayedDifficulty = diffName;
		lastPlayedRank = song.getRank(diffName);
		completedRank = null;
		card.confirm();
		if(ClientPrefs.data.flashing) FlxG.camera.flash(FlxColor.WHITE, FLASH_TIME);
		tweenBackdrop(0, CONFIRM_DELAY, FlxEase.quadOut);
		FlxG.sound.play(Paths.sound('confirmMenu'));
		var difficulty:Int = curDifficulty;
		new FlxTimer().start(CONFIRM_DELAY, function(_) loadSong(poop, songLowercase, difficulty));
	}

	function loadSong(poop:String, songLowercase:String, difficulty:Int)
	{
		persistentUpdate = false;
		Song.loadFromJson(poop, songLowercase);
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = difficulty;

		trace('CURRENT WEEK: ' + WeekData.getWeekFileName());

		@:privateAccess
		if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
		{
			trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
			Paths.freeGraphicsFromMemory();
		}
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
		stopMusicPlay = true;

		destroyFreeplayVocals();
		#if (MODS_ALLOWED && DISCORD_ALLOWED)
		DiscordClient.loadModRPC();
		#end
	}

	function pickRandomSong()
	{
		var diffName:String = Difficulty.getString(curDifficulty, false);
		var pool:Array<SongMetadata> = [for (song in songs) if(!song.isRandom && song.indexOfDifficulty(diffName) > -1) song];
		if(pool.length < 1)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		lastDifficultyName = diffName;
		curSelected = songs.indexOf(FlxG.random.getObject(pool));
		changeSelection(0, false);
		startSong(songs[curSelected]);
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0, fromInput:Bool = false)
	{
		if(songs.length < 1 || Difficulty.list.length < 1)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length - 1);
		var diffName:String = Difficulty.getString(curDifficulty, false);
		if(fromInput) lastDifficultyName = diffName;

		difficultySelector.show(diffName, Difficulty.getString(curDifficulty), change);
		difficultySelector.setArrowsVisible(Difficulty.list.length > 1);

		var song:SongMetadata = songs[curSelected];
		scorePanel.setValues(song.getScore(diffName), song.getClear(diffName));
		for (other in songs)
			if(!other.isRandom)
				other.row.setRank(other.getRank(diffName));

		missingText.visible = false;
		missingTextBG.visible = false;

		if(change != 0) schedulePreview();
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if(songs.length < 1)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		if(card != null) card.resetAfk();

		var song:SongMetadata = songs[curSelected];
		var newColor:Int = song.isRandom ? RANDOM_COLOR : song.color;
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		if(!song.isRandom)
		{
			Mods.currentModDirectory = song.folder;
			PlayState.storyWeek = song.week;
		}

		Difficulty.copyFrom(song.difficulties);
		curDifficulty = song.indexOfDifficulty(lastDifficultyName);
		if(curDifficulty < 0) curDifficulty = song.indexOfDifficulty(Difficulty.getDefault());
		if(curDifficulty < 0) curDifficulty = 0;

		changeDiff();
		schedulePreview();
	}

	function refreshSongList(?keepSong:SongMetadata)
	{
		var tabName:String = currentTabName();
		songs = [randomSong];
		for (song in allSongs)
			if(player.ownsSong(song.player) && songInTab(song, tabName))
				songs.push(song);

		randomSong.difficulties = [];
		for (song in songs)
			if(!song.isRandom)
				for (diff in song.difficulties)
					if(randomSong.indexOfDifficulty(diff) < 0)
						randomSong.difficulties.push(diff);
		if(randomSong.difficulties.length < 1)
			randomSong.difficulties = Difficulty.defaultList.copy();

		var index:Int = (keepSong != null) ? songs.indexOf(keepSong) : -1;
		if(index > -1) curSelected = index;
		if(curSelected >= songs.length) curSelected = songs.length - 1;
		if(curSelected < 0) curSelected = 0;
		lerpSelected = curSelected;
	}

	function currentTabName():String
	{
		return (isMultiModMode && tabList.length > 0) ? tabList[curTab] : null;
	}

	function songInTab(song:SongMetadata, tabName:String):Bool
	{
		if(tabName == null || tabName == 'All Songs')
			return true;
		if(tabName == 'Friday Night Funkin\'')
			return song.folder == '';
		return song.folder == tabName;
	}

	function playerHasSongs(target:FreeplayPlayer):Bool
	{
		var tabName:String = currentTabName();
		for (song in allSongs)
			if(target.ownsSong(song.player) && songInTab(song, tabName))
				return true;
		return false;
	}

	function applyPlayer(target:FreeplayPlayer)
	{
		player = target;
		curPlayerId = player.id;
		difficultySelector.setStyle(player.selectorAsset);
		scorePanel.setStyle(player);
	}

	function switchPlayer()
	{
		var next:FreeplayPlayer = player.next();
		if(!playerHasSongs(next))
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		var current:SongMetadata = songs[curSelected];
		applyPlayer(next);
		card.show(player);
		refreshSongList(findCounterpart(current));
		FlxG.sound.play(Paths.sound('scrollMenu'));
		changeSelection(0, false);
	}

	function findCounterpart(song:SongMetadata):SongMetadata
	{
		if(song == null || song.isRandom)
			return song;

		var base:String = baseSongName(song.songName);
		for (other in allSongs)
			if(player.ownsSong(other.player) && baseSongName(other.songName) == base)
				return other;
		return null;
	}

	static function baseSongName(name:String):String
	{
		return ~/\s*\([^)]*mix\)\s*$/i.replace(name, '').trim().toLowerCase();
	}

	public static function songCompleted(songFolder:String, rank:ResultsRank)
	{
		completedSong = Paths.formatToSongPath(songFolder);
		completedRank = rank;
	}

	function prepareResult()
	{
		var rank:Null<ResultsRank> = completedRank;
		var finishedSong:String = completedSong;
		completedRank = null;
		completedSong = null;
		if(rank == null || lastPlayedSong == null || finishedSong != lastPlayedFolder) return;

		var index:Int = -1;
		for (i in 0...songs.length)
		{
			if(!songs[i].isRandom && songs[i].songName == lastPlayedSong)
			{
				index = i;
				break;
			}
		}
		if(index < 0) return;

		curSelected = index;
		lerpSelected = index;
		lastDifficultyName = lastPlayedDifficulty;
		pendingResult = rank;

		var best:Null<ResultsRank> = songs[index].getRank(lastPlayedDifficulty);
		if(best != null && (lastPlayedRank == null || Type.enumIndex(best) < Type.enumIndex(lastPlayedRank)))
		{
			revealRow = songs[index].row;
			revealOldRank = lastPlayedRank;
			revealNewRank = best;
			busy = true;
		}
	}

	function onDJIntroDone()
	{
		if(pendingResult == null) return;

		var good:Bool = (pendingResult != SHIT);
		if(revealRow == null)
		{
			pendingResult = null;
			card.reaction(good);
			schedulePreview();
			return;
		}

		card.reactionIntro(good);
	}

	function startReveal()
	{
		revealRow.setRank(revealOldRank);
		rows.remove(revealRow, true);
		insert(members.indexOf(rankDim) + 1, revealRow);
		rankDim.alpha = 1;
		revealZoom = 1.25;
		backdropSpeed = 0;

		var good:Bool = (pendingResult != SHIT);
		new FlxTimer().start(REVEAL_DELAY, function(_)
		{
			tweenRevealZoom(1.25, 1.2, 0.6, FlxEase.sineIn);
			new FlxTimer().start(0.5, function(_) showNewRank(good));
		});
	}

	function showNewRank(good:Bool)
	{
		revealRow.revealRank(revealNewRank);

		new FlxTimer().start(0.1, function(_)
		{
			if(revealOldRank != null) playSparks();
			FlxG.sound.play(Paths.sound('ranks/' + switch(revealNewRank)
			{
				case SHIT: 'rankinbad';
				case PERFECT | PERFECT_GOLD: 'rankinperfect';
				default: 'rankinnormal';
			}));
			tweenRevealZoom(1.1, 1.3, 0.3, FlxEase.backInOut);
			revealRow.shake(6, 0.3);
		});

		new FlxTimer().start(0.4, function(_) tweenRevealZoom(revealZoom, 1, 0.8, FlxEase.backIn));
		new FlxTimer().start(0.6, function(_) rankSlam(good));
	}

	function rankSlam(good:Bool)
	{
		FlxTween.tween(rankDim, {alpha: 0}, 0.5, {ease: FlxEase.expoIn});
		FlxG.sound.play(Paths.sound('ranks/' + switch(revealNewRank)
		{
			case SHIT: 'loss';
			case GOOD: 'good';
			case GREAT: 'great';
			case EXCELLENT: 'excellent';
			case PERFECT | PERFECT_GOLD: 'perfect';
		}));

		new FlxTimer().start(0.5, function(_)
		{
			FlxG.camera.shake(0.0045, 0.35);
			card.reaction(good);
			tweenRevealZoom(0.9, 1, 1, FlxEase.elasticOut);

			if(ClientPrefs.data.flashing) FlxG.camera.flash(rankColor(revealNewRank), FLASH_TIME);
			tweenBackdrop(1, BACKDROP_RESUME_TIME, FlxEase.quadIn);

			for (row in visibleRows)
			{
				var distance:Float = Math.abs(songs.indexOf(getRowSong(row)) - curSelected);
				row.shake((row == revealRow) ? 12 : 12 / (distance + 1), 0.6);
			}
			if(!visibleRows.contains(revealRow)) revealRow.shake(12, 0.6);

			new FlxTimer().start(0.6, function(_) finishReveal());
		});
	}

	function finishReveal()
	{
		if(revealZoomTween != null) revealZoomTween.cancel();
		revealZoom = 1;
		remove(revealRow, true);
		rows.add(revealRow);
		revealRow = null;
		revealOldRank = revealNewRank = null;
		pendingResult = null;
		busy = false;
		schedulePreview();
	}

	function getRowSong(row:FreeplaySongRow):SongMetadata
	{
		for (song in songs)
			if(song.row == row)
				return song;
		return null;
	}

	function tweenBackdrop(to:Float, duration:Float, ease:EaseFunction)
	{
		if(backdropTween != null) backdropTween.cancel();
		backdropTween = FlxTween.num(backdropSpeed, to, duration, {ease: ease}, function(value:Float) backdropSpeed = value);
	}

	function tweenRevealZoom(from:Float, to:Float, duration:Float, ease:EaseFunction)
	{
		if(revealZoomTween != null) revealZoomTween.cancel();
		revealZoom = from;
		revealZoomTween = FlxTween.num(from, to, duration, {ease: ease}, function(value:Float) revealZoom = value);
	}

	function playSparks()
	{
		var badge:FlxSprite = revealRow.rankBadge;
		var centerX:Float = badge.x + badge.frameWidth / 2;
		var centerY:Float = badge.y + badge.frameHeight / 2;

		sparksAdd.color = rankColor(revealOldRank);

		for (spark in [sparks, sparksAdd])
		{
			spark.setPosition(centerX - spark.width / 2, centerY - spark.height / 2);
			spark.visible = true;
		}
		sparks.animation.play('sparks', true);
		sparksAdd.animation.play('sparks add', true);
	}

	static function rankColor(rank:Null<ResultsRank>):FlxColor
	{
		return switch(rank)
		{
			case SHIT: 0xFF6044FF;
			case GOOD: 0xFFEF8764;
			case GREAT: 0xFFEAF6FF;
			case EXCELLENT: 0xFFFDCB42;
			case PERFECT: 0xFFFF58B4;
			case PERFECT_GOLD | null: 0xFFFFB619;
		}
	}

	function schedulePreview()
	{
		if(previewTimer != null) previewTimer.cancel();
		previewTimer = new FlxTimer().start(PREVIEW_DELAY, function(_) startPreview());
	}

	function startPreview()
	{
		if(songs.length < 1 || pendingResult != null) return;

		var song:SongMetadata = songs[curSelected];
		var diffName:String = Difficulty.getString(curDifficulty, false);
		var folder:String = null;
		var suffix:String = null;
		var key:String = 'freeplayRandom';
		if(!song.isRandom)
		{
			folder = song.getSongFolder(diffName);
			suffix = difficultySuffix(diffName);
			key = Paths.instPath(folder, suffix);
			if(key == null) return;
		}
		if(key == pendingClipKey) return;
		if(key == previewKey && FlxG.sound.music != null && FlxG.sound.music.playing) return;

		previewRequest++;
		pendingClipKey = null;

		if(song.isRandom)
		{
			var randomSound:Sound = null;
			try { randomSound = Paths.music('freeplayRandom'); } catch(e:Dynamic) {}
			playPreview(key, randomSound, true, 0, -1);
			return;
		}

		var start:Float = Math.max(0, song.previewStart);
		var length:Float = PREVIEW_LENGTH;
		if(song.previewEnd > song.previewStart) length = Math.min(length, song.previewEnd - song.previewStart);

		#if lime_vorbis
		if(key.toLowerCase().endsWith('.ogg'))
		{
			requestClip(key, start, length);
			return;
		}
		#end

		var sound:Sound = null;
		try { sound = Paths.inst(folder, suffix); } catch(e:Dynamic) {}
		playPreview(key, sound, true, start * 1000, length * 1000);
	}

	function playPreview(key:String, sound:Sound, cached:Bool, startTime:Float, length:Float)
	{
		if(sound == null || sound == FlxAssets.getSound('flixel/sounds/beep')) return;

		if(FlxG.sound.music != null && FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();
		FlxG.sound.playMusic(sound, 0);
		if(previewSound != null && previewSound != sound && previewCached) forgetSound(previewSound);
		previewSound = sound;
		previewCached = cached;
		previewKey = key;
		previewFading = false;

		previewStartTime = (startTime < FlxG.sound.music.length) ? startTime : 0;
		previewEndTime = (length > 0) ? Math.min(previewStartTime + length, FlxG.sound.music.length) : -1;
		if(previewStartTime > 0) FlxG.sound.music.time = previewStartTime;
		FlxG.sound.music.fadeIn(PREVIEW_FADE, 0, PREVIEW_VOLUME);
	}

	#if lime_vorbis
	function requestClip(path:String, start:Float, length:Float)
	{
		var request:Int = previewRequest;
		pendingClipKey = path;
		#if target.threaded
		var queue:Deque<PreviewClip> = clipQueue;
		Thread.create(function() queue.add({request: request, key: path, buffer: decodeClip(path, start, length)}));
		#else
		receiveClip({request: request, key: path, buffer: decodeClip(path, start, length)});
		#end
	}

	function receiveClip(clip:PreviewClip)
	{
		if(clip.request != previewRequest) return;
		pendingClipKey = null;
		if(clip.buffer == null || pendingResult != null) return;

		var buffer:AudioBuffer = clip.buffer;
		var clipLength:Float = buffer.data.length / (buffer.channels * 2) / buffer.sampleRate * 1000;
		playPreview(clip.key, Sound.fromAudioBuffer(buffer), false, 0, clipLength);
	}

	static function decodeClip(path:String, start:Float, length:Float):AudioBuffer
	{
		var vorbis:VorbisFile = null;
		try
		{
			vorbis = VorbisFile.fromFile(path);
			if(vorbis == null) return null;

			var info = vorbis.info();
			var total:Float = vorbis.timeTotal();
			if(start >= total) start = 0;
			if(start > 0) vorbis.timeSeek(start);

			var frameSize:Int = info.channels * 2;
			var size:Int = Std.int(Math.min(length, total - start) * info.rate) * frameSize;
			var data:Bytes = Bytes.alloc(size);
			var position:Int = 0;
			var holes:Int = 0;
			while(position < size)
			{
				var read:Int = vorbis.read(data, position, Std.int(Math.min(4096, size - position)));
				if(read > 0) position += read;
				else if(read == VORBIS_HOLE && ++holes < MAX_VORBIS_HOLES) continue;
				else break;
			}
			vorbis.clear();
			vorbis = null;

			position -= position % frameSize;
			if(position <= 0) return null;

			var buffer:AudioBuffer = new AudioBuffer();
			buffer.channels = info.channels;
			buffer.sampleRate = info.rate;
			buffer.bitsPerSample = 16;
			buffer.data = UInt8Array.fromBytes(data, 0, position);
			return buffer;
		}
		catch(e:Dynamic)
		{
			if(vorbis != null) vorbis.clear();
			return null;
		}
	}
	#end

	function updatePreview()
	{
		var music:FlxSound = FlxG.sound.music;
		if(previewKey == null || previewEndTime < 0 || previewFading || music == null || !music.playing)
			return;

		if(music.time >= previewEndTime - PREVIEW_FADE * 1000)
		{
			previewFading = true;
			var key:String = previewKey;
			music.fadeOut(PREVIEW_FADE, 0, function(_)
			{
				if(key != previewKey || FlxG.sound.music == null) return;
				FlxG.sound.music.time = previewStartTime;
				FlxG.sound.music.fadeIn(PREVIEW_FADE, 0, PREVIEW_VOLUME);
				previewFading = false;
			});
		}
	}

	function stopPreview()
	{
		if(previewTimer != null) previewTimer.cancel();
		if(FlxG.sound.music != null && FlxG.sound.music.fadeTween != null) FlxG.sound.music.fadeTween.cancel();
		previewKey = null;
		pendingClipKey = null;
		previewRequest++;
		previewFading = false;
	}

	function forgetSound(sound:Sound)
	{
		for (key => cached in Paths.currentTrackedSounds)
		{
			if(cached != sound) continue;
			Paths.currentTrackedSounds.remove(key);
			while(Paths.localTrackedAssets.remove(key)) {}
			break;
		}
	}

	function updateRows(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));

		for (row in visibleRows)
			row.visible = row.active = false;
		visibleRows = [];

		var min:Int = Std.int(Math.max(0, Math.floor(lerpSelected - DRAW_DISTANCE)));
		var max:Int = Std.int(Math.min(songs.length, Math.ceil(lerpSelected + DRAW_DISTANCE) + 1));
		for (i in min...max)
		{
			var row:FreeplaySongRow = songs[i].row;
			var distance:Float = i - lerpSelected;
			var near:Float = Math.min(Math.abs(distance), 1);
			var far:Float = Math.max(Math.abs(distance) - 1, 0);

			var rowX:Float = ROW_X + near * ROW_INDENT + far * ROW_INDENT_FAR;
			var rowY:Float = ROW_Y + FlxMath.signOf(distance) * (near * ROW_SPACING + far * ROW_SPACING_FAR);
			row.visible = row.active = true;
			var rowScale:Float = FlxMath.lerp(1, ROW_SCALE_FAR, near);
			if(row == revealRow) rowScale *= revealZoom;
			row.layout(rowX, rowY, rowScale, FlxMath.lerp(1, ROW_ALPHA_FAR, near));
			visibleRows.push(row);
		}
	}

	function updateTab()
	{
		updateTabText();
		refreshSongList();
		if(songs.length < 2)
		{
			for (other in FreeplayPlayer.LIST)
			{
				if(other != player && playerHasSongs(other))
				{
					applyPlayer(other);
					card.show(player);
					refreshSongList();
					break;
				}
			}
		}
		curSelected = (songs.length > 1) ? 1 : 0;
		lerpSelected = curSelected;
		changeSelection(0, false);
	}

	function updateTabText()
	{
		tabText.text = '[ ' + tabList[curTab] + ' ]';
		var width:Float = Math.max(tabText.width, tabHint.width) + 12;
		tabBG.scale.set(width, 54);
		tabBG.x = FlxG.width - width;
		var center:Float = tabBG.x + width / 2;
		tabText.x = Std.int(center - tabText.width / 2);
		tabHint.x = Std.int(center - tabHint.width / 2);
	}

	override function destroy():Void
	{
		#if MODS_ALLOWED
		var _destroyMode = getCurrentModMode();
		if(_destroyMode != 'ALL MODS' && _destroyMode != 'MODS + FNF SONGS')
			Mods.pushGlobalMods();
		else
			Mods.clearGlobalMods();
		#end
		stopPreview();
		if(musicDimTween != null) musicDimTween.cancel();
		FlxG.sound.defaultMusicGroup.volume = 1;

		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		FlxG.mouse.visible = false;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			FlxG.sound.music.volume = 1;
		}
	}
}

#if lime_vorbis
typedef PreviewClip =
{
	request:Int,
	key:String,
	buffer:AudioBuffer
}
#end

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var isRandom:Bool = false;
	public var player:String = "";
	public var previewStart:Float = 0;
	public var previewEnd:Float = 0;
	public var difficulties:Array<String> = [];
	public var row:FreeplaySongRow;

	var erectFolders:Map<String, String> = [];

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}

	public function loadFreeplayData(weekDifficulties:Array<String>)
	{
		var formatted:String = Paths.formatToSongPath(songName);
		var meta = MetaData.getFreeplayMeta(formatted);
		player = meta.character;
		previewStart = meta.previewStart;
		previewEnd = meta.previewEnd;

		difficulties = weekDifficulties.copy();
		var erectFolder:String = formatted + '-erect';
		for (diff in FreeplayState.ERECT_DIFFICULTIES)
		{
			var suffix:String = FreeplayState.difficultySuffix(diff);
			var index:Int = indexOfDifficulty(diff);
			if(index > -1 && Song.findChartPath(formatted + suffix, formatted) != null) continue;
			if(Song.findChartPath(erectFolder + suffix, erectFolder) == null) continue;

			if(index < 0) difficulties.push(diff);
			erectFolders.set(Paths.formatToSongPath(diff), erectFolder);
		}
	}

	public function indexOfDifficulty(name:String):Int
	{
		if(name == null) return -1;

		var key:String = Paths.formatToSongPath(name);
		for (i in 0...difficulties.length)
			if(Paths.formatToSongPath(difficulties[i]) == key)
				return i;
		return -1;
	}

	public function getSongFolder(diff:String):String
	{
		var erectFolder:String = erectFolders.get(Paths.formatToSongPath(diff));
		return (erectFolder != null) ? erectFolder : Paths.formatToSongPath(songName);
	}

	public function getResetName(diff:String):String
	{
		return erectFolders.exists(Paths.formatToSongPath(diff)) ? songName + ' Erect' : songName;
	}

	function getSaveKey(diff:String):String
	{
		return getSongFolder(diff) + FreeplayState.difficultySuffix(diff);
	}

	public function getScore(diff:String):Int
	{
		var key:String = getSaveKey(diff);
		return Highscore.songScores.exists(key) ? Highscore.songScores.get(key) : 0;
	}

	public function getRating(diff:String):Float
	{
		var key:String = getSaveKey(diff);
		return Highscore.songRating.exists(key) ? Highscore.songRating.get(key) : 0;
	}

	public function getClear(diff:String):Int
	{
		return Math.floor(getRating(diff) * 100);
	}

	public function getRank(diff:String):Null<ResultsRank>
	{
		if(isRandom || indexOfDifficulty(diff) < 0) return null;

		var rating:Float = getRating(diff);
		if(getScore(diff) <= 0 && rating <= 0) return null;

		var key:String = getSaveKey(diff);
		var misses:Int = Highscore.songMisses.exists(key) ? Highscore.songMisses.get(key) : ((rating >= 1) ? 0 : 1);
		return RankData.calculate(rating, misses, (rating >= 1) ? 1 : 0, 1);
	}
}
