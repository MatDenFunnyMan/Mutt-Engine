package funkin.ui.results;

enum ResultsRank
{
	PERFECT_GOLD;
	PERFECT;
	EXCELLENT;
	GREAT;
	GOOD;
	SHIT;
}

typedef ResultsLayer = {
	var asset:String;
	var ?sparrow:Bool;
	var ?offsetX:Float;
	var ?offsetY:Float;
	var ?loop:Bool;
	var ?startDelay:Float;
}

class RankData
{
	public static var PERFECT_THRESHOLD:Float = 1;
	public static var EXCELLENT_THRESHOLD:Float = 0.9;
	public static var GREAT_THRESHOLD:Float = 0.8;
	public static var GOOD_THRESHOLD:Float = 0.6;

	public static function calculate(percent:Float, misses:Int, sicks:Int, totalHits:Int):ResultsRank
	{
		if(misses < 1 && totalHits > 0 && sicks >= totalHits) return PERFECT_GOLD;
		if(misses < 1 && percent >= PERFECT_THRESHOLD) return PERFECT;
		if(percent >= EXCELLENT_THRESHOLD) return EXCELLENT;
		if(percent >= GREAT_THRESHOLD) return GREAT;
		if(percent >= GOOD_THRESHOLD) return GOOD;
		return SHIT;
	}

	public static function suffix(rank:ResultsRank):String
	{
		return switch(rank)
		{
			case PERFECT_GOLD, PERFECT: 'PERFECT';
			case EXCELLENT: 'EXCELLENT';
			case GREAT: 'GREAT';
			case GOOD: 'GOOD';
			case SHIT: 'LOSS';
		}
	}

	public static function folder(rank:ResultsRank):String
	{
		return switch(rank)
		{
			case PERFECT_GOLD, PERFECT: 'resultsPERFECT';
			case EXCELLENT: 'resultsEXCELLENT';
			case GREAT: 'resultsGREAT';
			case GOOD: 'resultsGOOD';
			case SHIT: 'resultsSHIT';
		}
	}

	public static function musicPath(rank:ResultsRank):String
	{
		return switch(rank)
		{
			case PERFECT_GOLD, PERFECT: 'resultsPERFECT';
			case EXCELLENT: 'resultsEXCELLENT';
			case GREAT, GOOD: 'resultsNORMAL';
			case SHIT: 'resultsSHIT';
		}
	}

	public static function color(rank:ResultsRank):FlxColor
	{
		return switch(rank)
		{
			case PERFECT_GOLD: 0xFFFFB619;
			case PERFECT: 0xFFFF58B4;
			case EXCELLENT: 0xFFFDCB42;
			case GREAT: 0xFFEAF6FF;
			case GOOD: 0xFFEF8764;
			case SHIT: 0xFF6044FF;
		}
	}

	public static function musicDelay(rank:ResultsRank):Float
	{
		return switch(rank)
		{
			case PERFECT_GOLD, PERFECT: 95 / 24;
			case EXCELLENT: 0;
			case GREAT: 5 / 24;
			case GOOD: 3 / 24;
			case SHIT: 2 / 24;
		}
	}

	public static function characterDelay(rank:ResultsRank):Float
	{
		return switch(rank)
		{
			case EXCELLENT: 97 / 24;
			default: 95 / 24;
		}
	}

	public static function flashDelay(rank:ResultsRank):Float
	{
		return switch(rank)
		{
			case PERFECT_GOLD, PERFECT: 129 / 24;
			case EXCELLENT: 122 / 24;
			case GREAT: 109 / 24;
			case GOOD: 107 / 24;
			case SHIT: 186 / 24;
		}
	}

	public static function highscoreDelay(rank:ResultsRank):Float
	{
		return switch(rank)
		{
			case PERFECT_GOLD, PERFECT, EXCELLENT: 140 / 24;
			case GREAT: 129 / 24;
			case GOOD: 127 / 24;
			case SHIT: 207 / 24;
		}
	}

	public static function layers(rank:ResultsRank, character:String):Array<ResultsLayer>
	{
		var root:String = 'results/results-$character/' + folder(rank);

		if(character != 'bf')
		{
			return [{asset: root, loop: true}];
		}

		return switch(rank)
		{
			case PERFECT_GOLD, PERFECT: [
				{asset: '$root/bed', loop: true},
				{asset: '$root/tickleFight', loop: true},
				{asset: '$root/hearts', loop: true}
			];
			case GREAT: [
				{asset: '$root/gf', loop: true},
				{asset: '$root/bf', loop: true}
			];
			case GOOD: [
				{asset: '$root/resultGirlfriendGOOD', sparrow: true, loop: true},
				{asset: '$root/bf', loop: true}
			];
			default: [{asset: root, loop: true}];
		}
	}

	public static function resolveCharacter(playerName:String):String
	{
		if(playerName == null) return 'bf';

		var lower:String = playerName.toLowerCase();
		if(lower.indexOf('pico') > -1 && Paths.fileExists('images/results/results-pico/Animation.json', TEXT) == false)
		{
			if(Paths.fileExists('images/results/results-pico/resultsGOOD/Animation.json', TEXT)) return 'pico';
		}
		return 'bf';
	}
}
