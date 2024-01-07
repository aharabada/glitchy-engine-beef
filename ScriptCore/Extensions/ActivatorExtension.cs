#nullable enable

using System;
using System.Reflection;
using GlitchyEngine.Core;

namespace GlitchyEngine.Extensions;

public static class ActivatorExtension
{
    /// <summary>Creates an instance of the specified type using that type's default constructor.</summary>
    /// <param name="type">The type of object to create.</param>
    /// <returns>A reference to the newly created object; or <see langword="null"/> if no instance could be created.</returns>
    public static object? CreateInstanceSafe(Type type)
    {
        try
        {
            return Activator.CreateInstance(type, true);
        }
        catch (MissingMethodException e)
        {
            Log.Error($"Failed to create instance of type \"{type}\": The type doesn't contain a constructor with zero parameters.\nMake sure the type has a constructor that takes no arguments (It can be private!).\n{e}");
        }
        catch (MethodAccessException e)
        {
            Log.Error($"Failed to create instance of type \"{type}\": The default constructor is not accessible.\n{e}");
        }
        catch (Exception e)
        {
            Log.Error($"Failed to create instance of type \"{type}\": {e}");
        }

        return null;
    }

    /// <summary>Creates an instance of the specified type using a constructor that matches the given arguments.</summary>
    /// <param name="type">The type of object to create.</param>
    /// <param name="args">The arguments passed to the constructor</param>
    /// <returns>A reference to the newly created object; or <see langword="null"/> if no instance could be created.</returns>
    public static object? CreateInstanceSafe(Type type, params object[] args)
    {
        try
        {
            return Activator.CreateInstance(type, BindingFlags.Default | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.CreateInstance | BindingFlags.Instance, null, args, null);
        }
        catch (Exception e)
        {
            Log.Error($"Failed to create instance of type \"{type}\": {e}");
        }

        return null;
    }

    /// <summary>
    /// Creates an instance of the given component type and sets it's entities id.
    /// </summary>
    /// <param name="componentType">The type of the component.</param>
    /// <param name="entityId">The entities id.</param>
    /// <returns>An instance of the component type; or <see langword="null"/> if the creation failed.</returns>
    internal static Component? CreateComponent(Type componentType, UUID entityId)
    {
        Component? component = (Component?)CreateInstanceSafe(componentType);
            
        if (component != null)
            component._uuid = entityId;

        return component;
    }
}
