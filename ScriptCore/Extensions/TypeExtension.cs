using System;
using System.Collections.Generic;
using System.Text;

namespace GlitchyEngine.Extensions;

public static class TypeExtension
{
    /// <summary>
    /// Determines whether the current type can be assigned to a variable of the specified <see cref="targetType"/>.
    /// </summary>
    /// <param name="targetType">The type to compare with the current type.</param>
    /// <returns></returns>
    public static bool IsAssignableTo(this Type type, Type targetType)
    {
        return targetType.IsAssignableFrom(type);
    }
}
