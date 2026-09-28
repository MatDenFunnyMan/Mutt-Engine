package funkin.backend;

import flixel.FlxState;

class MouseVisibility
{
	public static final ALLOWED_STATES:Array<String> = ['MainMenuState', 'NotesColorSubState'];
	public static final ALLOWED_PACKAGES:Array<String> = ['funkin.editors.'];

	public static var scriptAllowed:Bool = false;

	static var initialized:Bool = false;
	static var wasHidden:Bool = false;
	static var suppressed:Bool = false;

	public static function init()
	{
		if(initialized) return;
		initialized = true;
		FlxG.signals.preStateSwitch.add(() -> scriptAllowed = suppressed = false);
		FlxG.signals.preUpdate.add(sync);
		FlxG.signals.postUpdate.add(sync);
	}

	public static function setScriptVisible(visible:Bool)
	{
		scriptAllowed = visible;
		FlxG.mouse.visible = visible;
	}

	public static function isHidden():Bool
	{
		if(!ClientPrefs.data.hideMouse || scriptAllowed) return false;
		#if FLX_DEBUG
		if(FlxG.debugger.visible) return false;
		#end

		var state:FlxState = FlxG.state;
		while(state != null)
		{
			if(isAllowed(state)) return false;
			state = state.subState;
		}
		return true;
	}

	static function isAllowed(state:FlxState):Bool
	{
		var path:String = Type.getClassName(Type.getClass(state));
		for (pack in ALLOWED_PACKAGES)
			if(path.startsWith(pack)) return true;

		if(ALLOWED_STATES.contains(path.substr(path.lastIndexOf('.') + 1))) return true;

		var scripted:Dynamic = Reflect.field(state, 'stateName');
		return scripted is String && ALLOWED_STATES.contains(scripted);
	}

	static function sync()
	{
		var hidden:Bool = isHidden();
		if(hidden != wasHidden)
		{
			wasHidden = hidden;
			FlxG.mouse.reset();
			FlxG.mouse.enabled = !hidden;
			if(!hidden && suppressed) FlxG.mouse.visible = true;
			suppressed = false;
		}
		if(hidden && FlxG.mouse.visible)
		{
			FlxG.mouse.visible = false;
			suppressed = true;
		}
	}
}
