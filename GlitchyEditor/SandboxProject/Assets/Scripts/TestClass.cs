using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using GlitchyEngine;

namespace Sandbox;

public static class TestClass
{
    [UnmanagedCallersOnly]
    public static void TestFunction()
    {
        Console.WriteLine("Hello from the second Assembly!");
    }

    public static void InternalTest()
    {
        Console.WriteLine("Ja, ich existiere in der Tat");

        Log.Info("Yeah!");
        //Console.WriteLine("Und nun bin ich anders");
    }

    public static int Test(IntPtr arg, int sizeofArg)
    {
        Console.WriteLine($"YUPPYPLASDPASDOIUZASD");
        return 7;
    }
}
