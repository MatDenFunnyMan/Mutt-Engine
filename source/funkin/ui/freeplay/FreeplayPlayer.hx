package funkin.ui.freeplay;

typedef FreeplayDJAnim =
{
	var symbol:String;
	var offsetX:Float;
	var offsetY:Float;
}

class FreeplayPlayer
{
	public static final LIST:Array<FreeplayPlayer> = [
		new FreeplayPlayer('bf', 'freeplay/freeplaySelector/freeplaySelector', 'freeplay/digital_numbers', 'freeplay/freeplay-boyfriend', [
			'intro' => {symbol: 'boyfriend dj intro', offsetX: 631.7, offsetY: 362.6},
			'idle' => {symbol: 'Boyfriend DJ', offsetX: 625, offsetY: 360},
			'afk' => {symbol: 'bf dj afk', offsetX: 1274.5, offsetY: 418.5},
			'confirm' => {symbol: 'Boyfriend DJ confirm', offsetX: 625, offsetY: 360},
			'fistPump' => {symbol: 'Boyfriend DJ fist pump', offsetX: 625, offsetY: 360},
			'loss' => {symbol: 'Boyfriend DJ loss reaction 1', offsetX: 625, offsetY: 360}
		], [0, 4, 4], [0, 4, 4]),
		new FreeplayPlayer('pico', 'freeplay/freeplaySelector/freeplaySelector_pico', 'freeplay/digital_numbers_pico', 'freeplay/freeplay-pico', [
			'intro' => {symbol: 'pico dj intro', offsetX: 631.7, offsetY: 362.6},
			'idle' => {symbol: 'Pico DJ', offsetX: 625, offsetY: 360},
			'afk' => {symbol: 'Pico DJ afk', offsetX: 625, offsetY: 360},
			'confirm' => {symbol: 'Pico DJ confirm', offsetX: 625, offsetY: 360},
			'fistPump' => {symbol: 'pico cheer', offsetX: 975, offsetY: 260},
			'loss' => {symbol: 'Pico DJ loss', offsetX: 625, offsetY: 360}
		], [0, 4, 4], [0, 0, 0])
	];

	public var id(default, null):String;
	public var selectorAsset(default, null):String;
	public var numbersAsset(default, null):String;
	public var djAtlas(default, null):String;
	public var djAnimations(default, null):Map<String, FreeplayDJAnim>;
	public var fistPumpFrames(default, null):Array<Int>;
	public var lossFrames(default, null):Array<Int>;

	public function new(id:String, selectorAsset:String, numbersAsset:String, djAtlas:String, djAnimations:Map<String, FreeplayDJAnim>, fistPumpFrames:Array<Int>, lossFrames:Array<Int>)
	{
		this.id = id;
		this.selectorAsset = selectorAsset;
		this.numbersAsset = numbersAsset;
		this.djAtlas = djAtlas;
		this.djAnimations = djAnimations;
		this.fistPumpFrames = fistPumpFrames;
		this.lossFrames = lossFrames;
	}

	public static function get(id:String):FreeplayPlayer
	{
		for (player in LIST)
			if (player.id == id)
				return player;
		return LIST[0];
	}

	public function next():FreeplayPlayer
	{
		return LIST[(LIST.indexOf(this) + 1) % LIST.length];
	}

	public function ownsSong(tag:String):Bool
	{
		tag = (tag == null) ? '' : tag.trim().toLowerCase();
		var owner:FreeplayPlayer = LIST[0];
		for (player in LIST)
			if (player.id == tag)
				owner = player;
		return owner == this;
	}
}
