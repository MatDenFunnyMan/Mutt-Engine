package funkin.game;

class InputSystem
{
	public static inline final PSYCH:String = 'Psych';
	public static inline final VSLICE:String = 'V-Slice';
	public static inline final LEGACY:String = 'Legacy';
	public static final LIST:Array<String> = [PSYCH, VSLICE, LEGACY];

	public static inline final MAX_SAFE_FRAMES:Float = 10;
	public static inline final VSLICE_SAFE_FRAMES:Float = 8;
	public static inline final LEGACY_MAX_SAFE_FRAMES:Float = 6;

	public static inline final VSLICE_HIT_WINDOW:Float = 160;
	public static final VSLICE_JUDGEMENTS:Array<Float> = [45, 90, 135];
	public static final VSLICE_RATING_MODS:Array<Float> = [1, 1, 0, 0];

	public static inline final VSLICE_MAX_SCORE:Int = 500;
	public static inline final VSLICE_MIN_SCORE:Float = 9;
	public static inline final VSLICE_PERFECT_THRESHOLD:Float = 5;
	public static inline final VSLICE_SCORING_OFFSET:Float = 54.99;
	public static inline final VSLICE_SCORING_SLOPE:Float = 0.080;
	public static inline final VSLICE_MISS_SCORE:Int = -100;
	public static inline final VSLICE_GHOST_MISS_SCORE:Int = -10;
	public static inline final VSLICE_HOLD_SCORE_PER_SECOND:Float = 250;
	public static inline final VSLICE_HOLD_DROP_SCORE_PER_SECOND:Float = -125;
	public static inline final VSLICE_HOLD_DROP_THRESHOLD:Float = 160;

	public static inline final VSLICE_HEALTH_SICK:Float = 0.03;
	public static inline final VSLICE_HEALTH_GOOD:Float = 0.015;
	public static inline final VSLICE_HEALTH_BAD:Float = 0;
	public static inline final VSLICE_HEALTH_SHIT:Float = -0.02;
	public static inline final VSLICE_HEALTH_MISS:Float = 0.08;
	public static inline final VSLICE_HEALTH_GHOST_MISS:Float = 0.08;
	public static inline final VSLICE_HEALTH_HOLD_PER_SECOND:Float = 0.12;

	public static inline final DEFAULT_HIT_HEALTH:Float = 0.02;
	public static inline final DEFAULT_MISS_HEALTH:Float = 0.1;
	public static inline final DEFAULT_PRESS_MISS_DAMAGE:Float = 0.05;

	public static var current(get, never):String;
	static function get_current():String
	{
		var mode:String = ClientPrefs.data.inputSystem;
		return LIST.contains(mode) ? mode : PSYCH;
	}

	public static inline function isVSlice():Bool
		return current == VSLICE;

	public static function ghostTapping():Bool
		return current != VSLICE && ClientPrefs.data.ghostTapping;

	public static function ghostTappingLocked():Bool
		return current == VSLICE;

	public static function sustainsAsOneNote():Bool
		return current != LEGACY;

	public static function safeFrames():Float
	{
		return switch(current)
		{
			case VSLICE: VSLICE_SAFE_FRAMES;
			case LEGACY: Math.min(ClientPrefs.data.safeFrames, LEGACY_MAX_SAFE_FRAMES);
			default: ClientPrefs.data.safeFrames;
		}
	}

	public static function maxSafeFrames():Float
		return current == LEGACY ? LEGACY_MAX_SAFE_FRAMES : MAX_SAFE_FRAMES;

	public static function safeFramesLocked():Bool
		return current == VSLICE;

	public static function hitWindowMs():Float
		return safeFrames() / 60 * 1000;

	public static function applyRatings(ratings:Array<Rating>)
	{
		if(!isVSlice()) return;

		var scale:Float = hitWindowMs() / VSLICE_HIT_WINDOW;
		for (i => rating in ratings)
		{
			if(i < VSLICE_JUDGEMENTS.length) rating.hitWindow = VSLICE_JUDGEMENTS[i] * scale;
			if(i < VSLICE_RATING_MODS.length) rating.ratingMod = VSLICE_RATING_MODS[i];
		}
	}

	public static function vsliceScore(diff:Float):Int
	{
		var absTiming:Float = Math.abs(diff);
		if(absTiming < VSLICE_PERFECT_THRESHOLD) return VSLICE_MAX_SCORE;

		var factor:Float = 1.0 - (1.0 / (1.0 + Math.exp(-VSLICE_SCORING_SLOPE * (absTiming - VSLICE_SCORING_OFFSET))));
		return Std.int(VSLICE_MAX_SCORE * factor + VSLICE_MIN_SCORE);
	}

	public static function vsliceHitHealth(rating:String):Float
	{
		return switch(rating)
		{
			case 'sick': VSLICE_HEALTH_SICK;
			case 'good': VSLICE_HEALTH_GOOD;
			case 'bad': VSLICE_HEALTH_BAD;
			case 'shit': VSLICE_HEALTH_SHIT;
			default: 0;
		}
	}

	public static function vsliceComboBreak(rating:String):Bool
		return rating == 'bad' || rating == 'shit';
}
