import haxepop.HXP;
import haxepop.Entity;
import haxepop.graphics.BitmapText;
import haxepop.graphics.Image;
import haxepop.utils.Math;
import haxepop.Graphic;
import haxepop.input.Mouse;


class Control extends Entity
{
	public static inline var FONT:String="font/bebas_neue.fnt";
	public static var FONT_OPTIONS={font:FONT, size:12, color:0x000000};

	public var speciesName:String;
	public var img:Image;
	public var label:BitmapText;
	public var countLabel:BitmapText;
	public var actionButtons:Array<BitmapText>;
	public var actionAlphas:Array<Float>;
	public var meter:Image;

	public var alpha(default, set):Float = 0;
	function set_alpha(v:Float)
	{
		for (n in 0 ... actionButtons.length) actionButtons[n].alpha = actionAlphas[n] * v;
		if (img != null) img.alpha = v;
		return meter.alpha = label.alpha = countLabel.alpha = alpha = v;
	}

	public function new(speciesName:String)
	{
		super();

		this.speciesName = speciesName;

		if (speciesName != "money" && speciesName != "human" && speciesName != "monster")
		{
			img = new Image("graphics/" + speciesName + ".png");
			img.scale = 0.25;
			addGraphic(img);
		}

		label = new BitmapText(speciesName, 48, -6, 0, 0, FONT_OPTIONS);
		countLabel = new BitmapText("0", 200, -6, 0, 0, FONT_OPTIONS);
		label.smooth = countLabel.smooth = true;
		addGraphic(label);
		addGraphic(countLabel);

		//meter
		meter = Image.createRect(48, Std.int(label.textHeight/2));
		meter.x = 208;
		meter.y = meter.height/2;
		addGraphic(meter);

		actionButtons = new Array();
		actionAlphas = new Array();
		for (action in Species.species[speciesName].actions)
		{
			var actionLabel = new BitmapText(action.name, 0, -6, 0, 0, FONT_OPTIONS);
			actionLabel.computeTextSize();
			actionLabel.x = 260 + Lambda.fold(actionButtons, function(x, y) { return x.textWidth + y + 32; }, 0);
			actionLabel.color = (action.effect.indexOf("-") > -1 ? 0xFF0000 : 0x008020);
			actionLabel.alpha = 0;
			addGraphic(actionLabel);
			actionButtons.push(actionLabel);
			actionAlphas.push(0);
		}

		collidable = true;
		type = "control";
		width = actionButtons.length == 0
			? 260
			: Std.int(actionButtons[actionButtons.length - 1].x + actionButtons[actionButtons.length - 1].textWidth);
		height = label.textHeight;
	}

	override public function update()
	{
		countLabel.text = Species.abundances.exists(speciesName)
			? ((speciesName == "money" ? "$" : "") + Std.int(Math.round(Species.abundances[speciesName])))
			: "0";
		countLabel.x = 200 - countLabel.textWidth;
		var c:Int = 0;
		if (speciesName == "money") c = 0x202020;
		else if (Species.abundances.exists(speciesName))
		{
			var growth = Species.growthRates.exists(speciesName) ? Species.growthRates[speciesName] : 0;
			var val:Int = Std.int(Math.clamp(Math.abs(growth) * 255, 0, 127)) + 128;
			var r:Int=0, g:Int=0, b:Int=0;
			if (growth < 0)
			{
				r = val;
			}
			else
			{
				g = Std.int(val*3/4);
				b = Std.int(val/4);
			}
			c = (r << 16) | (g << 8) | b;
		}

		label.color = countLabel.color = meter.color = c;

		if (speciesName != "money")
		{
			meter.scaleX = Math.clamp(
				(Species.abundances.exists(speciesName) ? Species.abundances[speciesName] : 0) /
				Species.species[speciesName].limit + (0.01 * Species.richness),
				0, 1);
		} else meter.visible = false;

		var n = 0;
		for (action in Species.species[speciesName].actions)
		{
			var visible = !Species.actionTimers.exists(action.name);
			if (visible) actionAlphas[n] = Math.min(1, actionAlphas[n] + HXP.elapsed);
			else actionAlphas[n] = Math.max(0, actionAlphas[n] - HXP.elapsed);
			this.alpha *= 1;
			n++;
		}

		super.update();
	}

	public function payCost(cost:Cost)
	{
		var typedSpecies = [for (sp in Species.speciesTypes[cost.type]) if (Species.abundances.exists(sp)) sp];
		var total:Float = 0;
		for (sp in typedSpecies)
		{
			total += Species.abundances[sp] * Species.species[sp].value;
		}
		if (total < cost.value) return false;
		for (sp in typedSpecies)
		{
			Species.abundances[sp] -= cost.value / typedSpecies.length / Species.species[sp].value;
		}
		return true;
	}

	public function performAction(action:Action)
	{
		if (action.cost != null && !payCost(action.cost)) return false;

		Species.species[speciesName].performAction(action);
		Species.actionTimers[action.name] = action.time;

		return true;
	}
}