using System;
using System.Runtime.CompilerServices;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine;

internal struct EntityHandle
{
    public uint Version;
    public uint Index;
}

public abstract class Entity : EngineObject
{
    //private UUID _uuid;

    //public UUID UUID => _uuid;

    ///// <summary>
    ///// Empty constructor not used. Do NOT USE!
    ///// </summary>
    //protected Entity()
    //{}

    //internal Entity(UUID uuid)
    //{
    //    _uuid = uuid;
    //}

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool HasComponent<T>() => HasComponent(typeof(T));
    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool HasComponent(Type type) => ScriptGlue.Entity_HasComponent(_uuid, type);

    /// <summary>
    /// Gets the component with the specified type.
    /// </summary>
    /// <typeparam name="T">The type of the component to get.</typeparam>
    /// <returns>The component or null, if the entity doesn't have a component of the specified type.</returns>
    public T GetComponent<T>() where T : Component, new()
    {
        Log.Info("Trying to get component");

        if (HasComponent<T>())
        {
            return new T
            {
                Entity = this
            };
        }

        return null;
    }
    
    /// <summary>
    /// Gets the component with the given type.
    /// </summary>
    /// <param name="componentType">The type of the component to get.</param>
    /// <returns>The component or null, if the entity doesn't have a component of the given type.</returns>
    /// <remarks>For performance reasons it is recommended to use <see cref="GetComponent{T}"/> if possible.</remarks>
    public Component GetComponent(Type componentType)
    {
        // TODO: probably throw!
        if (!componentType.IsSubclassOf(typeof(Component))) return null;
        
        if (HasComponent(componentType))
        {
            return Activator.CreateInstance(componentType) as Component;
        }

        return null;
    }
    
    /// <summary>
    /// Gets the component with the specified component type.
    /// </summary>
    /// <typeparam name="T">The type of the component to add.</typeparam>
    /// <returns>The component.</returns>
    public T AddComponent<T>() where T : Component, new()
    {
        ScriptGlue.Entity_AddComponent(_uuid, typeof(T));

        return new T
        {
            Entity = this
        };
    }

    /// <summary>
    /// Gets the component with the given component type.
    /// </summary>
    /// <param name="componentType">The type of the component to add.</param>
    /// <returns>The component or null, if the given type is not a valid component type.</returns>
    /// <remarks>For performance reasons it is recommended to use <see cref="AddComponent{T}"/> if possible.</remarks>
    public Component AddComponent(Type componentType)
    {
        // TODO: probably throw!
        if (!componentType.IsSubclassOf(typeof(Component))) return null;
        
        ScriptGlue.Entity_AddComponent(_uuid, componentType);

        Component component = Activator.CreateInstance(componentType) as Component;
        return component;
    }
    
    /// <summary>
    /// Removes the component with the specified component type.
    /// </summary>
    /// <typeparam name="T">The type of the component to remove.</typeparam>
    public void RemoveComponent<T>() where T : Component, new()
    {
        ScriptGlue.Entity_RemoveComponent(_uuid, typeof(T));
    }
    
    /// <summary>
    /// Removes the component with the given component type.
    /// </summary>
    /// <param name="componentType">The type of the component to remove.</param>
    /// <remarks>For performance reasons it is recommended to use <see cref="RemoveComponent{T}"/> if possible.</remarks>
    public void RemoveComponent(Type componentType)
    {
        // TODO: probably throw!
        if (!componentType.IsSubclassOf(typeof(Component))) return;
        
        ScriptGlue.Entity_RemoveComponent(_uuid, componentType);
    }

    public Transform Transform => GetComponent<Transform>();

    public Vector3 Translation
    {
        get => Transform.Translation;
        set => Transform.Translation = value;
    }

    // Will be executed once after the entity as be created.
    // void OnCreate();

    // Will be executed every frame.
    // void OnUpdate(GameTime);

    // Will be executed once when the entity is being destroyed.
    // void OnDestroy();
}