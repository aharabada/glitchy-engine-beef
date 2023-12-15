using System;
using System.Runtime.CompilerServices;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;

namespace GlitchyEngine;

/// <summary>
/// The base class for all entities and scripts in the current world.
/// </summary>
public class Entity : EngineObject
{
    /// <summary>
    /// Only to be called by the engine. Don't call this constructor yourself, it will not result in a valid entity.
    /// If you want to create a new entity use <see cref="Entity(string)"/> or <see cref="Entity(string, Type[])"/>
    /// </summary>
    protected Entity()
    {
        // We don't do anything here.
        // This constructor will be called by the Engine to initialize the scripts fields.
        // Especially don't call Create here! Because Create would try and create a new entity.
    }

    /// <summary>
    /// Creates a new Entity.
    /// </summary>
    /// <param name="name">The name of the new entity.</param>
    public Entity(string name = null)
    {
        Create(name, null);
    }
    
    /// <summary>
    /// Creates a new Entity with the specified components attached to it.
    /// </summary>
    /// <param name="name">The name of the new entity.</param>
    /// <param name="components">The components that the entity shall have.</param>
    public Entity(string name, params Type[] components)
    {
        Create(name, components);
    }

    private void Create(string name, Type[] components)
    {
        ScriptGlue.Entity_Create(this, name, components, out _uuid);
        
        if (_uuid == UUID.Zero)
        {
            throw new InvalidOperationException("Failed to create the Entity. Received UUID.Zero from the engine.");
        }
    }

    /// <summary>
    /// Creates an instance that represents the Entity with the given id.
    /// </summary>
    /// <param name="uuid">The ID of the entity that belongs to this instance.</param>
    internal Entity(UUID uuid) : base(uuid) { }

    /// <summary>
    /// Returns <see langword="true"/> if a component of the given type is attached to this entity.
    /// </summary>
    /// <typeparam name="T">The type of the component.</typeparam>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool HasComponent<T>() => HasComponent(typeof(T));
    
    /// <summary>
    /// Returns <see langword="true"/> if a component of the given type is attached to this entity.
    /// </summary>
    /// <param name="type">The type of the component.</param>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool HasComponent(Type type) => ScriptGlue.Entity_HasComponent(_uuid, type);

    /// <summary>
    /// Gets the component with the specified type.
    /// </summary>
    /// <typeparam name="T">The type of the component to get.</typeparam>
    /// <returns>The component or null, if the entity doesn't have a component of the specified type.</returns>
    public T GetComponent<T>() where T : Component, new()
    {
        if (HasComponent<T>())
        {
            return new T
            {
                _uuid = _uuid
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

    #region Add Components

    /// <summary>
    /// Adds the component with the specified type.
    /// </summary>
    /// <typeparam name="T">The type of the component to add.</typeparam>
    /// <returns>The component.</returns>
    public T AddComponent<T>() where T : Component, new()
    {
        ScriptGlue.Entity_AddComponent(_uuid, typeof(T));

        return new T
        {
            _uuid = _uuid
        };
    }

    /// <summary>
    /// Adds the component with the given type.
    /// </summary>
    /// <param name="componentType">The type of the component to add.</param>
    /// <returns>The component or null, if the given type is not a valid component type.</returns>
    /// <remarks>For performance reasons it is recommended to use <see cref="AddComponent{T}"/> if possible.</remarks>
    public Component AddComponent(Type componentType)
    {
        if (!componentType.IsSubclassOf(typeof(Component)))
        {
            throw new ArgumentException($"Invalid component type \"{componentType}\". Must be a subclass of \"Component\".", nameof(componentType));
        }

        ScriptGlue.Entity_AddComponent(_uuid, componentType);

        Component component = Activator.CreateInstance(componentType) as Component;
        if (component != null)
        {
            component._uuid = _uuid;
        }

        return component;
    }


    /// <summary>
    /// Adds components with the specified types to the entity.
    /// </summary>
    /// <param name="componentTypes">The types of the components to add.</param>
    /// <returns>An array containing the components.</returns>
    public Component[] AddComponents(params Type[] componentTypes)
    {
        foreach ((Type componentType, int index) in componentTypes.WithIndex())
        {
            if (!componentType.IsSubclassOf(typeof(Component)))
            {
                throw new ArgumentException($"Invalid component type \"{componentType}\" at index {index}. Must be a subclass of \"Component\".", nameof(componentTypes));
            }
        }

        ScriptGlue.Entity_AddComponents(_uuid, componentTypes);

        Component[] components = new Component[componentTypes.Length];
        
        foreach ((Type componentType, int index) in componentTypes.WithIndex())
        {
            components[index] = Activator.CreateInstance(componentType) as Component;
            components[index]._uuid = _uuid;
        }

        return components;
    }

    /// <summary>
    /// Adds the specified components to the entity.
    /// </summary>
    /// <returns>A tuple containing the added components.</returns>
    public (T1, T2) AddComponents<T1, T2>()
        where T1 : Component, new()
        where T2 : Component, new()
    {
        ScriptGlue.Entity_AddComponents(_uuid, new []{typeof(T1), typeof(T2)});

        return (new T1 { _uuid = _uuid }, new T2 { _uuid = _uuid });
    }

    /// <summary>
    /// Adds the specified components to the entity.
    /// </summary>
    /// <returns>A tuple containing the added components.</returns>
    public (T1, T2, T3) AddComponents<T1, T2, T3>()
        where T1 : Component, new()
        where T2 : Component, new()
        where T3 : Component, new()
    {
        ScriptGlue.Entity_AddComponents(_uuid, new []{typeof(T1), typeof(T2), typeof(T3)});

        return (new T1 { _uuid = _uuid }, new T2 { _uuid = _uuid }, new T3 { _uuid = _uuid });
    }

    #endregion Add Components

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
        if (!componentType.IsSubclassOf(typeof(Component)))
        {
            throw new ArgumentException($"Invalid component type \"{componentType}\". Must be a subclass of \"Component\".", nameof(componentType));
        }

        ScriptGlue.Entity_RemoveComponent(_uuid, componentType);
    }

    /// <summary>
    /// Sets the script of the entity to the specified type.
    /// If necessary removes the existing script.
    /// </summary>
    /// <typeparam name="T">The type of the script.</typeparam>
    public T SetScript<T>() where T : Entity
    {
        return ScriptGlue.Entity_SetScript(_uuid, typeof(T)) as T;
    }
    
    /// <summary>
    /// Removes the script from the entity.
    /// </summary>
    public void RemoveScript()
    {
        ScriptGlue.Entity_RemoveScript(_uuid);
    }

    /// <summary>
    /// Gets the <see cref="Core.Transform"/> <see cref="Component"/> of this <see cref="Entity"/>.
    /// </summary>
    public Transform Transform => GetComponent<Transform>();

    /// <summary>
    /// Returns the first entity with the given name.
    /// </summary>
    /// <param name="name">The name of the entity.</param>
    /// <returns>The first entity with the given name, or null.</returns>
    public static Entity FindEntityWithName(string name)
    {
        ScriptGlue.Entity_FindEntityWithName(name, out UUID entityId);
        
        if (entityId == UUID.Zero)
            return null;

        return new Entity(entityId);
    }
    
    /// <summary>
    /// Returns true if the entity has a script component of the given type; false if the entity either has no script or the script is not of the specified type.
    /// </summary>
    /// <typeparam name="T">The type of the script.</typeparam>
    public bool Is<T>() where T : Entity
    {
        ScriptGlue.Entity_GetScriptInstance(_uuid, out object scriptInstance);

        return scriptInstance is T;
    }

    /// <summary>
    /// Returns the script of the given type, or null, if the entity has no script of the given type.
    /// </summary>
    /// <typeparam name="T">The type of the script.</typeparam>
    /// <returns>The script instance or null.</returns>
    public T As<T>() where T : Entity
    {
        ScriptGlue.Entity_GetScriptInstance(_uuid, out object scriptInstance);

        return scriptInstance as T;
    }

    /// <summary>
    /// Destroys the entity and all it's children.
    /// </summary>
    /// <remarks>
    /// The destruction will not take place immediately. It will happen at the end of the current frame.
    /// </remarks>
    public void Destroy()
    {
        ScriptGlue.Entity_Destroy(_uuid);
    }

    /// <summary>
    /// Instantiates a copy of the given entity and it's children.
    /// </summary>
    /// <param name="entity">The entity to copy.</param>
    /// <returns>The new entity.</returns>
    public static Entity CreateInstance(Entity entity)
    {
        ScriptGlue.Entity_CreateInstance(entity.UUID, out UUID newEntityId);

        return new Entity(newEntityId);
    }

    // Will be executed once after the entity has be created.
    // void OnCreate();

    // Will be executed every frame.
    // void OnUpdate(GameTime);

    // Will be executed once when the entity is being destroyed.
    // void OnDestroy();
}
