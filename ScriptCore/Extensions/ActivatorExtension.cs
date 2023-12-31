using System;

namespace GlitchyEngine.Extensions;

public static class ActivatorExtension
{
    /// <summary>Creates an instance of the specified type using that type's default constructor.</summary>
    /// <param name="type">The type of object to create.</param>
    /// <returns>A reference to the newly created object; or <see langword="null"/> if no instance could be created.</returns>
    public static object CreateInstanceSafe(Type type)
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
}
