# Building Mutt Engine

This page shows the necessary steps for **COMPILING** a source code build of Mutt Engine.
Mutt Engine is built for **Windows** and as of now there are no plans for Mac or Linux ports (sorry).

## Requirements

1. **Haxe 4.3.4 or newer**: [haxe.org/download](https://haxe.org/download/).
2. **Git**: [git-scm.com](https://git-scm.com/downloads).
3. **Visual Studio 2019 or 2022** (the free Community edition or the Build Tools), with these parts selected in the installer:
   - *MSVC v142 (or newer) - VS C++ x64/x86 build tools*
   - *Windows 10 SDK (10.0.19041.0)*

## Libraries

Run these commands by terminal or Powershell. Use the **exact versions** or else it will FAIL to compile.

```bat
haxelib install hxcpp 4.3.2
haxelib install lime 8.1.2
haxelib install openfl 9.3.3
haxelib install flixel 5.6.1
haxelib install flixel-addons 3.2.2
haxelib install tjson 1.4.0
haxelib install hscript-iris 1.1.3
haxelib install hxvlc 2.3.0
haxelib install hxdiscord_rpc 1.2.4
haxelib install away3d 5.0.9
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git
haxelib run lime setup
```

| Library | Used for |
|---|---|
| `hxcpp` | Turns the Haxe code into C++. |
| `lime`, `openfl` | Window, graphics, sound and files. |
| `flixel`, `flixel-addons` | The game framework. |
| `tjson` | Reading JSON files. |
| `linc_luajit` | Lua scripts. |
| `hscript-iris` | HScript scripts. |
| `hxvlc` | Videos. |
| `hxdiscord_rpc` | Discord status. |
| `flxanimate` | Adobe Animate texture atlases. |
| `funkin.vis`, `grig.audio` | The speaker visualizer of the base game stages. |
| `away3d` | 3D objects. |

`flixel-animate` was added as an external library due to compiling issues. It can be found inside `libs/flixel-animate`.

**NOTE (for programmers):** Part of this engine was made with the assistance of AI. I'm not an expert programmer and I don't know source coding well. This is not meant to be a serious thing but rather just a fun project I wanted to make for myself. Source code is on GitHub but it will not be distributed nor shared publicly online, unless a different decision is made.

Please don't come harassing me for this, it's not that deep. I don't even feel proud for making this at all!

It's actually meant to be a "base" or "mock-up" for a new version of Psych Engine made by real people who know programming and are not fat chuds like me (I'm serious, btw).

## Compiling

Same as Psych Engine. On the main directory of the folder you installed the source code (aka where `Project.xml` is located), run this command in **`Command Prompt / Powershell`**:

```bat
lime test windows
```

Additionally, if you want to compile without opening the game:

```bat
lime build windows
```

Then `lime run windows` to start the application.

## Useful folders

| Folder | Description |
|---|---|
| `assets/` | Base game files, including custom assets loaded inside. |
| `assets/embed/` | Files hidden in the **executable file** that aren't accessible to the public UNLESS you have the source code. Similar to what Sonic Legacy does. |
| `loaded-mods/` | Mods that are automatically loaded in `mods/`, only if `MODS_ALLOWED` is enabled and `STANDALONE_BUILD` is disabled in `Project.xml` |
| `source/` | Engine's source code. `funkin/` contains majority of the engine's core functions, while the rest is used for libraries. |

## Build options

The options are `<define>` lines at the top of `Project.xml`. Remove a line to turn that feature off.

| Option | Description |
|---|---|
| `MODS_ALLOWED` | Toggles `mods/` and mod support. |
| `LUA_ALLOWED` | Lua scripting. |
| `HSCRIPT_ALLOWED` | HScript scripting. |
| `VIDEOS_ALLOWED` | Toggles Videos playback. |
| `DISCORD_ALLOWED` | Toggles Discord RPC. |
| `ACHIEVEMENTS_ALLOWED` | Toggles Achievements. |
| `TRANSLATIONS_ALLOWED` | Enables Language options. |
| `MULTITHREADED_LOADING` | Better asset loading, faster loading times. |
| `CRASH_HANDLER` | Enables crash handler and `crash/` folder upon fatal error. |
