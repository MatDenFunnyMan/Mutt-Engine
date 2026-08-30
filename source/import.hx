#if !macro
//Discord API
#if DISCORD_ALLOWED
import funkin.util.Discord;
#end

//Psych
#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if ACHIEVEMENTS_ALLOWED
import funkin.save.Achievements;
#end

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
#end

import funkin.Paths;
import funkin.input.Controls;
import funkin.util.CoolUtil;
import funkin.backend.MusicBeatState;
import funkin.backend.MusicBeatSubstate;
import funkin.backend.CustomFadeTransition;
import funkin.backend.SubStateManager;
import funkin.save.ClientPrefs;
import funkin.Conductor;
import funkin.game.stages.BaseStage;
import funkin.data.Difficulty;
import funkin.modding.Mods;
import funkin.data.Language;

import funkin.ui.psychui.*; //Psych-UI

import funkin.ui.Alphabet;
import funkin.graphics.BGSprite;

import funkin.game.states.PlayState;
import funkin.ui.states.LoadingState;

#if flxanimate
import flxanimate.*;
import flxanimate.PsychFlxAnimate as FlxAnimate;
#end

//Flixel
import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;
#end
