using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;

namespace GlitchyEngine.Extensions;

/// <summary>
/// Extends the <see cref="FieldInfo"/>-class with useful methods.
/// </summary>
public static class FieldInfoExtension
{
    /// <summary>
    /// Returns <see langword="true"/> if the field has the specified attribute.
    /// </summary>
    /// <typeparam name="T">The type of the attribte.</typeparam>
    public static bool HasCustomAttribute<T>(this FieldInfo fiedInfo) where T : Attribute
    {
        return fiedInfo.GetCustomAttribute<T>() != null;
    }
}
