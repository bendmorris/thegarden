import haxepop.Engine;
import haxepop.HXP;


class Main extends Engine
{

	public function new(width:Float = 0, height:Float = 0, frameRate:Float = 30, fixed:Bool = true)
	{
		super(640, 480, 30, true);
	}

	override public function init()
	{
#if debug
		HXP.console.enable();
#end
		HXP.scene = new MainScene();
	}

	public static function main()
	{
		Species.parseSpecies();
		HXP.autoPause = false;
		new Main();
	}

}
