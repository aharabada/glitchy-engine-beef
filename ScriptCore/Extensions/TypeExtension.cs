using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
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
            if (!type.IsAbstract && baseType.IsAssignableFrom(type)) yield return type;
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

    private static ReadOnlySpan<char> ReadTypeName(ReadOnlySpan<char> fullName)
    {
        for (int i = 0; i < fullName.Length; i++)
        {
            if (!char.IsLetterOrDigit(fullName[i]) && fullName[i] != '.' && fullName[i] != '+' && fullName[i] != '_')
            {
                return fullName.Slice(0, i);
            }
        }

        return fullName;
    }
    
    public static Type? FindType(string fullName)
    {
        ReadOnlySpan<char> rest = new ReadOnlySpan<char>();

        return FindType(fullName.AsSpan(), ref rest);
    }

    private static Type? FindType(ReadOnlySpan<char> fullName, ref ReadOnlySpan<char> rest)
    {
        rest = fullName;

        ReadOnlySpan<char> typeName = ReadTypeName(fullName);
        rest = rest.Slice(typeName.Length);
        
        if (rest.IsEmpty || rest[0] != '`')
        {
            // Non generic type, easy!
            return GetType(typeName);
        }

        // Handle generic type

        int brackedIndex = fullName.IndexOf('[');

        typeName = fullName.Slice(0, brackedIndex);
        rest = fullName.Slice(brackedIndex + 1).Trim();

        Type? genericType = GetType(typeName);

        Console.WriteLine($"Generic Type: {genericType}");
        
        List<Type> arguments = new List<Type>();

        while (true)
        {
            Type? argument = FindType(rest, ref rest);
            Console.WriteLine($"Argument:  {argument}");

            Debug.Assert(argument != null);

            arguments.Add(argument!);

            rest = rest.TrimStart();

            if (rest.TrimStart()[0] == ',')
            {
                rest = rest.Slice(1);
            }
            else if (rest.TrimStart()[0] == ']')
            {
                rest = rest.Slice(1);
                break;
            }
            else
            {
                break;
            }
        }
        
        return genericType?.MakeGenericType(arguments.ToArray());
    }

    private static Type? GetType(ReadOnlySpan<char> fullName)
    {
        string name = fullName.TrimEnd(']').ToString();

        // Non generic type, easy!
        foreach (Assembly assembly in AppDomain.CurrentDomain.GetAssemblies().Reverse())
        {
            Type? type = assembly.GetType(name);

            if (type != null)
                return type;
        }

        return null;
    }

    /// <summary>
    /// Gets the simple name of the type. This is the name of the type without any generic arguments.
    /// </summary>
    /// <param name="type">The type whose name is to be simplified.</param>
    /// <returns>The simple name of the type.</returns>
    public static string GetSimpleName(this Type type)
    {
        string uglyName = type.Name;

        int tickIndex = uglyName.IndexOf('`');

        if (tickIndex < 0)
        {
            return uglyName;
        }

        return uglyName.Substring(0, tickIndex);
    }

    /// <summary>
    /// Gets the pretty name of the type, including generic arguments. This prints the type name as it would be written in C# code.
    /// If the type is not generic, the name is returned as is.
    /// </summary>
    /// <param name="type">The type whose name is to be written pretty.</param>
    /// <returns>The pretty name of the type.</returns>
    public static string GetPrettyName(this Type type)
    {
        if (!type.IsGenericType)
        {
            return type.Name;
        }

        string uglyName = type.Name;

        int tickIndex = uglyName.IndexOf('`');

        // No tick in generic name?
        if (tickIndex < 0)
        {
            return uglyName;
        }
        
        StringBuilder nameBuilder = new StringBuilder(uglyName.Substring(0, tickIndex));

        nameBuilder.Append('<');
                            
        Type[] genericParameters = type.GetGenericArguments();

        bool first = true;
                            
        foreach (Type genericParameter in genericParameters)
        {
            if (!first)
            {
                nameBuilder.Append(", ");
            }
            else
            {
                first = false;
            }
                                
            nameBuilder.Append(genericParameter.Name);
        }

        nameBuilder.Append('>');
                            
        return nameBuilder.ToString();
    }

    /// <summary>
    /// Returns <see langword="true"/> if the type has at least one static field; <see langword="false"/> otherwise.
    /// </summary>
    public static bool HasStaticFields(this Type type)
    {
        foreach (FieldInfo _ in type.GetFields(BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic))
        {
            return true;
        }

        return false;
    }
}
