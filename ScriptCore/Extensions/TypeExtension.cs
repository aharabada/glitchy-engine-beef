using System;
using System.Collections.Generic;
using System.Reflection;
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

    /// <summary>
    /// Enumerates all types in all assemblies.
    /// </summary>
    public static IEnumerable<Type> EnumerateAllTypes()
    {
        foreach (Assembly domainAssembly in AppDomain.CurrentDomain.GetAssemblies())
        foreach (Type type in domainAssembly.GetTypes())
        {
            yield return type;
        }
    }

    /// <summary>
    /// Enumerates all types that derive from the given type.
    /// </summary>
    /// <param name="baseType"></param>
    /// <returns></returns>
    public static IEnumerable<Type> FindDerivedTypes(Type baseType)
    {
        foreach (Assembly domainAssembly in AppDomain.CurrentDomain.GetAssemblies())
        foreach (Type type in domainAssembly.GetTypes())
        {
            if (baseType.IsAssignableFrom(type) && !type.IsAbstract) yield return type;
        }
    }

    /// <summary>
    /// Returns whether or not the type has an <see cref="Attribute"/> of the specified <see cref="Type"/> <see cref="T"/>.
    /// </summary>
    /// <typeparam name="T">The type of the attribute</typeparam>
    /// <returns><see langword="true"/> if the type has the specified <see cref="Attribute"/>; <see langword="true"/> otherwise.</returns>
    public static bool HasCustomAttribute<T>(this Type type) where T: Attribute
    {
        return type.GetCustomAttribute<T>() != null;
    }

    /// <summary>
    /// Returns whether or not the type has an <see cref="Attribute"/> of the specified <see cref="Type"/> <see cref="T"/>.
    /// </summary>
    /// <typeparam name="T">The type of the attribute</typeparam>
    /// <param name="attribute">The attribute, or <seealso langword="null"/>, if the type hasn't got the attribute specified.</param>
    /// <returns><see langword="true"/> if the type has the specified <see cref="Attribute"/>; <see langword="true"/> otherwise.</returns>
    public static bool TryGetCustomAttribute<T>(this Type type, out T attribute) where T: Attribute
    {
        attribute = type.GetCustomAttribute<T>();

        return attribute != null;
    }
}
