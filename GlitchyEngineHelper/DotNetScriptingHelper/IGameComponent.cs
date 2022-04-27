namespace DotNetScriptingHelper;

public interface IGameComponent
{
    static int I { get; }
}

public class GameComponentAttribute : Attribute
{
    public GameComponentAttribute()
    {

    }
}
