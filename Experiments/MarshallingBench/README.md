# MarshallingBench

Measures what a CoreCLR marshalling stub costs when C# calls a Beef function through a `delegate* unmanaged`
(the mechanism `ScriptCore`'s generated `EngineFunctions` uses), compared to a stub-free "inlined" call.

Standalone experiment. Not part of the engine's `BeefSpace.toml` and not built by `BuildTool`.

## Background

A `delegate* unmanaged` call is only stub-free if the whole signature is blittable. With runtime marshalling enabled (the default)
the CLR generates an `IL_STUB_PInvoke` as soon as the signature contains

- `bool` (marshalled as 4-byte Win32 `BOOL`) or `char` (1-byte ANSI), or
- `in` / `ref` / `out` (the stub pins the byref for the duration of the call).

The `bool` case is not just slower but **wrong** against Beef: Beef returns a `bool` in `al` only, the stub tests all of `eax`.
The sanity check at startup shows exactly that for variant #2 (`IsGreater(1, 2)` comes back `True`).

`[assembly: DisableRuntimeMarshalling]` removes all stubs for an assembly, but then `in`/`ref`/`out` throw
`MarshalDirectiveException` at runtime, so those signatures have to use raw pointers instead.

## Layout

| Path | What |
| --- | --- |
| `BeefDemoLib/` | Beef DLL (`TargetType = "BeefLib"` + `BuildKind = "DynamicLib"`) exporting four trivial Cdecl functions |
| `Bench/` | C# exe, runtime marshalling **enabled**, BenchmarkDotNet harness, fnptr + DllImport variants |
| `Bench.NoMarshalling/` | C# lib with `[assembly: DisableRuntimeMarshalling]`, the same calls without marshalling |

Every variant sits behind a `[MethodImpl(NoInlining)]` wrapper in both assemblies, so all measurements pay for the same one extra managed call
(which is also what the generated `ScriptGlue.X(...)` wrappers look like).

## Running

```powershell
./run.ps1                      # build Beef DLL + C#, run all benchmarks (~4 min)
./run.ps1 -Stubs               # no benchmark: list which variants get an IL stub
./run.ps1 --filter *Scale*     # arguments are passed through to BenchmarkDotNet
./run.ps1 -BeefBuild D:\Development\Git\Beef\IDE\dist\BeefBuild.exe
```

## Results

Ryzen 7 9800X3D, Windows 11, .NET 10.0.12, Beef 0.43.6 (Release, O2), BenchmarkDotNet 0.15.8 default job.

| # | Variant | Stub | Mean | Ratio |
| --- | --- | --- | ---: | ---: |
| 1 | fnptr `<int,int,int>` | no | 2.26 ns | 1.00 |
| 2 | fnptr `<int,int,bool>` | **yes** | 3.06 ns | 1.35 |
| 3 | fnptr `<int,int,byte>` + `!= 0` | no | 2.22 ns | 0.98 |
| 4 | fnptr `<int,int,bool>`, `DisableRuntimeMarshalling` | no | 2.29 ns | 1.01 |
| 5 | `DllImport` int | no | 2.38 ns | 1.05 |
| 6 | `DllImport` bool (`U1`) | **yes** | 2.95 ns | 1.30 |
| 7 | fnptr `SuppressGCTransition` | no | 0.99 ns | 0.44 |
| | | | | |
| 8 | fnptr `<in Vec3, float, out Vec3>` | **yes** | 4.44 ns | 1.33 |
| 9 | fnptr `<Vec3*, float, Vec3*>` + `fixed` | no | 3.35 ns | 1.00 |
| 10 | like #9, `DisableRuntimeMarshalling` | no | 3.30 ns | 0.99 |
| 11 | `DllImport` in/out | **yes** | 4.10 ns | 1.22 |

Reading it:

- A marshalling stub costs roughly **0.8 - 1.1 ns per call** (~30 %) on this machine. Measurable, but tiny in absolute terms:
  10 000 glue calls per frame add about 0.01 ms.
- Function pointers and `DllImport` are equivalent. Both are stub-free when blittable, both get a stub otherwise.
- `byte` instead of `bool` (#3) is exactly as fast as disabling marshalling (#4) - there is no performance reason for the assembly attribute.
  Its value would be turning accidental non-blittable signatures into a loud error instead of silent misbehaviour.
- Raw pointers + `fixed` (#9) recover the full stub cost for in/out signatures, with or without the attribute (#10).
- The dominant cost of any of these calls is the GC transition itself (#7 vs #1), not the marshalling.
  `SuppressGCTransition` is only legal for trivial, non-blocking callees that never call back into managed code.
