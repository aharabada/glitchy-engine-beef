using GlitchyEngine;
using GlitchyEngine.Math;
using System;
using System.Runtime.InteropServices;
using static GlitchyEngine.Math.Math;

namespace TestProject;

public class TestScript : Entity
{
    /// <summary>
	/// OnCreate is called once before the first call to OnUpdate.
	/// </summary>
	protected override void OnCreate()
    {
    }

    /// <summary>
    /// OnUpdate is called once every frame.
    /// </summary>
    protected override void OnUpdate(float deltaTime)
    {
    }
}

public static class Test
{
    [UnmanagedCallersOnly]
    public static void TestFunc()
    {

    }
}
