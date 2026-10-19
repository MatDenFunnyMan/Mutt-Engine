package funkin.game.notes;

import flixel.FlxBasic;

class NoteTailLayer extends FlxBasic
{
	public var notes:FlxTypedGroup<Note>;
	public var sustains:Bool;

	public function new(notes:FlxTypedGroup<Note>, sustains:Bool)
	{
		super();
		this.notes = notes;
		this.sustains = sustains;
	}

	override function draw()
	{
		if(notes == null || !notes.exists) return;

		@:privateAccess
		{
			final oldDefaultCameras = FlxCamera._defaultCameras;
			if(notes.cameras != null) FlxCamera._defaultCameras = notes.cameras;
			for (note in notes.members)
				if(note != null && note.exists && note.visible && note.isSustainNote == sustains)
					note.draw();
			FlxCamera._defaultCameras = oldDefaultCameras;
		}
	}
}
