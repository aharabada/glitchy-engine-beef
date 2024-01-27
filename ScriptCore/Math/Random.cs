using System;

namespace GlitchyEngine.Math;

public static class RandomExtension
{
    /// <summary>Returns a random floating-point number that is greater than or equal to 0.0, and less than 1.0.</summary>
    /// <returns>A double-precision floating point number that is greater than or equal to 0.0, and less than 1.0.</returns>
    public static float NextFloat(this Random random) => (float)random.NextDouble();

    /// <summary>Returns a random integer that is within a specified range.</summary>
    /// <param name="random"></param>
    /// <param name="min">The inclusive lower bound of the random number returned.</param>
    /// <param name="max">The exclusive upper bound of the random number returned. <paramref name="max"/> must be greater than or equal to <paramref name="min"/> .</param>
    /// <returns>A 32-bit signed integer greater than or equal to <paramref name="min"/> and less than <paramref name="max"/>; that is, the range of return values includes <paramref name="min"/> but not <paramref name="max"/>. If <paramref name="min"/> equals <paramref name="max"/>, <paramref name="min"/> is returned.</returns>
    /// <exception cref="T:System.ArgumentOutOfRangeException"><paramref name="min"/> is greater than <paramref name="max"/>.</exception>
    public static int Range(this Random random, int min, int max) => random.Next(min, max);
    
    /// <summary>Returns a random floating-point number that is within a specified range.</summary>
    /// <param name="random"></param>
    /// <param name="min">The inclusive lower bound of the random number returned.</param>
    /// <param name="max">The exclusive upper bound of the random number returned. <paramref name="max"/> must be greater than or equal to <paramref name="min"/> .</param>
    /// <returns>A 32-bit signed integer greater than or equal to <paramref name="min"/> and less than <paramref name="max"/>; that is, the range of return values includes <paramref name="min"/> but not <paramref name="max"/>. If <paramref name="min"/> equals <paramref name="max"/>, <paramref name="min"/> is returned.</returns>
    /// <exception cref="T:System.ArgumentOutOfRangeException"><paramref name="min"/> is greater than <paramref name="max"/>.</exception>
    public static float Range(this Random random, float min, float max) => (float)(random.NextDouble() * (max - min) + min);
    
    /// <summary>Returns a random floating-point number that is within a specified range.</summary>
    /// <param name="random"></param>
    /// <param name="min">The inclusive lower bound of the random number returned.</param>
    /// <param name="max">The exclusive upper bound of the random number returned. <paramref name="max"/> must be greater than or equal to <paramref name="min"/> .</param>
    /// <returns>A 32-bit signed integer greater than or equal to <paramref name="min"/> and less than <paramref name="max"/>; that is, the range of return values includes <paramref name="min"/> but not <paramref name="max"/>. If <paramref name="min"/> equals <paramref name="max"/>, <paramref name="min"/> is returned.</returns>
    /// <exception cref="T:System.ArgumentOutOfRangeException"><paramref name="min"/> is greater than <paramref name="max"/>.</exception>
    public static double Range(this Random random, double min, double max) => random.NextDouble() * (max - min) + min;
}
