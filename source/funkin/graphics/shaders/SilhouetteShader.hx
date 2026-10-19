package funkin.graphics.shaders;

import flixel.addons.display.FlxRuntimeShader;

class SilhouetteShader extends FlxRuntimeShader
{
	static final SOURCE:String = '
#pragma header

uniform vec3 silColor;
uniform float amount;

void main()
{
	vec4 tex = flixel_texture2D(bitmap, openfl_TextureCoordv);
	if(tex.a <= 0.0)
	{
		gl_FragColor = tex;
		return;
	}
	vec3 base = tex.rgb / tex.a;
	float light = dot(base, vec3(0.299, 0.587, 0.114));
	float colorLight = dot(silColor, vec3(0.299, 0.587, 0.114));
	vec3 detailColor = (colorLight > 0.5) ? silColor * 0.3 : mix(silColor, vec3(1.0), 0.6);
	float line = 1.0 - smoothstep(0.04, 0.16, light);
	vec3 tinted = mix(silColor, detailColor, line);
	gl_FragColor = vec4(mix(base, tinted, amount) * tex.a, tex.a);
}';

	public function new()
	{
		super(SOURCE);
		setColor(FlxColor.BLACK, 0);
	}

	public function setColor(color:FlxColor, amount:Float)
	{
		setFloatArray('silColor', [color.redFloat, color.greenFloat, color.blueFloat]);
		setFloat('amount', amount);
	}
}
