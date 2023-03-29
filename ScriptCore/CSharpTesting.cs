using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using GlitchyEngine.Math;

namespace GlitchyEngine;

public class CSharpTesting
{
    public float MyPublicFloatVar = 5.0f;
    
	public CSharpTesting()
	{
		Console.WriteLine("Hallo von C#!");
        DoSomething();
        Console.WriteLine(Sample());

        Vector3 a = new Vector3(1, 2, 3);
        Vector3 b = new Vector3(3, 2, 1);

        Vector3 result;
        //Vector3.Add_Internal(a, b, out result);

        //Console.WriteLine(result);
    }
    
    [DllImport ("__Internal", EntryPoint="DoSomething")]
    static extern void DoSomething();

    [MethodImpl(MethodImplOptions.InternalCall)]
    static extern string Sample();

    public void PrintFloatVar()
    {
        Console.WriteLine("MyPublicFloatVar = {0:F}", MyPublicFloatVar);
    }

    private float IncrementFloatVar(float value)
    {
        MyPublicFloatVar += value;

        return MyPublicFloatVar;
    }
}
