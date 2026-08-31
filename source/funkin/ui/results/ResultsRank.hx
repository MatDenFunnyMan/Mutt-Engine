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
	var ?x:Float;
	var ?y:Float;
	var ?scale:Float;
	var ?delay:Float;
	var ?loopFrame:Int;
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

	public static function musicPath(rank:ResultsRank, character:String):String
	{
		var base:String = switch(rank)
		{
			case PERFECT_GOLD, PERFECT: 'resultsPERFECT';
			case EXCELLENT: 'resultsEXCELLENT';
			case GREAT, GOOD: 'resultsNORMAL';
			case SHIT: 'resultsSHIT';
		}

		return character == 'bf' ? base : '$base-$character';
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
		return character == 'pico' ? picoLayers(rank) : bfLayers(rank);
	}

	static function bfLayers(rank:ResultsRank):Array<ResultsLayer>
	{
		var root:String = 'results/results-bf';

		return switch(rank)
		{
			case PERFECT_GOLD, PERFECT: [
				{asset: '$root/resultsPERFECT/bed', x: 1342, y: 370, loopFrame: 0},
				{asset: '$root/resultsPERFECT/hearts', x: 1342, y: 370, delay: 4.41, loopFrame: 43}
			];
			case EXCELLENT: [
				{asset: '$root/resultsEXCELLENT', x: 1329, y: 429, loopFrame: 29}
			];
			case GREAT: [
				{asset: '$root/resultsGREAT/gf', x: 802, y: 331, scale: 0.93, delay: 0.25, loopFrame: 9},
				{asset: '$root/resultsGREAT/bf', x: 929, y: 363, scale: 0.93, loopFrame: 15}
			];
			case GOOD: [
				{asset: '$root/resultsGOOD/resultGirlfriendGOOD', sparrow: true, x: 629, y: 323, delay: 0.91, loopFrame: 9},
				{asset: '$root/resultsGOOD/bf', x: 662, y: 371, loopFrame: 14}
			];
			case SHIT: [
				{asset: '$root/resultsSHIT', x: 0, y: 20, loopFrame: 0}
			];
		}
	}

	static function picoLayers(rank:ResultsRank):Array<ResultsLayer>
	{
		var root:String = 'results/results-pico';

		return switch(rank)
		{
			case PERFECT_GOLD, PERFECT: [
				{asset: '$root/resultsPERFECT', x: 385, y: 82, scale: 0.88, loopFrame: 91}
			];
			case EXCELLENT, GREAT: [
				{asset: '$root/resultsGREAT', x: 350, y: 25, scale: 1.25, loopFrame: 32}
			];
			case GOOD: [
				{asset: '$root/resultsGOOD', x: 350, y: 25, scale: 1.25, loopFrame: 41}
			];
			case SHIT: [
				{asset: '$root/resultsSHIT', x: -185, y: -125, loopFrame: 0}
			];
		}
	}

	public static function resolveCharacter(playerName:String):String
	{
		if(playerName == null) return 'bf';

		if(playerName.toLowerCase().indexOf('pico') > -1
			&& Paths.fileExists('images/results/results-pico/resultsGOOD/Animation.json', TEXT))
			return 'pico';

		return 'bf';
	}
}
