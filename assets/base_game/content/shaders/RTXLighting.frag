#pragma header

uniform vec4 overlayColor;
uniform vec4 satinColor;
uniform vec4 innerShadowColor;
uniform float innerShadowAngle;
uniform float innerShadowDistance;
uniform vec4 frameBounds;
uniform vec2 frameFlip;

const int SAMPLES = 5;

float blendColorDodge(float base, float blend)
{
	return (blend == 1.0) ? blend : min(base / (1.0 - blend), 1.0);
}

vec3 blendColorDodge(vec3 base, vec3 blend)
{
	return vec3(blendColorDodge(base.r, blend.r), blendColorDodge(base.g, blend.g), blendColorDodge(base.b, blend.b));
}

void main()
{
	vec2 uv = openfl_TextureCoordv.xy;
	vec4 color = flixel_texture2D(bitmap, uv);
	if (color.a <= 0.0)
	{
		gl_FragColor = color;
		return;
	}

	vec3 rgb = color.rgb / color.a;
	rgb = mix(rgb, rgb * satinColor.rgb, satinColor.a);

	vec4 bounds = (frameBounds.z > frameBounds.x && frameBounds.w > frameBounds.y) ? frameBounds : vec4(0.0, 0.0, 1.0, 1.0);
	vec2 flip = vec2(frameFlip.x < 0.0 ? -1.0 : 1.0, frameFlip.y < 0.0 ? -1.0 : 1.0);
	vec2 direction = vec2(cos(innerShadowAngle), sin(innerShadowAngle)) * flip;
	vec2 stepUV = direction * (innerShadowDistance / openfl_TextureSize.xy) / float(SAMPLES);

	for (int i = 0; i < SAMPLES; i++)
	{
		vec2 probe = uv + stepUV * float(i);
		float probeAlpha = 0.0;
		if (probe.x >= bounds.x && probe.y >= bounds.y && probe.x <= bounds.z && probe.y <= bounds.w)
			probeAlpha = texture2D(bitmap, probe).a;
		rgb = mix(rgb, blendColorDodge(rgb, innerShadowColor.rgb), innerShadowColor.a * (1.0 - probeAlpha));
	}

	rgb = mix(rgb, max(rgb, overlayColor.rgb), overlayColor.a);
	gl_FragColor = vec4(rgb * color.a, color.a);
}
