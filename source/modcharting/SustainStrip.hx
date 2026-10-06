package modcharting;

import funkin.game.notes.Note;
import funkin.game.notes.StrumNote;
import funkin.game.states.PlayState;
import funkin.backend.MusicBeatState;

import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import openfl.geom.Vector3D;
#if LEATHER
import game.Note;
#end
import flixel.FlxStrip;

class SustainStrip extends FlxStrip
{
    private static final noteUV:Array<Float> = [
        0,0, //top left
        1,0, //top right
        0,0.5, //half left
        1,0.5, //half right    
        0,1, //bottom left
        1,1, //bottom right 
    ];
    private static final noteIndices:Array<Int> = [
        0,1,2,1,3,2, 2,3,4,3,4,5
        //makes 4 triangles
    ];

    private var daNote:Note;

    override public function new(daNote:Note)
    {
        this.daNote = daNote;
        daNote.alpha = 1;
        super(0,0);
        loadGraphic(daNote.graphic);
        shader = daNote.shader;
        var i:Int = 0;
        while (i < noteUV.length)
        {
            var uv:Array<Float> = frameUV(daNote, noteUV[i], noteUV[i + 1]);
            uvtData.push(uv[0]);
            uvtData.push(uv[1]);
            vertices.push(0);
            vertices.push(0);
            i += 2;
        }
        for (ind in noteIndices)
            indices.push(ind);
    }

    private static function frameUV(daNote:Note, u:Float, v:Float):Array<Float>
    {
        var frame = daNote.frame;
        var doFlipX:Bool = daNote.flipX != frame.flipX;
        var doFlipY:Bool = daNote.flipY != frame.flipY;
        if (daNote.animation.curAnim != null)
        {
            doFlipX = doFlipX != daNote.animation.curAnim.flipX;
            doFlipY = doFlipY != daNote.animation.curAnim.flipY;
        }
        if (doFlipX) u = 1 - u;
        if (doFlipY) v = 1 - v;

        var localX:Float = u;
        var localY:Float = v;
        if (frame.angle == flixel.graphics.frames.FlxFrame.FlxFrameAngle.ANGLE_NEG_90)
        {
            localX = 1 - v;
            localY = u;
        }
        else if (frame.angle == flixel.graphics.frames.FlxFrame.FlxFrameAngle.ANGLE_90)
        {
            localX = v;
            localY = 1 - u;
        }

        var rect = frame.frame;
        var bitmapWidth:Float = daNote.graphic.width;
        var bitmapHeight:Float = daNote.graphic.height;
        var left:Float = rect.x + 0.5;
        var top:Float = rect.y + 0.5;
        var right:Float = rect.right - 0.5;
        var bottom:Float = rect.bottom - 0.5;
        return [(left + (right - left) * localX) / bitmapWidth, (top + (bottom - top) * localY) / bitmapHeight];
    }

    public function constructVertices(noteData:NotePositionData, thisNotePos:Vector3D, nextHalfNotePos:NotePositionData, nextNotePos:NotePositionData, flipGraphic:Bool, reverseClip:Bool)
    {
        var yOffset = 2; //fix small gaps
        if (reverseClip)
            yOffset = -yOffset;

        var verts:Array<Float> = [];
        if (flipGraphic)
        {
            verts.push(nextNotePos.x);
            verts.push(nextNotePos.y+yOffset); //slight offset to fix small gaps
            verts.push(nextNotePos.x+(daNote.frameWidth*(1/-nextNotePos.z)*noteData.scaleX));
            verts.push(nextNotePos.y+yOffset);

            verts.push(nextHalfNotePos.x);
            verts.push(nextHalfNotePos.y);
            verts.push(nextHalfNotePos.x+(daNote.frameWidth*(1/-nextHalfNotePos.z)*noteData.scaleX));
            verts.push(nextHalfNotePos.y);

            verts.push(thisNotePos.x);
            verts.push(thisNotePos.y);
            verts.push(thisNotePos.x+(daNote.frameWidth*(1/-thisNotePos.z)*nextNotePos.scaleX));
            verts.push(thisNotePos.y);
        }
        else 
        {
            verts.push(thisNotePos.x);
            verts.push(thisNotePos.y);
            verts.push(thisNotePos.x+(daNote.frameWidth*(1/-thisNotePos.z)*noteData.scaleX));
            verts.push(thisNotePos.y);

            verts.push(nextHalfNotePos.x);
            verts.push(nextHalfNotePos.y);
            verts.push(nextHalfNotePos.x+(daNote.frameWidth*(1/-nextHalfNotePos.z)*noteData.scaleX));
            verts.push(nextHalfNotePos.y);

            verts.push(nextNotePos.x);
            verts.push(nextNotePos.y+yOffset); //slight offset to fix small gaps
            verts.push(nextNotePos.x+(daNote.frameWidth*(1/-nextNotePos.z)*nextNotePos.scaleX));
            verts.push(nextNotePos.y+yOffset);
        }
        vertices = new DrawData(12, true, verts);
    }


}