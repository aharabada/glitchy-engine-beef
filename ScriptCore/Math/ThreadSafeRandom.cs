using System;

namespace GlitchyEngine.Math;

/// <summary>
/// A thread safe global random number generator.
/// </summary>
/// <remarks>
/// Based on https://andrewlock.net/building-a-thread-safe-random-implementation-for-dotnet-framework/
/// </remarks>
public static class ThreadSafeRandom
{
    [ThreadStatic]
    private static Random? _local;
    private static readonly Random Global = new();

    /// <summary>
    /// Gets a thread safe random number generator.
    /// </summary>
    public static Random Instance
    {
        get
        {
            if (_local is null)
            {
                int seed;
                lock (Global)
                {
                    seed = Global.Next();
                }

                _local = new Random(seed);
            }

            return _local;
        }
    }
}
