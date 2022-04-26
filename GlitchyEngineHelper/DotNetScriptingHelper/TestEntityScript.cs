using System.Diagnostics;

namespace DotNetScriptingHelper;

public class TestEntityScript : ScriptableEntity
{
    public int Inty = 1337;

    protected override void OnUpdate()
    {
        Debug.WriteLine($"My Number is {Inty++}");
    }
}
