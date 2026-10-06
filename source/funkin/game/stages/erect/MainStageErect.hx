package funkin.game.stages.erect;

import funkin.game.Character;
import funkin.game.notes.Note;
import funkin.game.notes.Note.EventNote;
import funkin.game.states.GameOverSubstate;
import funkin.game.stages.objects.*;
import funkin.graphics.shaders.AdjustColorShader;
import funkin.graphics.shaders.DropShadowShader;
import funkin.graphics.shaders.DropShadowScreenspace;
import funkin.graphics.shaders.RainShader;
import funkin.graphics.shaders.WiggleEffectRuntime;
import openfl.display.BlendMode;

class MainStageErect extends BaseStage {

	var peeps:BGSprite;
	override function create()
	{
        new StageSpotlight(200,-50);
		var bg:FlxSprite = makeSolid(-500,-1000, 2400, 2000, 0xFF222026);
		add(bg);

        if(!ClientPrefs.data.lowQuality) {
            peeps = new BGSprite('erect/crowd', 682, 290,0.8,0.8,["idle"],true);
            peeps.animation.curAnim.frameRate = 12;
            add(peeps);

            var lightSmol = new BGSprite('erect/brightLightSmall',967, -103,1.2,1.2);
            lightSmol.blend = BlendMode.ADD;
            add(lightSmol);
        }

		var stageFront:BGSprite = new BGSprite('erect/bg', -765, -247);
		add(stageFront);

        var server:BGSprite = new BGSprite('erect/server', -991, 205);
		add(server);

		if(!ClientPrefs.data.lowQuality) {
			var greenLight:BGSprite = new BGSprite('erect/lightgreen', -171, 242);
            greenLight.blend = BlendMode.ADD;
			add(greenLight);

            var redLight:BGSprite = new BGSprite('erect/lightred', -101, 560);
            redLight.blend = BlendMode.ADD;
			add(redLight);

            var orangeLight:BGSprite = new BGSprite('erect/orangeLight', 189, -500);
            orangeLight.blend = BlendMode.ADD;
			add(orangeLight);
		}

        var beamLol:BGSprite = new BGSprite('erect/lights', -847, -245,1.2,1.2);
		add(beamLol);

        if(!ClientPrefs.data.lowQuality) {
			var TheOneAbove:BGSprite = new BGSprite('erect/lightAbove', 804, -117);
            TheOneAbove.blend = BlendMode.ADD;
			add(TheOneAbove);
        }
	}

    override function createPost() {
        super.createPost();
        if(ClientPrefs.data.shaders){
            gf.shader = makeCoolShader(-9,0,-30,-4);
            dad.shader = makeCoolShader(-32,0,-33,-23);
            boyfriend.shader = makeCoolShader(12,0,-23,7);
            PicoCapableStage.instance?.applyABotShader(makeCoolShader(-9,0,-30,-4));
        }
    }

    function makeCoolShader(hue:Float,sat:Float,bright:Float,contrast:Float) {
        var coolShader = new AdjustColorShader();
        coolShader.hue = hue;
        coolShader.saturation = sat;
        coolShader.brightness = bright;
        coolShader.contrast = contrast;
        return coolShader;
    }
}
