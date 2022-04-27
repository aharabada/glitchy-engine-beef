using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using DotNetScriptingHelper.Components;

namespace DotNetScriptingHelper;

public abstract class ScriptableEntity
{
    internal Entity Entity;
    
    public virtual void OnCreate() { }
    protected virtual void OnDestroy() { }
    protected virtual void OnUpdate(GameTime gameTime) { }

    [UnmanagedCallersOnly]
    public static IntPtr CreateInstance(IntPtr typeNamePtr, int typeNameLength, EcsEntity entity, IntPtr scene)
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
            
            scriptableEntity.Entity = new Entity(entity, scene);
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
    public static void UpdateEntity(IntPtr entityPtr, ulong frameCount, TimeSpan totalTime, TimeSpan frameTime)
    {
        GCHandle entityHandle = GCHandle.FromIntPtr(entityPtr);

        if (entityHandle.Target is ScriptableEntity entity)
        {
            GameTime gameTime = new GameTime(frameCount, totalTime, frameTime);

            entity.OnUpdate(gameTime);
        }
    }

    [DllImport("GlitchyEditor.exe", EntryPoint = "GE_DoStuff")]
    static extern int DoStuff();
    
    [DllImport("GlitchyEditor.exe", EntryPoint = "GE_DotNetScript_GetComponent")]
    private static extern IntPtr GetComponent(EcsEntity entity, IntPtr scenePtr);

    protected TransformComponent GetTransform()// where T : struct
    {
        IntPtr component = GetComponent(Entity.Handle, Entity.Scene);

        return new TransformComponent(component);

        //unsafe
        //{
        //    TransformComponent* transform = (TransformComponent*)component;

        //    return ref *transform;
        //}

        //GameComponentAttribute? attribute = typeof(T).GetCustomAttribute<GameComponentAttribute>();

        //Debug.Assert(attribute != null, $"Requested type {typeof(T)} is not a component.");
    }
}
