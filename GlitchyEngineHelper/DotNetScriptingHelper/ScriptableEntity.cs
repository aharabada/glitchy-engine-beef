using System.Diagnostics;
using System.Runtime.InteropServices;

namespace DotNetScriptingHelper;

public abstract class ScriptableEntity
{
    internal Entity Entity;
    
    public virtual void OnCreate() { }
    protected virtual void OnDestroy() { }
    protected virtual void OnUpdate() { }

    [UnmanagedCallersOnly]
    public static IntPtr CreateInstance(IntPtr typeNamePtr, int typeNameLength, EcsEntity entity)
    {
        try
        {
            string typeName = Marshal.PtrToStringUTF8(typeNamePtr, typeNameLength);
            
            Type? type = Type.GetType(typeName, true);

            Debug.Assert(type != null, "Type not found.");

            object? instance = Activator.CreateInstance(type);
            
            Debug.Assert(instance != null, "Instance could not be created");

            Debug.Assert(instance is ScriptableEntity, "Activated instance doesn't inherit from ScriptableEntity");

            if (instance is not ScriptableEntity scriptableEntity)
                return IntPtr.Zero;
            
            scriptableEntity.Entity = new Entity(entity);
            scriptableEntity.OnCreate();

            GCHandle handle = GCHandle.Alloc(instance);
            return GCHandle.ToIntPtr(handle);
        }
        catch (Exception e)
        {
            Console.WriteLine(e);
            throw;
        }
    }

    [UnmanagedCallersOnly]
    public static void DestroyEntity(IntPtr entityPtr)
    {
        GCHandle entityHandle = GCHandle.FromIntPtr(entityPtr);

        if (entityHandle.Target is ScriptableEntity entity)
        {
            entity.OnDestroy();
        }

        entityHandle.Free();
    }

    [UnmanagedCallersOnly]
    public static void UpdateEntity(IntPtr entityPtr)
    {
        GCHandle entityHandle = GCHandle.FromIntPtr(entityPtr);

        if (entityHandle.Target is ScriptableEntity entity)
        {
            entity.OnUpdate();
        }
    }
}
