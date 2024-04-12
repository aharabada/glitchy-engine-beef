using System;
using System.Reflection;

namespace GlitchyEngine.Extensions;

/// <summary>
/// Extends <see cref="MemberInfo"/> with useful methods.
/// </summary>
public static class MemberInfoExtension
{
    /// <summary>
    /// Returns <see langword="true"/> if the member has the specified attribute.
    /// </summary>
    /// <typeparam name="T">The type of the attribute.</typeparam>
    public static bool HasCustomAttribute<T>(this MemberInfo memberInfo) where T : Attribute
    {
        return memberInfo.GetCustomAttribute<T>() != null;
    }
}
