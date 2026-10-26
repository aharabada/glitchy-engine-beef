using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

// Applies to every P/Invoke and unmanaged function pointer call in THIS assembly:
// bool is passed as 1 byte, no IL stubs are generated - and in/ref/out are not allowed anymore.
[assembly: DisableRuntimeMarshalling]

namespace MarshallingBench;

/// <summary>
/// Call variants compiled with runtime marshalling disabled.
/// </summary>
public static unsafe class UnmarshalledCalls
{
    // Non-readonly on purpose: mirrors ScriptGlue._engineFunctions and keeps the JIT from folding the target into a constant.
    private static delegate* unmanaged[Cdecl]<int, int, bool> _isGreaterBool;
    private static delegate* unmanaged[Cdecl]<Vec3*, float, Vec3*, void> _scalePtr;

    public static void Init(nint library)
    {
        _isGreaterBool = (delegate* unmanaged[Cdecl]<int, int, bool>)NativeLibrary.GetExport(library, "Bench_IsGreater");
        _scalePtr = (delegate* unmanaged[Cdecl]<Vec3*, float, Vec3*, void>)NativeLibrary.GetExport(library, "Bench_Scale");
    }

    /// <summary>#4: bool return, no marshalling because of the assembly attribute.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static bool IsGreater_Bool(int a, int b) => _isGreaterBool(a, b);

    /// <summary>#10: raw pointers, the wrapper keeps the in/out API and pins manually.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static void Scale_Pointer(in Vec3 v, float s, out Vec3 result)
    {
        fixed (Vec3* pv = &v)
        fixed (Vec3* pr = &result)
        {
            _scalePtr(pv, s, pr);
        }
    }
}
