package funkin.graphics.shaders;

import flixel.addons.display.FlxRuntimeShader;
import funkin.graphics.shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

typedef ShaderUniform = {
	var name:String;
	var type:String;
}

class ShaderLoader
{
	public static final UNIFORM_TYPES:Array<String> = ['float', 'int', 'bool', 'vec2', 'vec3', 'vec4', 'ivec2', 'ivec3', 'ivec4', 'bvec2', 'bvec3', 'bvec4', 'sampler2D'];
	static final HIDDEN_UNIFORMS:Array<String> = ['bitmap', 'hasTransform', 'hasColorTransform', 'openfl_TextureSize', 'frameBounds', 'frameFlip'];

	public static function folders():Array<String>
	{
		#if sys
		return Mods.directoriesWithFile(Paths.getSharedPath(), 'shaders/');
		#else
		return [];
		#end
	}

	public static function source(name:String):Array<String>
	{
		#if sys
		if(name == null || name.length < 1) return null;
		for (folder in folders())
		{
			var frag:String = folder + name + '.frag';
			var vert:String = folder + name + '.vert';
			var fragSource:String = FileSystem.exists(frag) ? File.getContent(frag) : null;
			var vertSource:String = FileSystem.exists(vert) ? File.getContent(vert) : null;
			if(fragSource != null || vertSource != null) return [fragSource, vertSource];
		}
		#end
		return null;
	}

	public static function list():Array<String>
	{
		var names:Array<String> = [];
		#if sys
		for (folder in folders())
		{
			if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) continue;
			for (file in FileSystem.readDirectory(folder))
			{
				var dot:Int = file.lastIndexOf('.');
				if(dot < 1) continue;
				var ext:String = file.substr(dot + 1).toLowerCase();
				if(ext != 'frag' && ext != 'vert') continue;
				var name:String = file.substr(0, dot);
				if(!names.contains(name)) names.push(name);
			}
		}
		#end
		names.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : (a.toLowerCase() > b.toLowerCase() ? 1 : 0));
		return names;
	}

	public static function uniforms(name:String):Array<ShaderUniform>
	{
		var result:Array<ShaderUniform> = [];
		var code:Array<String> = source(name);
		if(code == null) return result;
		for (part in code)
		{
			if(part == null) continue;
			for (line in part.split('\n'))
			{
				var words:Array<String> = [for (word in line.replace('\t', ' ').replace(';', ' ; ').split(' ')) if(word.length > 0) word];
				var index:Int = words.indexOf('uniform');
				if(index < 0 || index + 2 >= words.length) continue;
				var type:String = words[index + 1];
				if(!UNIFORM_TYPES.contains(type))
				{
					if(index + 3 >= words.length || !UNIFORM_TYPES.contains(words[index + 2])) continue;
					index++;
					type = words[index + 1];
				}
				var uniformName:String = words[index + 2];
				if(uniformName.contains('[') || HIDDEN_UNIFORMS.contains(uniformName) || uniformName.startsWith('openfl_')) continue;
				var exists:Bool = false;
				for (uniform in result) if(uniform.name == uniformName) exists = true;
				if(!exists) result.push({name: uniformName, type: type});
			}
		}
		return result;
	}

	public static function create(name:String):FlxRuntimeShader
	{
		#if (!flash && sys)
		if(!ClientPrefs.data.shaders) return null;
		var code:Array<String> = source(name);
		if(code == null) return null;
		return new ErrorHandledRuntimeShader(name, code[0], code[1]);
		#else
		return null;
		#end
	}

	public static function applyValue(shader:FlxRuntimeShader, uniform:ShaderUniform, value:Dynamic):Bool
	{
		if(shader == null || uniform == null || value == null) return false;
		try
		{
			switch(uniform.type)
			{
				case 'float':
					shader.setFloat(uniform.name, toFloat(value));
				case 'int':
					shader.setInt(uniform.name, Std.int(toFloat(value)));
				case 'bool':
					shader.setBool(uniform.name, toBool(value));
				case 'vec2' | 'vec3' | 'vec4':
					shader.setFloatArray(uniform.name, [for (item in toList(value, size(uniform.type))) toFloat(item)]);
				case 'ivec2' | 'ivec3' | 'ivec4':
					shader.setIntArray(uniform.name, [for (item in toList(value, size(uniform.type))) Std.int(toFloat(item))]);
				case 'bvec2' | 'bvec3' | 'bvec4':
					shader.setBoolArray(uniform.name, [for (item in toList(value, size(uniform.type))) toBool(item)]);
				case 'sampler2D':
					var path:String = Std.string(value).trim();
					if(path.length < 1) return false;
					var graphic = Paths.image(path);
					if(graphic == null || graphic.bitmap == null) return false;
					shader.setSampler2D(uniform.name, graphic.bitmap);
				default:
					return false;
			}
			return true;
		}
		catch(e:Dynamic)
		{
			trace('ShaderLoader: could not set ${uniform.name}: $e');
		}
		return false;
	}

	public static function applyValues(shader:FlxRuntimeShader, name:String, values:Dynamic)
	{
		if(shader == null || values == null) return;
		for (uniform in uniforms(name))
			if(Reflect.hasField(values, uniform.name))
				applyValue(shader, uniform, Reflect.field(values, uniform.name));
	}

	public static function isCameraTarget(target:String):Bool
	{
		return switch(target != null ? target.toLowerCase() : '')
		{
			case 'camgame' | 'camhud' | 'camother': true;
			default: false;
		}
	}

	public static function parseText(type:String, text:String):Dynamic
	{
		if(text == null) return null;
		text = text.trim();
		if(text.length < 1) return null;
		switch(type)
		{
			case 'sampler2D':
				return text;
			case 'bool':
				return toBool(text);
			case 'float' | 'int':
				var value:Float = Std.parseFloat(text);
				return Math.isNaN(value) ? null : (type == 'int' ? Std.int(value) : value);
			default:
				var parts:Array<Dynamic> = [];
				for (part in text.split(','))
				{
					part = part.trim();
					if(type.startsWith('b')) parts.push(toBool(part));
					else
					{
						var value:Float = Std.parseFloat(part);
						if(Math.isNaN(value)) return null;
						parts.push(type.startsWith('i') ? Std.int(value) : value);
					}
				}
				return parts;
		}
	}

	public static function formatValue(value:Dynamic):String
	{
		if(value == null) return '';
		if(Std.isOfType(value, Array)) return [for (item in (value : Array<Dynamic>)) Std.string(item)].join(', ');
		return Std.string(value);
	}

	static function size(type:String):Int
		return Std.parseInt(type.charAt(type.length - 1));

	static function toList(value:Dynamic, count:Int):Array<Dynamic>
	{
		var list:Array<Dynamic> = Std.isOfType(value, Array) ? (value : Array<Dynamic>).copy() : [value];
		while(list.length < count) list.push(list.length > 0 ? list[list.length - 1] : 0);
		return list.slice(0, count);
	}

	static function toFloat(value:Dynamic):Float
	{
		if(Std.isOfType(value, String)) return Std.parseFloat(value);
		if(Std.isOfType(value, Bool)) return value ? 1 : 0;
		return value;
	}

	static function toBool(value:Dynamic):Bool
	{
		if(Std.isOfType(value, String)) return (value : String).trim().toLowerCase() == 'true' || (value : String).trim() == '1';
		if(Std.isOfType(value, Bool)) return value;
		return toFloat(value) != 0;
	}
}
