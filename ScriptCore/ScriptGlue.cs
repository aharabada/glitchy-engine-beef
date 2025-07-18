using GlitchyEngine.Core;
using GlitchyEngine.Editor;
using GlitchyEngine.Extensions;
using GlitchyEngine.Serialization;
using ImGuiNET;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.Loader;

namespace GlitchyEngine;

[StructLayout(LayoutKind.Sequential)]
internal unsafe partial struct EngineFunctions
{
}

/// <summary>
/// All methods in here are glued to the ScriptGlue.bf in the engine.
/// </summary>
internal static unsafe partial class ScriptGlue
{
#region Script Glueing infrastructure

    static ScriptGlue()
    {
        ConfigureDllImportResolver();
    }

    private static void ConfigureDllImportResolver()
    {
        NativeLibrary.SetDllImportResolver(typeof(ScriptGlue).Assembly, ImportResolver);
        // TODO: With this we can actually use the official ImGui.NET-Branch in the future!
        NativeLibrary.SetDllImportResolver(typeof(ImGui).Assembly, ImportResolver);
    }

    /// <summary>
    /// Resolves an import request for the DLL <b>__Internal</b> (<c>[DllImport("__Internal")]</c>) to the current executable file.
    /// This allows calling functions that are part of the native executable (e.g. native libraries we want to use from C# scripts).
    /// </summary>
    private static IntPtr ImportResolver(string libraryName, Assembly assembly, DllImportSearchPath? searchPath)
    {
        if (libraryName == "__Internal")
        {
            string? mainModuleFileName = Process.GetCurrentProcess().MainModule?.FileName;

            if (mainModuleFileName != null)
                return NativeLibrary.Load(mainModuleFileName);
            
            throw new DllNotFoundException("Failed to resolve import to current executable: Could not find file name of main module.");
        }

        return IntPtr.Zero;
    }

    private static EngineFunctions _engineFunctions;
    
    private static AssemblyLoadContext? _scriptAssemblyContext;

    private static Assembly? _appAssembly;
    
    /// <summary>
    /// Entity script instances
    /// </summary>
    private static readonly Dictionary<UUID, (Entity Entity, Type Type)> EntityScriptInstances = new();

    /// <summary>
    /// Called by the engine to provide a struct containing all functions pointers that can be called from C##
    /// </summary>
    /// <param name="engineFunctions">The struct containing the function pointers to the engine functions.</param>
    [UnmanagedCallersOnly]
    public static void SetEngineFunctions(EngineFunctions* engineFunctions)
    {
        _engineFunctions = *engineFunctions;

        Log.Info("Yeah");
    }

    /// <summary>
    /// Called by the engine to load the provided assembly (containing user scripts) and optionally debug symbols.
    /// </summary>
    [UnmanagedCallersOnly]
    public static void LoadScriptAssembly(byte* assemblyData, long assemblyLength, byte* pdbData, long pdbLength)
    {
        using UnmanagedMemoryStream assemblyStream = new(assemblyData, assemblyLength);

        using UnmanagedMemoryStream? pdbStream = (pdbData != null) ? new UnmanagedMemoryStream(pdbData, pdbLength) : null;

        LoadAssembly(assemblyStream, pdbStream);
    }

    private static void LoadAssembly(Stream assemblyStream, Stream? pdbStream)
    {
        try
        {
            _scriptAssemblyContext ??= new AssemblyLoadContext("ScriptContext", true);

            _appAssembly = _scriptAssemblyContext.LoadFromStream(assemblyStream, pdbStream);

            Debug.Assert(_appAssembly != null);
        }
        catch (Exception e)
        {
            Console.WriteLine($"Fehler: {e}");
        }
    }
    
    /// <summary>
    /// Called by the engine to unload the assembly (containing user scripts).
    /// </summary>
    [UnmanagedCallersOnly]
    public static void UnloadAssemblies()
    {
        _scriptAssemblyContext?.Unload();
        _scriptAssemblyContext = null;
    }

    private static NativeScriptClassInfo[]? _unsafeClasses;

    public struct NativeScriptClassInfo
    {
        public IntPtr Name;
        public Guid Guid;
        public ScriptMethods Methods;
        public bool RunInEditMode;
    }

    [Flags]
    public enum ScriptMethods
    {
        None = 0,
        OnCreate = 0x1,
        OnUpdate = 0x2,
        OnDestroy = 0x4
    }

    /// <summary>
    /// Called by the engine to receive a list of all script classes.
    /// </summary>
    /// <param name="outBuffer">Pointer to the array of <see cref="NativeScriptClassInfo"/>s</param>
    /// <param name="length">The number of elements in <see cref="outBuffer"/></param>
    /// <remarks>
    /// The array returned by <see cref="outBuffer"/> must be freed using <see cref="FreeScriptClassNames"/>.
    /// </remarks>
    [UnmanagedCallersOnly]
    public static void GetScriptClasses(NativeScriptClassInfo** outBuffer, long* length)
    {
        using var contextualReflection = AssemblyLoadContext.EnterContextualReflection(_appAssembly);

        Debug.Assert(_appAssembly != null);

        Internal_FreeScriptClassNames();

        var types = _appAssembly.GetTypes();

        List<(string Name, Guid Guid, ScriptMethods AvailableMethods, bool runInEditMode)> scriptClasses = new();

        foreach (var type in types)
        {
            if (type.IsSubclassOf(typeof(Entity)))
            {
                string? name = type.FullName;

                if (name == null)
                    continue;

                Guid guid = type.GUID;

                ScriptMethods methods = ScriptMethods.None;

                static ScriptMethods HasMethod(Type type, string methodName, ScriptMethods methodFlag)
                {
                    MethodInfo? methodInfo = type.GetMethod(methodName, BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.DeclaredOnly);

                    return methodInfo != null ? methodFlag : ScriptMethods.None;
                }

                methods |= HasMethod(type, nameof(Entity.OnCreate), ScriptMethods.OnCreate);
                methods |= HasMethod(type, nameof(Entity.OnUpdate), ScriptMethods.OnUpdate);
                methods |= HasMethod(type, nameof(Entity.OnDestroy), ScriptMethods.OnDestroy);

                bool runInEditMode = type.HasCustomAttribute<RunInEditModeAttribute>();

                scriptClasses.Add((name, guid, methods, runInEditMode));
            }
        }

        _unsafeClasses = new NativeScriptClassInfo[scriptClasses.Count];

        for (int i = 0; i < _unsafeClasses.Length; i++)
        {
            _unsafeClasses[i] = new NativeScriptClassInfo()
            {
                Guid = scriptClasses[i].Guid,
                Name = Marshal.StringToCoTaskMemUTF8(scriptClasses[i].Name),
                Methods = scriptClasses[i].AvailableMethods,
                RunInEditMode = scriptClasses[i].runInEditMode
            };
        }

        *outBuffer = (NativeScriptClassInfo*)Marshal.UnsafeAddrOfPinnedArrayElement(_unsafeClasses, 0);
        *length = _unsafeClasses.Length;
    }

    /// <summary>
    /// Called by the engine to free the data allocated by <see cref="GetScriptClasses"/>
    /// </summary>
    [UnmanagedCallersOnly]
    public static void FreeScriptClassNames()
    {
        Internal_FreeScriptClassNames();
    }

    private static void Internal_FreeScriptClassNames()
    {
        if (_unsafeClasses == null)
            return;

        foreach (NativeScriptClassInfo info in _unsafeClasses)
        {
            Marshal.FreeCoTaskMem(info.Name);
        }

        _unsafeClasses = null;
    }

    [UnmanagedCallersOnly]
    public static void ShowEntityEditor(UUID entityId)
    {
        try
        {
            (Entity entity, Type type) = EntityScriptInstances[entityId];
            EntityEditor.ShowEntityEditor(entity);
        }
        catch (Exception e)
        {
            Console.WriteLine(e);
            // TODO: Log exceptions to console
        }
    }

    [UnmanagedCallersOnly]
    public static void InvokeEntityOnCreate(UUID entityId)
    {
        try
        {
            (Entity entity, Type type) = EntityScriptInstances[entityId];
            entity.OnCreate();
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }

    [UnmanagedCallersOnly]
    public static void InvokeEntityOnUpdate(UUID entityId, float deltaTime)
    {
        try
        {
            (Entity entity, Type type) = EntityScriptInstances[entityId];
            entity.OnUpdate(deltaTime);
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }

    [UnmanagedCallersOnly]
    public static void InvokeEntityOnDestroy(UUID entityId, byte callDestroy)
    {
        try
        {
            if (EntityScriptInstances.Remove(entityId, out var match) && callDestroy > 0)
            {
                match.Entity.OnDestroy();
            }
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }

    internal static Type? GetTypeFromNativeString(byte* fullTypeName)
    {
        if (fullTypeName == null)
            return null;

        using var _ = AssemblyLoadContext.EnterContextualReflection(_appAssembly);

        Debug.Assert(_appAssembly != null);

        string? typeName = Marshal.PtrToStringUTF8((IntPtr)fullTypeName);

        Debug.Assert(typeName != null);

        return _appAssembly.GetType(typeName);
    }

    [UnmanagedCallersOnly]
    public static void CreateScriptInstance(UUID entityId, byte* scriptClassName)
    {
        Log.Info("Exception");

        Type? scriptType = GetTypeFromNativeString(scriptClassName);

        Debug.Assert(scriptType != null, "Script class Type not found.");

        Entity? scriptInstance = ActivatorExtension.CreateEngineObject(scriptType, entityId) as Entity;

        Debug.Assert(scriptInstance != null, "Failed to create script instance.");

        EntityScriptInstances.Add(entityId, (scriptInstance!, scriptType));
    }

    struct ComponentFunctionPointers
    {
        public delegate* unmanaged[Cdecl]<UUID, void> AddComponent;
        public delegate* unmanaged[Cdecl]<UUID, bool> HasComponent;
        public delegate* unmanaged[Cdecl]<UUID, void> RemoveComponent;
    }

    private static readonly Dictionary<Type, ComponentFunctionPointers> ComponentTypeFunctions = new();

    [UnmanagedCallersOnly]
    public static void RegisterComponentType(byte* fullComponentTypeName,
        delegate* unmanaged[Cdecl]<UUID, void> addComponent,
        delegate* unmanaged[Cdecl]<UUID, bool> hasComponent,
        delegate* unmanaged[Cdecl]<UUID, void> removeComponent)
    {
        string? beefComponentTypeName = Marshal.PtrToStringUTF8((IntPtr)fullComponentTypeName);

        if (beefComponentTypeName == null)
            return;

        foreach(Type componentType in TypeExtension.FindDerivedTypes(typeof(Component)))
        {
            if (!componentType.TryGetCustomAttribute(out EngineClassAttribute mapping) ||
                mapping.EngineClassName != beefComponentTypeName) continue;
            
            ComponentTypeFunctions[componentType] = new ComponentFunctionPointers
            {
                AddComponent = addComponent,
                HasComponent = hasComponent,
                RemoveComponent = removeComponent
            };

            return;
        }

        Log.Error($"Failed to register component type \"{beefComponentTypeName}\": No matching component class found.");
    }
    
    [UnmanagedCallersOnly]
    internal static void ThrowException(IntPtr message)
    {
        throw new Exception(Marshal.PtrToStringUTF8(message));
    }

    #region EntitySerializer

    [UnmanagedCallersOnly]
    public static void CreateSerializationContext(IntPtr engineSerializer)
    {
        EntitySerializer.CreateSerializationContext(engineSerializer);
    }

    [UnmanagedCallersOnly]
    public static void DestroySerializationContext(IntPtr engineSerializer)
    {
        EntitySerializer.DestroySerializationContext(engineSerializer);
    }
    
    [UnmanagedCallersOnly]
    public static void EntitySerializer_Serialize(UUID entityId, IntPtr engineObject, IntPtr engineSerializer)
    {
        if (!EntityScriptInstances.TryGetValue(entityId, out var match))
            return;

        EntitySerializer.Serialize(match.Entity, engineObject, engineSerializer);
    }
    
    [UnmanagedCallersOnly]
    public static void EntitySerializer_Deserialize(UUID entityId, IntPtr engineObject, IntPtr engineSerializer)
    {
        if (!EntityScriptInstances.TryGetValue(entityId, out var match))
            return;

        EntitySerializer.Deserialize(match.Entity, engineObject, engineSerializer);
    }
    
    [UnmanagedCallersOnly]
    public static void EntitySerializer_SerializeStaticFields(byte* fullTypeName, IntPtr engineObject, IntPtr engineSerializer)
    {
        Type? type = GetTypeFromNativeString(fullTypeName);
        Debug.Assert(type != null);

        EntitySerializer.SerializeStaticFields(type, engineObject, engineSerializer);
    }
    
    [UnmanagedCallersOnly]
    public static void EntitySerializer_DeserializeStaticFields(byte* fullTypeName, IntPtr engineObject, IntPtr engineSerializer)
    {
        Type? type = GetTypeFromNativeString(fullTypeName);
        Debug.Assert(type != null);

        EntitySerializer.DeserializeStaticFields(type, engineObject, engineSerializer);
    }

    #endregion EntitySerializer

    #endregion

    public static void Entity_AddComponent(UUID entityId, Type componentType)
    {
        ComponentTypeFunctions[componentType].AddComponent(entityId);
    }

    public static bool Entity_HasComponent(UUID entityId, Type componentType)
    {
        return ComponentTypeFunctions[componentType].HasComponent(entityId);
    }
    
    public static void Entity_RemoveComponent(UUID entityId, Type componentType)
    {
        ComponentTypeFunctions[componentType].RemoveComponent(entityId);
    }

    public static void Entity_GetScriptInstance(UUID entityId, out Entity? instance)
    {
        // We currently can implement this method here, because we only have C# scripts.
        // If we ever need to do something to interop with other script languages, then this would change.
        if (EntityScriptInstances.TryGetValue(entityId, out var match))
        {
            instance = match.Entity;
        }

        instance = null;
    }

    public static void Serialization_SerializeField(IntPtr serializationContext, SerializationType type, string fieldName, object? valueObject, string fullTypeName)
    {
        byte* fieldNameConverted = (byte*)Marshal.StringToCoTaskMemUTF8(fieldName);
        byte* fullTypeNameConverted = (byte*)Marshal.StringToCoTaskMemUTF8(fullTypeName);

        void* valueObjectConverted = null;
        bool deleteValueObject = false;

        switch (type)
        {
            case SerializationType.String:
                valueObjectConverted = (void*)Marshal.StringToCoTaskMemUTF8(fullTypeName);
                deleteValueObject = true;
                break;
            default:
                if (valueObject is not null)
                {
                    void* p = &valueObject;
                    // Skip Object Header (IntPtr) + Method Table (IntPtr) 
                    valueObjectConverted = (byte*)*(IntPtr*)p + sizeof(IntPtr);
                    float i = *(float*)valueObjectConverted;
                }
                break;
        }
        
        _engineFunctions.Serialization_SerializeField((void*)serializationContext, type, fieldNameConverted, valueObjectConverted, fullTypeNameConverted);

        Marshal.FreeCoTaskMem((IntPtr)fieldNameConverted);
        Marshal.FreeCoTaskMem((IntPtr)fullTypeNameConverted);

        if (deleteValueObject)
            Marshal.FreeCoTaskMem((IntPtr)valueObjectConverted);
    }
}
