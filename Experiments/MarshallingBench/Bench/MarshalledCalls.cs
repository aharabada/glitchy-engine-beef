using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace MarshallingBench;

/// <summary>
/// Call variants compiled with runtime marshalling ENABLED (the default, and what ScriptCore uses).
/// Whether a call gets an IL stub depends only on its signature.
/// </summary>
public static unsafe class MarshalledCalls
{
    // Non-readonly on purpose: mirrors ScriptGlue._engineFunctions and keeps the JIT from folding the target into a constant.
    private static delegate* unmanaged[Cdecl]<int, int, int> _addInt;
    private static delegate* unmanaged[Cdecl, SuppressGCTransition]<int, int, int> _addIntNoGcTransition;
    private static delegate* unmanaged[Cdecl]<int, int, bool> _isGreaterBool;
    private static delegate* unmanaged[Cdecl]<int, int, byte> _isGreaterByte;
    private static delegate* unmanaged[Cdecl]<in Vec3, float, out Vec3, void> _scaleByRef;
    private static delegate* unmanaged[Cdecl]<Vec3*, float, Vec3*, void> _scalePtr;

    public static void Init(nint library)
    {
        nint addInt = NativeLibrary.GetExport(library, "Bench_AddInt");
        nint isGreater = NativeLibrary.GetExport(library, "Bench_IsGreater");
        nint scale = NativeLibrary.GetExport(library, "Bench_Scale");

        _addInt = (delegate* unmanaged[Cdecl]<int, int, int>)addInt;
        _addIntNoGcTransition = (delegate* unmanaged[Cdecl, SuppressGCTransition]<int, int, int>)addInt;
        _isGreaterBool = (delegate* unmanaged[Cdecl]<int, int, bool>)isGreater;
        _isGreaterByte = (delegate* unmanaged[Cdecl]<int, int, byte>)isGreater;
        _scaleByRef = (delegate* unmanaged[Cdecl]<in Vec3, float, out Vec3, void>)scale;
        _scalePtr = (delegate* unmanaged[Cdecl]<Vec3*, float, Vec3*, void>)scale;
    }

#region Primitive

    /// <summary>#1: fully blittable, the JIT inlines the transition. Baseline.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static int AddInt(int a, int b) => _addInt(a, b);

    /// <summary>#2: bool is not blittable -> IL stub, marshalled as 4-byte Win32 BOOL. This is the original bug.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static bool IsGreater_Bool(int a, int b) => _isGreaterBool(a, b);

    /// <summary>#3: byte instead of bool -> blittable again. This is the current generator fix.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static bool IsGreater_Byte(int a, int b) => _isGreaterByte(a, b) != 0;

    /// <summary>#5: classic P/Invoke, blittable.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static int AddInt_DllImport(int a, int b) => PInvoke_AddInt(a, b);

    /// <summary>#6: classic P/Invoke with a correctly annotated 1-byte bool.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static bool IsGreater_DllImport(int a, int b) => PInvoke_IsGreater(a, b);

    /// <summary>#7: skips the cooperative -> preemptive GC mode switch. Lower bound, only legal for trivial non-blocking callees.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static int AddInt_SuppressGCTransition(int a, int b) => _addIntNoGcTransition(a, b);

#endregion

#region Struct by ref

    /// <summary>#8: in/out need an IL stub that pins the byrefs. This is what the generated ScriptGlue does today.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static void Scale_ByRef(in Vec3 v, float s, out Vec3 result) => _scaleByRef(in v, s, out result);

    /// <summary>#9: raw pointers, the wrapper keeps the in/out API and pins manually. What a reworked generator would emit.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static void Scale_Pointer(in Vec3 v, float s, out Vec3 result)
    {
        fixed (Vec3* pv = &v)
        fixed (Vec3* pr = &result)
        {
            _scalePtr(pv, s, pr);
        }
    }

    /// <summary>#11: classic P/Invoke with in/out.</summary>
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static void Scale_DllImport(in Vec3 v, float s, out Vec3 result) => PInvoke_Scale(in v, s, out result);

#endregion

    [DllImport(Native.LibraryName, EntryPoint = "Bench_AddInt", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
    private static extern int PInvoke_AddInt(int a, int b);

    [DllImport(Native.LibraryName, EntryPoint = "Bench_IsGreater", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.U1)]
    private static extern bool PInvoke_IsGreater(int a, int b);

    [DllImport(Native.LibraryName, EntryPoint = "Bench_Scale", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
    private static extern void PInvoke_Scale(in Vec3 v, float s, out Vec3 result);
}
