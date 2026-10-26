using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Configs;

namespace MarshallingBench;

[GroupBenchmarksBy(BenchmarkLogicalGroupRule.ByCategory)]
[CategoriesColumn]
public class Benchmarks
{
    private const string Primitive = "Primitive";
    private const string StructByRef = "StructByRef";

    private int _a = 3;
    private int _b = 2;
    private Vec3 _v = new(1, 2, 3);

    [GlobalSetup]
    public void Setup() => Native.Init();

    [Benchmark(Baseline = true, Description = "#1 fnptr <int,int,int>"), BenchmarkCategory(Primitive)]
    public int AddInt() => MarshalledCalls.AddInt(_a, _b);

    [Benchmark(Description = "#2 fnptr <..,bool> (stub)"), BenchmarkCategory(Primitive)]
    public bool IsGreater_Bool() => MarshalledCalls.IsGreater_Bool(_a, _b);

    [Benchmark(Description = "#3 fnptr <..,byte> != 0"), BenchmarkCategory(Primitive)]
    public bool IsGreater_Byte() => MarshalledCalls.IsGreater_Byte(_a, _b);

    [Benchmark(Description = "#4 fnptr <..,bool> DisableRuntimeMarshalling"), BenchmarkCategory(Primitive)]
    public bool IsGreater_Bool_NoMarshalling() => UnmarshalledCalls.IsGreater_Bool(_a, _b);

    [Benchmark(Description = "#5 DllImport int"), BenchmarkCategory(Primitive)]
    public int AddInt_DllImport() => MarshalledCalls.AddInt_DllImport(_a, _b);

    [Benchmark(Description = "#6 DllImport bool (U1)"), BenchmarkCategory(Primitive)]
    public bool IsGreater_DllImport() => MarshalledCalls.IsGreater_DllImport(_a, _b);

    [Benchmark(Description = "#7 fnptr SuppressGCTransition"), BenchmarkCategory(Primitive)]
    public int AddInt_SuppressGCTransition() => MarshalledCalls.AddInt_SuppressGCTransition(_a, _b);

    [Benchmark(Description = "#8 fnptr <in,float,out> (stub)"), BenchmarkCategory(StructByRef)]
    public float Scale_ByRef()
    {
        MarshalledCalls.Scale_ByRef(in _v, 2.0f, out Vec3 result);
        return result.X;
    }

    [Benchmark(Baseline = true, Description = "#9 fnptr <T*,float,T*> + fixed"), BenchmarkCategory(StructByRef)]
    public float Scale_Pointer()
    {
        MarshalledCalls.Scale_Pointer(in _v, 2.0f, out Vec3 result);
        return result.X;
    }

    [Benchmark(Description = "#10 like #9, DisableRuntimeMarshalling"), BenchmarkCategory(StructByRef)]
    public float Scale_Pointer_NoMarshalling()
    {
        UnmarshalledCalls.Scale_Pointer(in _v, 2.0f, out Vec3 result);
        return result.X;
    }

    [Benchmark(Description = "#11 DllImport in/out"), BenchmarkCategory(StructByRef)]
    public float Scale_DllImport()
    {
        MarshalledCalls.Scale_DllImport(in _v, 2.0f, out Vec3 result);
        return result.X;
    }
}
