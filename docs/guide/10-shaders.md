# Shaders

Shaders are small programs that change how things are drawn: colors, blur, glow, distortion. They are `.frag` files in `content/shaders/`, the same kind of shaders Psych Engine uses.

## The Shader Editor

The Shader Editor puts shaders on a stage **without writing scripts**. The shaders are saved inside the stage file and start by themselves in every song with that stage.

Open it from the Editor Menu, then pick a stage.

| Part | What's inside |
|---|---|
| **Stage** tab | The stage to edit, Reload, Save. |
| **Characters** tab | Which characters to show in the preview (only for the editor). |
| **Shaders** box | The list of shaders of the stage. For each one: the `.frag` file, the **target**, a name, and the starting value of every setting. |
| **Lighting Editor** | RTX lighting for characters (see below). |

The **target** is what the shader is drawn on: a camera (`camGame`, `camHUD`, `camOther`), a character (BF, Dad, GF, extra characters) or an object of the stage. More shaders on the same camera are applied in order: use **Move Up** to change it.

Values are written like this: a number for `float` and `int`, `1, 0.5, 0` for `vec2`/`vec3`/`vec4`, `true` or `false` for `bool`, an image path for `sampler2D`. Empty = the shader's default.

| Key | Action |
|---|---|
| E / Q, mouse wheel | Zoom in / out |
| J / K / L / I, mouse drag | Move the camera |
| R | Reset the camera |
| P | Reload the stage |
| Ctrl + S | Save |

### RTX lighting

The **Lighting Editor** adds rim lighting to a character, to make it match the light of the stage. Pick a character and change:

- **Overlay**: brightens the character with a color.
- **Satin**: multiplies the character by a color.
- **Inner Shadow**: lights the edges facing a direction, with an angle and a distance.

## Shaders in scripts

```lua
function onCreate()
	addCameraShader('camGame', 'glow')
	setShaderFloat('camGame:glow', 'intensity', 0)
end

function onBeatHit()
	if curBeat == 32 then
		tweenShader('glowUp', 'camGame:glow', {intensity = 1}, 2, {ease = 'sineOut'})
	end
end
```

### Which shader?

Every shader function takes the object that has the shader:

| You write | Shader |
|---|---|
| `'myBackground'` | The shader of an object or character. |
| `'camGame:glow'` | The shader named `glow` on the game camera. `'camGame'` alone = its first shader. |
| `'stage:glow'` | The shader named `glow` added in the Shader Editor. |

### Functions

| Function | What it does |
|---|---|
| `initLuaShader(name)` | Loads a shader before using it. |
| `setSpriteShader(obj, shader)` / `removeSpriteShader(obj)` | Puts / removes a shader on an object. |
| `addCameraShader(camera, shader, ?name)` | Adds a shader to a camera, after the ones it already has. |
| `setCameraShader(camera, shader)` | Replaces all the shaders of a camera with one. |
| `removeCameraShader(camera, ?name)` | Removes one shader (by name) or all of them. |
| `getCameraShaders(camera)` | Names of the shaders on a camera, in order. |
| `setShaderFloat`, `setShaderInt`, `setShaderBool`... | Change a value of a shader. |
| `getShaderFloat`, `getShaderInt`, `getShaderBool`... | Read a value. |
| `setShaderSampler2D(obj, prop, image)` | Sends an image to a shader. |
| `tweenShader(tag, obj, values, duration, ?options)` | Tweens several values at once, of any type (numbers, vectors, colors). |
| `tweenShaderFloat(tag, obj, uniform, value, duration, ?options)` | Tweens one number. |

The old `setCameraShaderFloat` and friends still work, but `setShaderFloat('camGame:name', ...)` replaces them.
