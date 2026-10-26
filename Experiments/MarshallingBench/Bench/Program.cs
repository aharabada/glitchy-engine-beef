using System;
using System.Linq;
using BenchmarkDotNet.Running;

namespace MarshallingBench;

internal static class Program
{
    private static int Main(string[] args)
    {
        Native.Init();

        bool ok = SanityCheck();

        // --stubs: call everything once and exit.
        // Meant to be run with DOTNET_JitDisasmSummary=1 to see which calls get an IL stub (see run.ps1 -Stubs).
        if (args.Contains("--stubs"))
            return ok ? 0 : 1;

        if (!ok)
        {
            Console.Error.WriteLine("Sanity check failed, not running benchmarks.");
            return 1;
        }

        BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args.Length > 0 ? args : ["--filter", "*"]);
        return 0;
    }

    private static bool SanityCheck()
    {
        bool ok = true;
        Vec3 v = new(1, 2, 3);

        void Check<T>(string name, T actual, T expected, bool mayBeWrong = false)
        {
            bool equal = Equals(actual, expected);
            string state = equal ? "ok" : (mayBeWrong ? "WRONG (expected, this is the bool marshalling bug)" : "FAILED");
            Console.WriteLine($"  {name,-48} = {actual,-10} expected {expected,-10} {state}");

            if (!equal && !mayBeWrong)
                ok = false;
        }

        Console.WriteLine("Sanity check:");
        Check("#1  AddInt(3, 2)", MarshalledCalls.AddInt(3, 2), 5);
        Check("#2  IsGreater_Bool(1, 2)  [stub, 4-byte BOOL]", MarshalledCalls.IsGreater_Bool(1, 2), false, mayBeWrong: true);
        Check("#2  IsGreater_Bool(2, 1)  [stub, 4-byte BOOL]", MarshalledCalls.IsGreater_Bool(2, 1), true, mayBeWrong: true);
        Check("#3  IsGreater_Byte(1, 2)", MarshalledCalls.IsGreater_Byte(1, 2), false);
        Check("#3  IsGreater_Byte(2, 1)", MarshalledCalls.IsGreater_Byte(2, 1), true);
        Check("#4  IsGreater_Bool(1, 2)  [no marshalling]", UnmarshalledCalls.IsGreater_Bool(1, 2), false);
        Check("#4  IsGreater_Bool(2, 1)  [no marshalling]", UnmarshalledCalls.IsGreater_Bool(2, 1), true);
        Check("#5  AddInt_DllImport(3, 2)", MarshalledCalls.AddInt_DllImport(3, 2), 5);
        Check("#6  IsGreater_DllImport(1, 2)", MarshalledCalls.IsGreater_DllImport(1, 2), false);
        Check("#6  IsGreater_DllImport(2, 1)", MarshalledCalls.IsGreater_DllImport(2, 1), true);
        Check("#7  AddInt_SuppressGCTransition(3, 2)", MarshalledCalls.AddInt_SuppressGCTransition(3, 2), 5);

        MarshalledCalls.Scale_ByRef(in v, 2, out Vec3 r8);
        Check("#8  Scale_ByRef((1,2,3), 2)", r8.ToString(), "(2, 4, 6)");
        MarshalledCalls.Scale_Pointer(in v, 2, out Vec3 r9);
        Check("#9  Scale_Pointer((1,2,3), 2)", r9.ToString(), "(2, 4, 6)");
        UnmarshalledCalls.Scale_Pointer(in v, 2, out Vec3 r10);
        Check("#10 Scale_Pointer((1,2,3), 2)  [no marshalling]", r10.ToString(), "(2, 4, 6)");
        MarshalledCalls.Scale_DllImport(in v, 2, out Vec3 r11);
        Check("#11 Scale_DllImport((1,2,3), 2)", r11.ToString(), "(2, 4, 6)");
        Console.WriteLine();

        return ok;
    }
}
