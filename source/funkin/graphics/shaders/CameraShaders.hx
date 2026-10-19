package funkin.graphics.shaders;

import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;

class CameraShaderEntry
{
	public var name:String;
	public var shader:FlxRuntimeShader;
	public var filter:ShaderFilter;

	public function new(name:String, shader:FlxRuntimeShader)
	{
		this.name = name;
		this.shader = shader;
		filter = new ShaderFilter(cast shader);
	}
}

class CameraShaders
{
	static var stacks:Map<FlxCamera, Array<CameraShaderEntry>> = [];
	static var listening:Bool = false;

	public static function add(camera:FlxCamera, name:String, shader:FlxRuntimeShader):String
	{
		if(camera == null || shader == null) return null;
		listen();
		var old:Array<CameraShaderEntry> = entries(camera);
		var list:Array<CameraShaderEntry> = old.copy();
		if(name == null || name.length < 1) name = 'shader';
		var replaced:Bool = false;
		for (i in 0...list.length)
		{
			if(list[i].name != name) continue;
			list[i] = new CameraShaderEntry(name, shader);
			replaced = true;
			break;
		}
		if(!replaced) list.push(new CameraShaderEntry(name, shader));
		apply(camera, old, list);
		return name;
	}

	public static function remove(camera:FlxCamera, ?name:String):Bool
	{
		if(camera == null) return false;
		var old:Array<CameraShaderEntry> = entries(camera);
		var list:Array<CameraShaderEntry> = (name == null) ? [] : [for (entry in old) if(entry.name != name) entry];
		if(list.length == old.length) return false;
		apply(camera, old, list);
		return true;
	}

	public static function reset(camera:FlxCamera)
	{
		if(camera == null) return;
		stacks.remove(camera);
		camera.setFilters([]);
	}

	public static function get(camera:FlxCamera, ?name:String):FlxRuntimeShader
	{
		for (entry in entries(camera))
			if(name == null || entry.name == name) return entry.shader;
		return null;
	}

	public static function names(camera:FlxCamera):Array<String>
		return [for (entry in entries(camera)) entry.name];

	static function entries(camera:FlxCamera):Array<CameraShaderEntry>
	{
		var list:Array<CameraShaderEntry> = (camera != null) ? stacks.get(camera) : null;
		return (list != null) ? list : [];
	}

	static function apply(camera:FlxCamera, old:Array<CameraShaderEntry>, list:Array<CameraShaderEntry>)
	{
		var current:Array<BitmapFilter> = (camera.filters != null) ? camera.filters : [];
		var others:Array<BitmapFilter> = [];
		for (filter in current)
		{
			var managed:Bool = false;
			for (entry in old) if(entry.filter == filter) managed = true;
			if(!managed) others.push(filter);
		}
		for (entry in list) others.push(entry.filter);
		if(list.length > 0) stacks.set(camera, list);
		else stacks.remove(camera);
		camera.setFilters(others);
	}

	static function listen()
	{
		if(listening) return;
		listening = true;
		FlxG.signals.preStateSwitch.add(function() stacks.clear());
	}
}
