using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.CompilerServices;
using GlitchyEngine.Core;
using GlitchyEngine.Extensions;
using GlitchyEngine.Physics;
using System.Diagnostics.CodeAnalysis;
using GlitchyEngine.Editor;

namespace GlitchyEngine;

/// <summary>
/// The base class for all entities and scripts in the current world.
/// </summary>
public class Entity : EngineObject
{
    /// <summary>
    /// Gets or sets the name of the <see cref="Entity"/>.
    /// </summary>
    public string Name
    {
        get => "TODO!";//ScriptGlue.Entity_GetName(_uuid);
        set => ScriptGlue.Entity_SetName(_uuid, value);
    }
    
    /// <summary>
    /// Gets or sets the <see cref="EditorFlags"/> of the <see cref="Entity"/>, which specify how the <see cref="Entity"/> is displayed and interacted with in the editor.
    /// </summary>
    public EditorFlags EditorFlags
    {
        get
        {
            ScriptGlue.Entity_GetEditorFlags(_uuid, out EditorFlags flags);
            return flags;
        }
        set => ScriptGlue.Entity_SetEditorFlags(_uuid, value);
    }

    /// <summary>
    /// Only to be called by the engine. Don't call this constructor yourself, it will not result in a valid <see cref="Entity"/>.
    /// If you want to create a new <see cref="Entity"/> use <see cref="Entity(string)"/> or <see cref="Entity(string, Type[])"/>
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
    /// <param name="name">The name of the new <see cref="Entity"/>.</param>
    public Entity(string? name = null)
    {
        Create(name, null);
    }
    
    /// <summary>
    /// Creates a new <see cref="Entity"/> with the specified components attached to it.
    /// </summary>
    /// <param name="name">The name of the new <see cref="Entity"/>.</param>
    /// <param name="components">The components that the <see cref="Entity"/> will be created with.</param>
    public Entity(string? name, params Type[] components)
    {
        Create(name, components);
    }

    private void Create(string? name, Type[]? components)
    {
        ScriptGlue.Entity_Create(name, out _uuid);
        
        if (_uuid == UUID.Zero)
        {
            throw new InvalidOperationException("Failed to create the Entity. Received UUID.Zero from the engine.");
        }

        if (components != null)
        {
            AddComponents(components);
        }
    }

    /// <summary>
    /// Creates an instance that represents the <see cref="Entity"/> with the given id.
    /// </summary>
    /// <param name="uuid">The ID of the <see cref="Entity"/> that belongs to this instance.</param>
    internal Entity(UUID uuid) : base(uuid) { }
    
    #region Components

    /// <summary>
    /// Returns <see langword="true"/> if a component of the given type is attached to this <see cref="Entity"/>.
    /// </summary>
    /// <typeparam name="T">The type of the component.</typeparam>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool HasComponent<T>() => HasComponent(typeof(T));
    
    /// <summary>
    /// Returns <see langword="true"/> if a component of the given type is attached to this <see cref="Entity"/>.
    /// </summary>
    /// <param name="type">The type of the component.</param>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool HasComponent(Type type)
    {
        return ScriptGlue.Entity_HasComponent(_uuid, type);
    }

    /// <summary>
    /// Gets the component with the specified type.
    /// </summary>
    /// <typeparam name="T">The type of the component to get.</typeparam>
    /// <returns>The component or null, if the <see cref="Entity"/> doesn't have a component of the specified type.</returns>
    public T? GetComponent<T>() where T : Component, new()
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
    /// Gets the component with the specified type.
    /// </summary>
    /// <typeparam name="T">The type of the component to get.</typeparam>
    /// <param name="component">If the entity has a <see cref="Component"/> of type <see cref="T"/> then <see cref="Component"/> contains a reference to this component; otherwise it will contain <see langword="null"/> after the method returned.</param>
    /// <returns><see langword="true"/>, if a component was retrieved; otherwise <see langword="false"/>.</returns>
    public bool TryGetComponent<T>([MaybeNullWhen(false)] out T component) where T : Component, new()
    {
        component = GetComponent<T>();
        
        return component != null;
    }

    /// <summary>
    /// Gets the component with the given type.
    /// </summary>
    /// <param name="componentType">The type of the component to get.</param>
    /// <returns>The component; or <see langword="null"/>, if the <see cref="Entity"/> doesn't have a component of the specified type or if <see cref="componentType"/> doesn't inherit from <see cref="Component"/>.</returns>
    /// <remarks>For performance reasons it is recommended to use <see cref="GetComponent{T}"/> if possible as it might be slightly faster.</remarks>
    public Component? GetComponent(Type componentType)
    {
        if (!componentType.IsSubclassOf(typeof(Component)))
        {
            Log.Error($"{nameof(GetComponent)}: Invalid component type \"{componentType}\". Must be a subclass of \"{nameof(Component)}\".");
            return null;
        }
        
        if (HasComponent(componentType))
        {
            return ActivatorExtension.CreateComponent(componentType, _uuid);
        }

        return null;
    }

    /// <summary>
    /// Attaches a component of the specified type to the <see cref="Entity"/>.
    /// </summary>
    /// <typeparam name="T">The type of the component to attach.</typeparam>
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
    /// Attaches a component of the specified type to the <see cref="Entity"/>.
    /// </summary>
    /// <param name="componentType">The type of the component to attach.</param>
    /// <returns>The component that was attached to the <see cref="Entity"/>; or <see langword="null"/> if <see cref="componentType"/> doesn't inherit from <see cref="Component"/>.</returns>
    /// <remarks>For performance reasons it is recommended to use <see cref="AddComponent{T}"/> if possible as it might be slightly faster.</remarks>
    public Component? AddComponent(Type componentType)
    {
        if (!componentType.IsSubclassOf(typeof(Component)))
        {
            Log.Error($"{nameof(AddComponent)}: Invalid component type \"{componentType}\". Must be a subclass of \"{nameof(Component)}\".");
            return null;
        }

        ScriptGlue.Entity_AddComponent(_uuid, componentType);
        
        return ActivatorExtension.CreateComponent(componentType, _uuid);
    }


    /// <summary>
    /// Attaches components with the specified types to the <see cref="Entity"/>.
    /// </summary>
    /// <param name="componentTypes">The types of the components to attach.</param>
    /// <returns>An array containing the components that were attached. A component is <see langword="null"/>, if it's type doesn't inherit from <see cref="Component"/>.</returns>
    public Component?[] AddComponents(params Type[] componentTypes)
    {
        // Note: The elements in componentTypes are non-nullable externally, but internally we rely on nullability.

        foreach ((Type componentType, int index) in componentTypes.WithIndex())
        {
            if (!componentType.IsSubclassOf(typeof(Component)))
            {
                Log.Error($"{nameof(AddComponents)}: Invalid component type \"{componentType}\" at index {index}. Must be a subclass of \"{nameof(Component)}\".");

                // Setting null here is fine, the engine can handle it!
                componentTypes[index] = null!;
            }
        }
        
        Component?[] components = new Component[componentTypes.Length];
        
        foreach ((Type componentType, int index) in componentTypes.WithIndex())
        {
            // componentType is null, if it's type is invalid!
            if (componentType == null!)
                continue;

            ScriptGlue.Entity_AddComponent(_uuid, componentType);

            components[index] = ActivatorExtension.CreateComponent(componentType, _uuid);
        }

        return components;
    }

    /// <summary>
    /// Attaches the specified components to the <see cref="Entity"/>.
    /// </summary>
    /// <returns>A tuple containing the added components.</returns>
    public (T1, T2) AddComponents<T1, T2>()
        where T1 : Component, new()
        where T2 : Component, new()
    {
        ScriptGlue.Entity_AddComponent(_uuid, typeof(T1));
        ScriptGlue.Entity_AddComponent(_uuid, typeof(T2));

        return (new T1 { _uuid = _uuid }, new T2 { _uuid = _uuid });
    }

    /// <summary>
    /// Attaches the specified components to the <see cref="Entity"/>.
    /// </summary>
    /// <returns>A tuple containing the added components.</returns>
    public (T1, T2, T3) AddComponents<T1, T2, T3>()
        where T1 : Component, new()
        where T2 : Component, new()
        where T3 : Component, new()
    {
        ScriptGlue.Entity_AddComponent(_uuid, typeof(T1));
        ScriptGlue.Entity_AddComponent(_uuid, typeof(T2));
        ScriptGlue.Entity_AddComponent(_uuid, typeof(T3));

        return (new T1 { _uuid = _uuid }, new T2 { _uuid = _uuid }, new T3 { _uuid = _uuid });
    }

    /// <summary>
    /// Removes the component with the specified component type from the <see cref="Entity"/>.
    /// </summary>
    /// <typeparam name="T">The type of the component to remove.</typeparam>
    public void RemoveComponent<T>() where T : Component, new()
    {
        ScriptGlue.Entity_RemoveComponent(_uuid, typeof(T));
    }
    
    /// <summary>
    /// Removes the component with the given component type from the <see cref="Entity"/>.
    /// </summary>
    /// <param name="componentType">The type of the component to remove.</param>
    public void RemoveComponent(Type componentType)
    {
        if (!componentType.IsSubclassOf(typeof(Component)))
        {
            Log.Error($"{nameof(RemoveComponent)}: Invalid component type \"{componentType}\". Must be a subclass of \"{nameof(Component)}\".");
            return;
        }

        ScriptGlue.Entity_RemoveComponent(_uuid, componentType);
    }

    #endregion Components

    /// <summary>
    /// Sets the script of the <see cref="Entity"/> to the specified type.
    /// If necessary removes the existing script.
    /// </summary>
    /// <typeparam name="T">The type of the script.</typeparam>
    /// <returns>A reference to the new script or <see langword="null"/>, if the operation failed.</returns>
    public T? SetScript<T>() where T : Entity
    {
        Entity? scriptInstance = null;

        if (ScriptGlue.Entity_SetScript(_uuid, typeof(T).FullName))
        {
            ScriptGlue.Entity_GetScriptInstance(_uuid, out scriptInstance);
        }
        
        return scriptInstance as T;
    }
    
    /// <summary>
    /// Removes the script from the <see cref="Entity"/>.
    /// </summary>
    public void RemoveScript()
    {
        ScriptGlue.Entity_RemoveScript(_uuid);
    }

    /// <summary>
    /// Gets the <see cref="Core.Transform"/> <see cref="Component"/> of this <see cref="Entity"/>.
    /// </summary>
    public Transform Transform => GetComponent<Transform>()!; // Transform always exists!

    /// <summary>
    /// Returns the first <see cref="Entity"/> with the given name.
    /// </summary>
    /// <param name="name">The name of the <see cref="Entity"/>.</param>
    /// <returns>The first <see cref="Entity"/> with the given name, or <see langword="null"/> if no such entity exists.</returns>
    public static Entity? FindEntityWithName(string name)
    {
        ScriptGlue.Entity_FindEntityWithName(name, out UUID entityId);
        
        if (entityId == UUID.Zero)
            return null;

        return new Entity(entityId);
    }
    
    /// <summary>
    /// Returns whether or not the <see cref="Entity"/> has a script of the specified type.
    /// </summary>
    /// <typeparam name="T">The type of the script.</typeparam>
    /// <returns><see langword="true"/> if the <see cref="Entity"/> has a script component of the given type; or <see langword="false"/> if the <see cref="Entity"/> either has no script or the script is not of the specified type.</returns>
    public bool Is<T>() where T : Entity
    {
        ScriptGlue.Entity_GetScriptInstance(_uuid, out Entity? scriptInstance);

        return scriptInstance is T;
    }

    /// <summary>
    /// Returns whether or not the <see cref="Entity"/> has a script of the specified type.
    /// </summary>
    /// <param name="type">The type of the script.</param>
    /// <returns><see langword="true"/> if the <see cref="Entity"/> has a script component of the given type; or <see langword="false"/> if the <see cref="Entity"/> either has no script or the script is not of the specified type.</returns>
    public bool Is(Type type)
    {
        if (!type.IsSubclassOf(typeof(Entity)))
        {
            Log.Warning($"{nameof(Is)}: Invalid script type \"{type}\". Must be a subclass of \"{nameof(Entity)}\".");
            return false;
        }

        ScriptGlue.Entity_GetScriptInstance(_uuid, out Entity? scriptInstance);

        return type.IsInstanceOfType(scriptInstance);
    }

    /// <summary>
    /// Returns the script instance of the given type that is attached to the <see cref="Entity"/>.
    /// </summary>
    /// <typeparam name="T">The type of the script.</typeparam>
    /// <returns>The script instance of the given type; or <see langword="null"/> if the <see cref="Entity"/> has no script of the given type.</returns>
    public T? As<T>() where T : Entity
    {
        ScriptGlue.Entity_GetScriptInstance(_uuid, out Entity? scriptInstance);

        return scriptInstance as T;
    }

    /// <summary>
    /// Returns the script instance of the given type that is attached to the <see cref="Entity"/>.
    /// </summary>
    /// <param name="type">The type of the script.</param>
    /// <returns>The script instance of the given type; or <see langword="null"/> if the <see cref="Entity"/> has no script of the given type.</returns>
    public object? As(Type type)
    {
        if (!type.IsSubclassOf(typeof(Entity)))
        {
            Log.Error($"{nameof(As)}: Invalid script type \"{type}\". Must be a subclass of \"{nameof(Entity)}\".");
            return null;
        }

        ScriptGlue.Entity_GetScriptInstance(_uuid, out Entity? scriptInstance);

        return scriptInstance;
    }

    /// <summary>
    /// Returns the script instance of the given type that is attached to the <see cref="Entity"/> with the given <see cref="id"/>.
    /// </summary>
    /// <param name="id">The id of the <see cref="Entity"/> whose script instance shall be returned.</param>
    /// <param name="type">The type of the script.</param>
    /// <returns>The script instance of the given type; or <see langword="null"/> if the <see cref="Entity"/> with the given <see cref="id"/> has no script of the given type.</returns>
    internal static Entity? GetScriptReference(UUID id, Type type)
    {
        Debug.Assert(typeof(Entity).IsAssignableFrom(type));

        ScriptGlue.Entity_GetScriptInstance(id, out Entity? scriptInstance);

        return scriptInstance as Entity;
    }

    /// <summary>
    /// Destroys the <see cref="Entity"/> and all it's children.
    /// </summary>
    /// <remarks>
    /// The destruction will not take place immediately. It will happen at the end of the current frame.
    /// </remarks>
    public void Destroy()
    {
        ScriptGlue.Entity_Destroy(_uuid);
    }

    /// <summary>
    /// Instantiates a copy of the given <see cref="Entity"/> and all of it's children.
    /// </summary>
    /// <param name="entity">The <see cref="Entity"/> to copy.</param>
    /// <returns>The new <see cref="Entity"/>.</returns>
    public static Entity CreateInstance(Entity entity)
    {
        if (entity == null)
        {
            throw new ArgumentException("The provided instance must not be null!", nameof(entity));
        }

        ScriptGlue.Entity_CreateInstance(entity.UUID, out UUID newEntityId);

        return new Entity(newEntityId);
    }

    /// <summary>
    /// Will be called once after the entity has be created.
    /// </summary>
    protected internal virtual void OnCreate() { }

    /// <summary>
    /// Is called once every frame.
    /// </summary>
    protected internal virtual void OnUpdate(float deltaTime) { }

    /// <summary>
    /// Will be called once when the entity is being destroyed.
    /// </summary>
    protected internal virtual void OnDestroy() { }
}
