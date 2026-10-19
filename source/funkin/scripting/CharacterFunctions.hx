package funkin.scripting;

import funkin.data.Song;
import funkin.game.Character;
import funkin.game.notes.ExtraStrumlineLayout;

class CharacterFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		Lua_helper.add_callback(lua, "setSingAlong", function(commander:Dynamic, ?followers:Dynamic = null, ?all:Bool = false) {
			var game:PlayState = PlayState.instance;
			if(game == null) return false;
			if(!game.setSingAlong(Std.string(commander), followerList(followers), all))
			{
				FunkinLua.luaTrace('setSingAlong: $commander is not a valid character!', false, false, FlxColor.RED);
				return false;
			}
			return true;
		});
		Lua_helper.add_callback(lua, "getSingAlong", function(commander:Dynamic) {
			var game:PlayState = PlayState.instance;
			var key:String = PlayState.trailKey(Std.string(commander));
			var followers:Array<String> = (game != null && key != null) ? game.singAlongs.get(key) : null;
			return (followers != null) ? followers.copy() : [];
		});
		Lua_helper.add_callback(lua, "getExtraCharacters", function() {
			var list:Array<Dynamic> = [];
			var game:PlayState = PlayState.instance;
			if(game == null || PlayState.SONG == null || PlayState.SONG.extraCharacters == null) return list;
			for (data in PlayState.SONG.extraCharacters)
			{
				if(data == null) continue;
				var char:Character = game.getExtraCharacter(data.slot);
				list.push({
					slot: data.slot,
					name: 'character${data.slot}',
					character: (char != null) ? char.curCharacter : '',
					parent: data.parent,
					strumline: data.strumline,
					playable: ExtraStrumlineLayout.isPlayer(data, game.opponentMode),
					visible: data.strumline == Song.SEPARATE && data.visible != false
				});
			}
			return list;
		});
	}

	static function followerList(value:Dynamic):String
	{
		if(value == null) return null;
		if(Std.isOfType(value, Array))
		{
			var parts:Array<String> = [];
			for (item in (value:Array<Dynamic>)) parts.push(Std.string(item));
			return parts.join(',');
		}
		return Std.string(value);
	}
}
