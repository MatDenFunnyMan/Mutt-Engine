package funkin.graphics.shaders;

import flixel.system.FlxAssets.FlxShader;
import funkin.data.WeekData;

class WeekColorShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform vec3 weekColor;

		void main()
		{
			vec4 tex = flixel_texture2D(bitmap, openfl_TextureCoordv);
			if(tex.a <= 0.0)
			{
				gl_FragColor = tex;
				return;
			}
			float lum = dot(tex.rgb / tex.a, vec3(0.299, 0.587, 0.114));
			vec3 tinted = clamp(weekColor * (lum / 0.8046), 0.0, 1.0);
			gl_FragColor = vec4(tinted * tex.a, tex.a);
		}
	')

	public function new()
	{
		super();
		setColor(WeekData.DEFAULT_COLOR);
	}

	public function setColor(color:FlxColor)
	{
		weekColor.value = [color.redFloat, color.greenFloat, color.blueFloat];
	}

	public static function apply(sprite:FlxSprite, colors:Array<Int>, ?color:Null<FlxColor>)
	{
		if(colors == null || colors.length < 3)
		{
			sprite.shader = null;
			return;
		}
		var shader:WeekColorShader = Std.isOfType(sprite.shader, WeekColorShader) ? cast sprite.shader : new WeekColorShader();
		shader.setColor(color != null ? color : WeekData.getWeekColor(colors));
		sprite.shader = shader;
	}
}
