import haxepop.HXP;
import haxepop.Entity;
import haxepop.EntityList;
import haxepop.Scene;
import haxepop.Input;
import haxepop.graphics.BitmapText;
import haxepop.input.Mouse;


class MainScene extends Scene
{
	public var controls:Map<String, Control>;
	public var mouseOverLabel:BitmapText;
	public var messageLabel:BitmapText;
	public var messageFade:Float = 0;

	public function new()
	{
		super();
		controls = new Map();
		Species.abundances = [
			"money" => 100,
		];
		Species.actionTimers = ["payday" => 30, "cut" => 30, "pesticide" => 60];
		Species.lastExtinction = 4;
	}

	public override function begin()
	{
		HXP.stage.color = 0xFFFFFF;
		for (sp in Species.speciesOrder)
		{
			controls[sp] = new Control(sp);
			controls[sp].visible = false;
			controls[sp].x = 48;
			add(controls[sp]);
		}

		mouseOverLabel = new BitmapText(" ", 48, 8, 0, 0, Control.FONT_OPTIONS);
		mouseOverLabel.alpha = 0;
		mouseOverLabel.color = 0x808080;
		addGraphic(mouseOverLabel);

		messageLabel = new BitmapText(" ", 48, 440, 0, 0, Control.FONT_OPTIONS);
		messageLabel.alpha = 0;
		messageLabel.color = 0x808080;
		addGraphic(messageLabel);
	}

	override public function update()
	{
		Species.update();

		var n = 0;
		for (sp in Species.speciesOrder)
		{
			var control = controls[sp];
			if (control != null)
			{
				var visible = Species.abundances.exists(sp);
				if (visible)
				{
					control.visible = true;
					if (control.alpha < 1) control.alpha = Math.min(1, control.alpha + HXP.elapsed);
					var targetY = 72 + n*(control.label.textHeight-2);
					var move = HXP.elapsed * (36 + Math.abs(control.y - targetY)) * (control.y > targetY ? -1 : 1);
					if (Math.abs(move) > Math.abs(targetY - control.y))
						move = targetY - control.y;
					if (Math.abs(control.y - targetY) < 1) control.y = targetY;
					else control.y += move;
					n += 1;
				}
				else
				{
					if (control.alpha > 0) control.alpha = Math.max(0, control.alpha - HXP.elapsed);
					if (control.alpha <= 0)
					{
						control.visible = false;
						control.y = 0;
					}
				}
			}
		}

		var mx = Mouse.mouseX, my = Mouse.mouseY;
		var control:Control = cast collidePoint("control", mx, my);
		if (control != null && Species.abundances.exists(control.speciesName))
		{
			var overButton = false;
			if (control.speciesName == "money") mouseOverLabel.alpha = Math.max(0, mouseOverLabel.alpha - HXP.elapsed);
			else mouseOverLabel.alpha = Math.min(1, mouseOverLabel.alpha + HXP.elapsed);

			for (n in 0 ... control.actionButtons.length)
			{
				if (Species.actionTimers.exists(Species.species[control.speciesName].actions[n].name)) continue;

				var btn = control.actionButtons[n];
				var bx:Float = btn.x + control.x;

				if (mx > bx && mx < bx + btn.textWidth)
				{
					var action = Species.species[control.speciesName].actions[n];
					overButton = true;
					if (control.speciesName != "money")
					{
						var actionText = action.name + ":\n  " + control.speciesName + " " + action.effect;
						if (action.cost != null)
						{
							if (action.cost.type == "money") actionText += " ($" + action.cost.value + ")";
							else actionText += " (" + action.cost.value + " " + action.cost.type + ")";
						}
						mouseOverLabel.text = actionText;
					}

					if (Mouse.mousePressed && control.performAction(action))
					{
						control.actionAlphas[n] -= 0.25;
					}
					break;
				}
			}
			HXP.engine.useHandCursor = HXP.engine.buttonMode = overButton;
			if (!overButton && control.speciesName != "money") mouseOverLabel.text = Species.species[control.speciesName].description;
		}
		else
		{
			HXP.engine.useHandCursor = HXP.engine.buttonMode = false;
			mouseOverLabel.alpha = Math.max(0, mouseOverLabel.alpha - HXP.elapsed);
		}

		if (Species.messages.length > 0)
		{
			messageLabel.text = Species.messages.pop();
			while (Species.messages.length > 0) Species.messages.pop();
			messageFade = 5;
		}
		messageFade = Math.max(0, messageFade - HXP.elapsed);
		messageLabel.alpha = Math.min(messageLabel.alpha + HXP.elapsed, messageFade > 1 ? 1 : messageFade);

		super.update();
	}

}
