package modcharting;

import funkin.game.notes.Note;
import funkin.game.notes.StrumNote;
import funkin.game.states.PlayState;
import funkin.backend.MusicBeatState;


import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import flixel.FlxStrip;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import openfl.geom.Vector3D;
import flixel.util.FlxSpriteUtil;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.FlxSprite;

import flixel.FlxG;
import modcharting.Modifier;
import flixel.system.FlxAssets.FlxShader;

#if LEATHER
import states.PlayState;
import game.Note;
import game.StrumNote;
import game.Conductor;
#else 
#end

using StringTools;

//a few todos im gonna leave here:

//setup quaternions for everything else (incoming angles and the rotate mod)
//do add and remove buttons on stacked events in editor
//fix switching event type in editor so you can actually do set events
//finish setting up tooltips in editor
//start documenting more stuff idk

typedef StrumNoteType = 
#if (PSYCH || LEATHER) StrumNote
#elseif KADE StaticArrow
#elseif FOREVER_LEGACY UIStaticArrow
#elseif ANDROMEDA Receptor
#else FlxSprite #end;

class PlayfieldRenderer extends FlxSprite //extending flxsprite just so i can edit draw
{
    public var strumGroup:FlxTypedGroup<StrumNoteType>;
    public var notes:FlxTypedGroup<Note>;
    public var instance:ModchartMusicBeatState;
    public var playStateInstance:PlayState;
    public var playfields:Array<Playfield> = []; //adding an extra playfield will add 1 for each player

    public var eventManager:ModchartEventManager;
    public var modifierTable:ModTable;
    public var tweenManager:FlxTweenManager;

    public var modchart:ModchartFile;
    public var inEditor:Bool = false;
    public var editorPaused:Bool = false;

    public var speed:Float = 1.0;

    public var modifiers(get, default):Map<String, Modifier>;
    
    private function get_modifiers() : Map<String, Modifier>
    {
        return modifierTable.modifiers; //back compat with lua modcharts
    }


    public function new(strumGroup:FlxTypedGroup<StrumNoteType>, notes:FlxTypedGroup<Note>,instance:ModchartMusicBeatState) 
    {
        super(0,0);
        this.strumGroup = strumGroup;
        this.notes = notes;
        this.instance = instance;
        if (Std.isOfType(instance, PlayState))
            playStateInstance = cast instance; //so it just casts once

        strumGroup.visible = false; //drawing with renderer instead
        notes.visible = false;

        //fix stupid crash because the renderer in playstate is still technically null at this point and its needed for json loading
        instance.playfieldRenderer = this;

        tweenManager = new FlxTweenManager();
        eventManager = new ModchartEventManager(this);
        modifierTable = new ModTable(instance, this);
        addNewPlayfield(0,0,0);
        modchart = new ModchartFile(this);
    }


    public function addNewPlayfield(?x:Float = 0, ?y:Float = 0, ?z:Float = 0, ?alpha:Float = 1)
    {
        playfields.push(new Playfield(x,y,z,alpha));
    }

    override function update(elapsed:Float) 
    {
        eventManager.update(elapsed);
        tweenManager.update(elapsed); //should be automatically paused when you pause in game
        super.update(elapsed);
    }


    var strumBaseAlpha:Array<Float> = [];
    var strumDrawnAlpha:Array<Float> = [];

    function syncStrumBaseAlpha()
    {
        for (i in 0...strumGroup.members.length)
        {
            var strum = strumGroup.members[i];
            if (strum == null)
                continue;
            if (i >= strumBaseAlpha.length || strum.alpha != strumDrawnAlpha[i])
            {
                strumBaseAlpha[i] = strum.alpha;
                strumDrawnAlpha[i] = strum.alpha;
            }
        }
    }

    function getStrumBaseAlpha(index:Int):Float
    {
        return (index >= 0 && index < strumBaseAlpha.length) ? strumBaseAlpha[index] : 1;
    }

    override public function draw()
    {
        if (alpha == 0 || !visible)
            return;

        syncStrumBaseAlpha();

        strumGroup.cameras = this.cameras;
        notes.cameras = this.cameras;
        
        drawStuff(getNotePositions());
        //draw notes to screen

        #if PSYCH
        syncEngineAttachments();
        #end
    }

    #if PSYCH
    private function syncEngineAttachments()
    {
        if (playStateInstance == null)
            return;

        var isPixelStage = ModchartUtil.getIsPixelStage(instance);

        for (i in 0...strumGroup.members.length)
        {
            var strum = strumGroup.members[i];
            if (strum == null || strum.holdCover == null)
                continue;

            var baseScale = isPixelStage ? PlayState.daPixelZoom : ((i < NoteMovement.defaultScale.length) ? NoteMovement.defaultScale[i] / laneScale(i) : 0);
            var ratio = (baseScale != 0) ? strum.scale.x / baseScale : 1;

            strum.holdCover.followStrum(strum, isPixelStage, ratio);
        }

        for (splash in playStateInstance.grpNoteSplashes.members)
            if (splash != null && splash.exists && splash.visible)
                splash.followStrum();
    }
    #end


    private function addDataToStrum(strumData:NotePositionData, strum:FlxSprite)
    {
        strum.x = strumData.x;
        strum.y = strumData.y;
        //strum.z = strumData.z;
        strum.angle = strumData.angle;
        strum.alpha = strumData.alpha;
        strumDrawnAlpha[strumData.index] = strum.alpha;
        strum.scale.x = strumData.scaleX;
        strum.scale.y = strumData.scaleY;
    }

    private function getDataForStrum(i:Int, pf:Int)
    {
        var strumX = NoteMovement.defaultStrumX[i];
        var strumY = NoteMovement.defaultStrumY[i];
        var strumZ = 0;
        var strumScaleX = NoteMovement.defaultScale[i];
        var strumScaleY = NoteMovement.defaultScale[i];
        if (ModchartUtil.getIsPixelStage(instance))
        {
            //work on pixel stages
            strumScaleX = laneScale(i)*PlayState.daPixelZoom;
            strumScaleY = laneScale(i)*PlayState.daPixelZoom;
        }
        var strumData:NotePositionData = NotePositionData.get();
        strumData.setupStrum(strumX, strumY, strumZ, i, strumScaleX, strumScaleY, pf);
        playfields[pf].applyOffsets(strumData);
        modifierTable.applyStrumMods(strumData, i, pf);
        return strumData;
    }

    function isExtraLane(lane:Int):Bool
    {
        return lane >= NoteMovement.totalKeyCount;
    }

    function laneScale(lane:Int):Float
    {
        if (lane >= NoteMovement.defaultScale.length)
            return 1;
        return NoteMovement.defaultScale[lane] / NoteMovement.arrowScale;
    }

   

    private function addDataToNote(noteData:NotePositionData, daNote:Note)
    {
        daNote.x = noteData.x;
        daNote.y = noteData.y;
        daNote.z = noteData.z;
        daNote.angle = noteData.angle;
        daNote.alpha = noteData.alpha;
        daNote.scale.x = noteData.scaleX;
        daNote.scale.y = noteData.scaleY;
    }
    private function createDataFromNote(noteIndex:Int, playfieldIndex:Int, curPos:Float, noteDist:Float, incomingAngle:Array<Float>)
    {
        var noteX = notes.members[noteIndex].x;
        var noteY = notes.members[noteIndex].y;
        var noteZ = notes.members[noteIndex].z;
        var lane = getLane(noteIndex);
        var noteScaleX = NoteMovement.defaultScale[lane];
        var noteScaleY = NoteMovement.defaultScale[lane];

        var noteAlpha:Float = 1;
        #if PSYCH
        noteAlpha = notes.members[noteIndex].multAlpha * getStrumBaseAlpha(lane);
        #else 
        if (notes.members[noteIndex].isSustainNote)
            noteAlpha = 0.6;
        else 
            noteAlpha = 1;
        #end

        if (ModchartUtil.getIsPixelStage(instance))
        {
            //work on pixel stages
            noteScaleX = laneScale(lane)*PlayState.daPixelZoom;
            noteScaleY = laneScale(lane)*PlayState.daPixelZoom;
        }

        var noteData:NotePositionData = NotePositionData.get();
        noteData.setupNote(noteX, noteY, noteZ, lane, noteScaleX, noteScaleY, playfieldIndex, noteAlpha,
            curPos, noteDist, incomingAngle[0], incomingAngle[1], notes.members[noteIndex].strumTime, noteIndex);
        playfields[playfieldIndex].applyOffsets(noteData);

        return noteData;
    }

    private function getNoteCurPos(noteIndex:Int, strumTimeOffset:Float = 0)
    {
        #if PSYCH
        if (notes.members[noteIndex].isSustainNote && ModchartUtil.getDownscroll(instance))
            strumTimeOffset -= sustainSpan(notes.members[noteIndex]);
        #else 
        if (notes.members[noteIndex].isSustainNote && !ModchartUtil.getDownscroll(instance))
            strumTimeOffset += Conductor.stepCrochet; //fix upscroll lol
        #end
        var distance = (Conductor.songPosition - notes.members[noteIndex].strumTime) + strumTimeOffset;
        return distance*getCorrectScrollSpeed()*notes.members[noteIndex].multSpeed;
    }
    private function getLane(noteIndex:Int)
    {
        var note:Note = notes.members[noteIndex];
        if (note.strumline >= 0)
            return NoteMovement.totalKeyCount + note.strumline * 4 + note.noteData;
        return (note.mustPress ? note.noteData+NoteMovement.keyCount : note.noteData);
    }
    private function getNoteDist(noteIndex:Int)
    {
        var noteDist = -0.45;
        if (ModchartUtil.getDownscroll(instance))
            noteDist *= -1;
        return noteDist;
    }


    private function getNotePositions()
    {
        var notePositions:Array<NotePositionData> = [];
        for (pf in 0...playfields.length)
        {
            for (i in 0...strumGroup.members.length)
            {
                if (isExtraLane(i) && !strumGroup.members[i].visible)
                    continue;
                var strumData = getDataForStrum(i, pf);
                notePositions.push(strumData);
            }
            for (i in 0...notes.members.length)
            {
                var songSpeed = getCorrectScrollSpeed();

                var lane = getLane(i);
                if (isExtraLane(lane) && !notes.members[i].visible)
                    continue;

                var noteDist = getNoteDist(i);
                noteDist = modifierTable.applyNoteDistMods(noteDist, lane, pf);


                var sustainTimeThingy:Float = 0;

                //just causes too many issues lol, might fix it at some point
                /*if (notes.members[i].animation.curAnim.name.endsWith('end') && ClientPrefs.downScroll)
                {
                    if (noteDist > 0)
                        sustainTimeThingy = (NoteMovement.getFakeCrochet()/4)/2; //fix stretched sustain ends (downscroll)
                    //else 
                        //sustainTimeThingy = (-NoteMovement.getFakeCrochet()/4)/songSpeed;
                }*/
                    
                var curPos = getNoteCurPos(i, sustainTimeThingy);
                curPos = modifierTable.applyCurPosMods(lane, curPos, pf);

                if ((notes.members[i].wasGoodHit || (notes.members[i].prevNote.wasGoodHit)) && curPos >= 0 && notes.members[i].isSustainNote)
                    curPos = 0; //sustain clip

                var incomingAngle:Array<Float> = modifierTable.applyIncomingAngleMods(lane, curPos, pf);
                if (noteDist < 0)
                    incomingAngle[0] += 180; //make it match for both scrolls
                    
                //get the general note path
                NoteMovement.setNotePath(notes.members[i], lane, songSpeed, curPos, noteDist, incomingAngle[0], incomingAngle[1]);

                //save the position data
                var noteData = createDataFromNote(i, pf, curPos, noteDist, incomingAngle);

                //add offsets to data with modifiers
                modifierTable.applyNoteMods(noteData, lane, curPos, pf);

                //add position data to list
                notePositions.push(noteData);
            }
        }
        //sort by z before drawing
        var tailsBehind:Bool = ClientPrefs.data.holdNoteTail == 'Behind';
        notePositions.sort(function(a, b){
            if (a.z < b.z)
                return -1;
            else if (a.z > b.z)
                return 1;
            else if (tailsBehind)
                return drawLayer(a) - drawLayer(b);
            else
                return 0;
        });
        return notePositions;
    }

    function drawLayer(data:NotePositionData):Int
    {
        if (data.isStrum)
            return 1;
        var note:Note = notes.members[data.index];
        return (note != null && note.isSustainNote) ? 0 : 2;
    }

    private function drawStrum(noteData:NotePositionData)
    {
        noteData.alpha *= getStrumBaseAlpha(noteData.index);
        if (noteData.alpha <= 0)
            return;
        var strumNote = strumGroup.members[noteData.index];
        var thisNotePos = ModchartUtil.calculatePerspective(new Vector3D(noteData.x+(strumNote.width/2), noteData.y+(strumNote.height/2), noteData.z*0.001), 
        ModchartUtil.defaultFOV*(Math.PI/180), -(strumNote.width/2), -(strumNote.height/2));

        noteData.x = thisNotePos.x;
        noteData.y = thisNotePos.y;
        noteData.scaleX *= (1/-thisNotePos.z);
        noteData.scaleY *= (1/-thisNotePos.z);

        addDataToStrum(noteData, strumGroup.members[noteData.index]); //set position and stuff before drawing
        strumGroup.members[noteData.index].cameras = this.cameras;

        strumGroup.members[noteData.index].draw();
    }
    private function drawNote(noteData:NotePositionData)
    {
        if (noteData.alpha <= 0)
            return;
        var daNote = notes.members[noteData.index];
        var thisNotePos = ModchartUtil.calculatePerspective(new Vector3D(noteData.x+(daNote.width/2)+ModchartUtil.getNoteOffsetX(daNote, instance), noteData.y+(daNote.height/2), noteData.z*0.001), 
        ModchartUtil.defaultFOV*(Math.PI/180), -(daNote.width/2), -(daNote.height/2));

        noteData.x = thisNotePos.x;
        noteData.y = thisNotePos.y;
        noteData.scaleX *= (1/-thisNotePos.z);
        noteData.scaleY *= (1/-thisNotePos.z);
        //set note position using the position data
        addDataToNote(noteData, notes.members[noteData.index]); 
        //make sure it draws on the correct camera
        notes.members[noteData.index].cameras = this.cameras;
        //draw it
        notes.members[noteData.index].draw();
    }
    static inline final TAIL_BEHIND_SHIFT:Float = -2;

    function tailShift(lane:Int):Float
    {
        if (ClientPrefs.data.holdNoteTail != 'Behind' || lane >= NoteMovement.arrowSizes.length)
            return 0;
        return TAIL_BEHIND_SHIFT * NoteMovement.arrowSizes[lane] / 112;
    }

    private function drawSustainNote(noteData:NotePositionData)
    {
        if (noteData.alpha <= 0)
            return;
        var daNote = notes.members[noteData.index];
        if (daNote.mesh == null)
            daNote.mesh = new SustainStrip(daNote);

        daNote.mesh.scrollFactor.x = daNote.scrollFactor.x;
        daNote.mesh.scrollFactor.y = daNote.scrollFactor.y;
        daNote.alpha = noteData.alpha;
        daNote.mesh.alpha = daNote.alpha;

        var songSpeed = getCorrectScrollSpeed();
        var lane = noteData.lane;
        
        //makes the sustain match the center of the parent note when at weird angles
        var yOffsetThingy = (NoteMovement.arrowSizes[lane]/2);

        var thisNotePos = ModchartUtil.calculatePerspective(new Vector3D(noteData.x+(daNote.width/2)+ModchartUtil.getNoteOffsetX(daNote, instance)+tailShift(lane), noteData.y+(NoteMovement.arrowSizes[noteData.lane]/2), noteData.z*0.001), 
        ModchartUtil.defaultFOV*(Math.PI/180), -(daNote.width/2), yOffsetThingy-(NoteMovement.arrowSizes[noteData.lane]/2));
        
        var timeToNextSustain = sustainSpan(daNote);
        if (noteData.noteDist < 0)
            timeToNextSustain = -timeToNextSustain;

        var nextHalfNotePos = getSustainPoint(noteData, timeToNextSustain*0.5);
        var nextNotePos = getSustainPoint(noteData, timeToNextSustain);

        var flipGraphic = false;

        // mod/bound to 360, add 360 for negative angles, mod again just in case
        var fixedAngY = ((noteData.incomingAngleY%360)+360)%360;

        var reverseClip = (fixedAngY > 90 && fixedAngY < 270);

        if (noteData.noteDist > 0) //downscroll
        {
            if (!ModchartUtil.getDownscroll(instance)) //fix reverse
                flipGraphic = true;
        }
        else
        {
            if (ModchartUtil.getDownscroll(instance))
                flipGraphic = true;
        }
        //render that shit
        daNote.mesh.constructVertices(noteData, thisNotePos, nextHalfNotePos, nextNotePos, flipGraphic, reverseClip);

        daNote.mesh.cameras = this.cameras;
        daNote.mesh.draw();
    }

    private function drawStuff(notePositions:Array<NotePositionData>)
    {
        for (noteData in notePositions)
        {
            if (noteData.isStrum) //draw strum
                drawStrum(noteData);
            else if (!notes.members[noteData.index].isSustainNote) //draw regular note
                drawNote(noteData);
            else //draw sustain
                drawSustainNote(noteData);

        }
    }

    function sustainSpan(note:Note):Float
    {
        var step:Float = ModchartUtil.getFakeCrochet()/4;
        var parent:Note = note.parent;
        if (parent == null)
            return step;
        var index:Int = parent.tail.indexOf(note);
        if (index < 0)
            return step;
        var end:Float = (index + 1 < parent.tail.length) ? parent.tail[index + 1].strumTime : parent.strumTime + parent.sustainLength;
        var span:Float = end - note.strumTime;
        return (span > 0) ? span : step;
    }

    function getSustainPoint(noteData:NotePositionData, timeOffset:Float):NotePositionData
    {
        var daNote:Note = notes.members[noteData.index];
        var songSpeed:Float = getCorrectScrollSpeed();
        var lane:Int = noteData.lane;
        var pf:Int = noteData.playfieldIndex;

        var noteDist:Float = getNoteDist(noteData.index);
        var curPos:Float = getNoteCurPos(noteData.index, timeOffset);
    
        curPos = modifierTable.applyCurPosMods(lane, curPos, pf);

        if ((daNote.wasGoodHit || (daNote.prevNote.wasGoodHit)) && curPos >= 0)
            curPos = 0;
        noteDist = modifierTable.applyNoteDistMods(noteDist, lane, pf);
        var incomingAngle:Array<Float> = modifierTable.applyIncomingAngleMods(lane, curPos, pf);
        if (noteDist < 0)
            incomingAngle[0] += 180; //make it match for both scrolls
        //get the general note path for the next note
        NoteMovement.setNotePath(daNote, lane, songSpeed, curPos, noteDist, incomingAngle[0], incomingAngle[1]);
        //save the position data 
        var noteData = createDataFromNote(noteData.index, pf, curPos, noteDist, incomingAngle);
        //add offsets to data with modifiers
        modifierTable.applyNoteMods(noteData, lane, curPos, pf);
        var yOffsetThingy = (NoteMovement.arrowSizes[lane]/2);
        var finalNotePos = ModchartUtil.calculatePerspective(new Vector3D(noteData.x+(daNote.width/2)+ModchartUtil.getNoteOffsetX(daNote, instance)+tailShift(lane), noteData.y+(NoteMovement.arrowSizes[noteData.lane]/2), noteData.z*0.001), 
        ModchartUtil.defaultFOV*(Math.PI/180), -(daNote.width/2), yOffsetThingy-(NoteMovement.arrowSizes[noteData.lane]/2));

        noteData.x = finalNotePos.x;
        noteData.y = finalNotePos.y;
        noteData.z = finalNotePos.z;

        return noteData;
    }

    public function getCorrectScrollSpeed()
    {
        if (inEditor)
            return PlayState.SONG.speed; //just use this while in editor so the instance shit works
        else
            return ModchartUtil.getScrollSpeed(playStateInstance);
        return 1.0; 
    }

    override public function destroy()
    {
        if (modchart != null)
        {
            for (customMod in modchart.customModifiers)
            {
                customMod.destroy(); //make sure the interps are dead
            }
        }
        super.destroy();
    }

}