package funkin.ui.psychui;

import funkin.ui.psychui.PsychUIBox.UIStyleData;
import flixel.util.FlxSpriteUtil;

class PsychUIButton extends FlxSpriteGroup
{
	public static final CLICK_EVENT = 'button_click';

	public var name:String;
	public var label(default, set):String;
	public var bg:FlxSprite;
	public var text:FlxText;

	public var onChangeState:String->Void;
	public var onClick:Void->Void;
	
	public var clickStyle:UIStyleData = {
		bgColor: FlxColor.BLACK,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var hoverStyle:UIStyleData = {
		bgColor: FlxColor.WHITE,
		textColor: FlxColor.BLACK,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: 0xFFAAAAAA,
		textColor: FlxColor.BLACK,
		bgAlpha: 1
	};

	public function new(x:Float = 0, y:Float = 0, label:String = '', ?onClick:Void->Void = null, ?wid:Int = 80, ?hei:Int = 20)
	{
		super(x, y);

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		bg.color = 0xFFAAAAAA;
		bg.alpha = 0.6;
		add(bg);

		text = new FlxText(0, 0, 1, '');
		text.alignment = CENTER;
		add(text);
		resize(wid, hei);
		this.label = label;
		
		this.onClick = onClick;
		forceCheckNext = true;
	}

	public var isClicked:Bool = false;
	public var forceCheckNext:Bool = false;
	public var broadcastButtonEvent:Bool = true;
	var _firstFrame:Bool = true;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(_firstFrame)
		{
			bg.color = normalStyle.bgColor;
			bg.alpha = normalStyle.bgAlpha;
			text.color = normalStyle.textColor;
			_firstFrame = false;
		}
		
		if(isClicked && FlxG.mouse.released)
		{
			forceCheckNext = true;
			isClicked = false;
		}

		if(forceCheckNext || FlxG.mouse.justMoved || FlxG.mouse.justPressed)
		{
			var overlapped:Bool = (FlxG.mouse.overlaps(bg, camera));

			forceCheckNext = false;

			if(!isClicked)
			{
				var style:UIStyleData = (overlapped) ? hoverStyle : normalStyle;
				bg.color = style.bgColor;
				bg.alpha = style.bgAlpha;
				text.color = style.textColor;
			}

			if(overlapped && FlxG.mouse.justPressed)
			{
				isClicked = true;
				bg.color = clickStyle.bgColor;
				bg.alpha = clickStyle.bgAlpha;
				text.color = clickStyle.textColor;
				if(onClick != null) onClick();
				if(broadcastButtonEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
			}
		}
	}

	public function resize(width:Int, height:Int)
	{
		bg.setGraphicSize(width, height);
		bg.updateHitbox();
		
		text.fieldWidth = width;
		text.x = bg.x;
		text.y = bg.y + height/2 - text.height/2;
	}

	function _redrawBtn(width:Int, height:Int, bgColor:FlxColor)
	{
		bg.makeGraphic(width, height + 3, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(bg, 0, 3, width, height, 50, 50, bgColor, {thickness: 2, color: 0xFFE8A800});
		FlxSpriteUtil.drawRoundRect(bg, 0, 0, width, height, 50, 50, bgColor, {thickness: 0, color: FlxColor.TRANSPARENT});
		FlxSpriteUtil.drawLine(bg, 4, height + 1, width - 4, height + 1, {thickness: 3, color: 0xFFC78A00});
		bg.updateHitbox();
	}

	function set_label(v:String)
	{
		if(text != null && text.exists) text.text = v;
		return (label = v);
	}
}
