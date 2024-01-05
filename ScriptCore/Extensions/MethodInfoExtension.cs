using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;

namespace GlitchyEngine.Extensions;

public static class MethodInfoExtension
{
    /// <summary>
    /// Gets the <see cref="Delegate"/> of this <see cref="MethodInfo"/>.
    /// </summary>
    /// <typeparam name="T">The type of the Delegate.</typeparam>
    /// <param name="info">The method info.</param>
    /// <returns>The delegate.</returns>
    public static T GetDelegate<T>(this MethodInfo info) where T : Delegate
    {
        return (T)Delegate.CreateDelegate(typeof(T), info);
    }
}
