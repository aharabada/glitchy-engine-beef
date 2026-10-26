using System;
using System.IO;
using System.Runtime.InteropServices;

namespace MarshallingBench;

internal static class Native
{
    public const string LibraryName = "BeefDemoLib";

    private static bool _initialized;

    /// <summary>
    /// Loads the Beef DLL and hands the function pointers to both call classes.
    /// </summary>
    public static void Init()
    {
        if (_initialized)
            return;

        string path = Path.Combine(AppContext.BaseDirectory, LibraryName + ".dll");

        if (!File.Exists(path))
            throw new FileNotFoundException("Beef DLL not found. Build it first (run.ps1).", path);

        nint library = NativeLibrary.Load(path);

        MarshalledCalls.Init(library);
        UnmarshalledCalls.Init(library);

        _initialized = true;
    }
}
