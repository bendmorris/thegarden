import haxe.xml.Fast;
import haxepop.HXP;
import openfl.Assets;


class Species
{
	public static var species:Map<String, Species> = new Map();
	public static var speciesTypes:Map<String, Array<String>> = new Map();
	public static var oldAbundances:Map<String, Float> = new Map();
	public static var abundances:Map<String, Float> = new Map();
	public static var growthRates:Map<String, Float> = new Map();
	public static var speciesOrder:Array<String> = new Array();
	public static var actionTimers:Map<String, Float> = new Map();
	public static var lastExtinction:Float = 0;
	public static var messages:Array<String> = new Array();

	public static var richness(get, never):Int;
	static function get_richness()
	{
		var s = 0;
		for (a in abundances) s += 1;
		return s;
	}

	public static function parseSpecies()
	{
		var _data = Assets.getText("data/species.xml");
		var _xml = Xml.parse(_data);
		var _fast = new Fast(_xml.firstElement());
		for (node in _fast.nodes.species) {
			var thisSpecies = new Species();

			thisSpecies.name = node.att.name;
			thisSpecies.types = node.att.type.split(' ');
			for (type in thisSpecies.types.concat([node.att.type, thisSpecies.name]))
			{
				if (!speciesTypes.exists(type)) speciesTypes[type] = new Array();
				if (speciesTypes[type].indexOf(thisSpecies.name) == -1) speciesTypes[type].push(thisSpecies.name);
			}
			thisSpecies.time = Std.parseFloat(node.att.time);
			thisSpecies.start = Std.parseFloat(node.att.start);
			thisSpecies.goal = Std.parseFloat(node.att.goal);
			if (node.has.value)
				thisSpecies.value = Std.parseFloat(node.att.value);
			if (node.has.limit)
				thisSpecies.limit = Std.parseFloat(node.att.limit);
			if (node.has.growth && node.att.growth == 'linear')
				thisSpecies.linearGrowth = true;
			if (node.has.article)
				thisSpecies.article = node.att.article;

			for (cost in node.nodes.cost)
			{
				thisSpecies.costs.push({type: cost.att.type, value: Std.parseFloat(cost.att.value)});
			}

			for (action in node.nodes.action)
			{
				var actionCost:Cost = null;
				if (action.has.cost)
				{
					var actionCostParts = action.att.cost.split(':');
					actionCost = {type: actionCostParts[0], value: Std.parseFloat(actionCostParts[1])};
				}
				thisSpecies.actions.push({name:
					action.att.name,
					effect: action.att.effect,
					cost: actionCost,
					time: Std.parseFloat(action.att.time),
				});
			}

			species[thisSpecies.name] = thisSpecies;
			speciesOrder.push(thisSpecies.name);
		}
	}

	public static function update()
	{
		lastExtinction = Math.max(0, lastExtinction - HXP.elapsed);

		if (Species.lastExtinction <= 0)
		{
			for (sp in Species.speciesOrder)
			{
				var species = Species.species[sp];
				if (Species.abundances.exists(sp) && Species.abundances[sp] < species.goal)
					break;
				else if (!Species.abundances.exists(sp))
				{
					Species.abundances[sp] = species.start;
					lastExtinction = 15;
					messages.push(species.article + " " + sp + (species.types.indexOf("plant") > -1 ? " grew." : " appeared."));
					break;
				}
			}
		}

		for (speciesName in abundances.keys()) oldAbundances[speciesName] = abundances[speciesName];

		for (speciesName in abundances.keys()) species[speciesName].grow();

		for (speciesName in abundances.keys())
		{
			growthRates[speciesName] =
				20 * (abundances[speciesName] - oldAbundances[speciesName]) / HXP.elapsed / oldAbundances[speciesName];

			if (abundances[speciesName] < 0.5 && speciesName != "money")
			{
				abundances.remove(speciesName);
				messages.push("The " + speciesName + " went extinct.");
				lastExtinction = 15;
			}
		}

		for (actionName in actionTimers.keys())
		{
			actionTimers[actionName] -= HXP.elapsed;
			if (actionTimers[actionName] <= 0) actionTimers.remove(actionName);
		}
	}

	public var description(get, never):String;
	function get_description()
	{
		var eatString = [for (cost in costs) cost.type].join(", ");
		var desc = name;
		if (name != "money")
		{
			desc += " [" + types.join(' ') + "]";
			if (eatString.length > 0) desc += "\nEATS: " + eatString;
		}
		return desc;
	}

	function new()
	{
		types = new Array();
		costs = new Array();
		actions = new Array();
	}

	public function grow()
	{
		var abundance:Float = abundances[name];
		var desiredGrowth:Float = linearGrowth ? 100 : abundances[name];
		var growth = desiredGrowth;
		var limit = this.limit * (1 + 0.01 * richness);

		for (cost in costs)
		{
			var options = cost.type.split('|');
			var typedSpecies = [
				for (x in Lambda.fold(options, function(a:String, b:Array<String>) { return b.concat(speciesTypes[a]); }, []))
				if (abundances.exists(x)) x];

			var needed = desiredGrowth * cost.value;
			var totalAmt:Float = 0;
			for (sp in typedSpecies)
			{
				totalAmt += species[sp].value * abundances[sp];
			}
			if (totalAmt < needed)
			{
				growth -= desiredGrowth * 2 * (needed - totalAmt) / needed;
				if (totalAmt == 0)
				{
					growth = -limit / 10 * time;
					break;
				}
			}
			for (sp in typedSpecies)
			{
				abundances[sp] -= needed * species[sp].value * abundances[sp] / totalAmt * HXP.elapsed / time;
			}
		}

		if (growth > 0) growth *= (1 - (abundance / limit));

		abundances[name] += growth * HXP.elapsed / time;
	}

	public function performAction(action:Action)
	{
		var effect = action.effect;
		var percent = false;
		if (effect.indexOf("%") > -1)
		{
			percent = true;
			effect = StringTools.replace(effect, "%", "");
		}
		var amt = Std.parseFloat(effect);
		if (percent)
		{
			amt = Math.round(abundances[name] * amt / 100);
			if (Math.abs(amt) < 1) amt = amt < 0 ? -1 : 1;
		}
		abundances[name] += amt;
	}

	public var name:String;
	public var types:Array<String>;
	public var costs:Array<Cost>;
	public var actions:Array<Action>;
	public var value:Float = 1;
	public var time:Float = 0;
	public var limit:Float = 1000;
	public var linearGrowth:Bool = false;
	public var start:Float = 0;
	public var goal:Float = 0;
	public var article:String = "a";
}
