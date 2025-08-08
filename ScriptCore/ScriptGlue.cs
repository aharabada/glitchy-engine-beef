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
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Loader;
using GlitchyEngine.Native;
using GlitchyEngine.Physics;

namespace GlitchyEngine;

/// <summary>
/// Contains functions pointer to engine functions that can be called form scripts.
/// </summary>
[StructLayout(LayoutKind.Sequential)]
internal unsafe partial struct EngineFunctions
{
}

/// <summary>
/// Provides the interface between engine and scripts.
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
        try
        {
            _engineFunctions = *engineFunctions;
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }

    /// <summary>
    /// Called by the engine to load the provided assembly (containing user scripts) and optionally debug symbols.
    /// </summary>
    [UnmanagedCallersOnly]
    public static void LoadScriptAssembly(byte* assemblyData, long assemblyLength, byte* pdbData, long pdbLength)
    {
        try
        {
            using UnmanagedMemoryStream assemblyStream = new(assemblyData, assemblyLength);

            using UnmanagedMemoryStream? pdbStream = (pdbData != null) ? new UnmanagedMemoryStream(pdbData, pdbLength) : null;

            LoadAssembly(assemblyStream, pdbStream);
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }

    private static void LoadAssembly(Stream assemblyStream, Stream? pdbStream)
    {
        _scriptAssemblyContext ??= new AssemblyLoadContext("ScriptContext", true);

        _appAssembly = _scriptAssemblyContext.LoadFromStream(assemblyStream, pdbStream);

        Debug.Assert(_appAssembly != null);
    }
    
    /// <summary>
    /// Called by the engine to unload the assembly (containing user scripts).
    /// </summary>
    [UnmanagedCallersOnly]
    public static void UnloadAssemblies()
    {
        try
        {
            _scriptAssemblyContext?.Unload();
            _scriptAssemblyContext = null;
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
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
        OnDestroy = 0x4,
        OnCollisionEnter2D = 0x8
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
        try
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
                        MethodInfo? methodInfo = null;
                        Type? currentType = type;

                        while (methodInfo == null && currentType != typeof(Entity) && currentType != null)
                        {
                            methodInfo = currentType.GetMethod(methodName,
                                BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.DeclaredOnly);

                            currentType = currentType.BaseType;
                        }

                        return methodInfo != null ? methodFlag : ScriptMethods.None;
                    }

                    methods |= HasMethod(type, nameof(Entity.OnCreate), ScriptMethods.OnCreate);
                    methods |= HasMethod(type, nameof(Entity.OnUpdate), ScriptMethods.OnUpdate);
                    methods |= HasMethod(type, nameof(Entity.OnDestroy), ScriptMethods.OnDestroy);
                    methods |= HasMethod(type, nameof(Entity.OnCollisionEnter2D), ScriptMethods.OnCollisionEnter2D);

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
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }

    /// <summary>
    /// Called by the engine to free the data allocated by <see cref="GetScriptClasses"/>
    /// </summary>
    [UnmanagedCallersOnly]
    public static void FreeScriptClassNames()
    {
        try
        {
            Internal_FreeScriptClassNames();
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
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
            Log.Exception(e);
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
    
    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvCdecl)])]
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
    
    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvCdecl)])]
    public static void InvokeEntityOnCollisionEnter2D(UUID entityId, Collision2D collision)
    {
        try
        {
            (Entity entity, Type type) = EntityScriptInstances[entityId];
            entity.OnCollisionEnter2D(collision);
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
        try
        {
            Type? scriptType = GetTypeFromNativeString(scriptClassName);

            Debug.Assert(scriptType != null, "Script class Type not found.");

            Entity? scriptInstance = ActivatorExtension.CreateEngineObject(scriptType, entityId) as Entity;

            Debug.Assert(scriptInstance != null, "Failed to create script instance.");

            EntityScriptInstances.Add(entityId, (scriptInstance, scriptType));
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }

    struct ComponentFunctionPointers
    {
        public delegate* unmanaged[Cdecl]<UUID, void> AddComponent;
        public delegate* unmanaged[Cdecl]<UUID, EngineResult> HasComponent;
        public delegate* unmanaged[Cdecl]<UUID, void> RemoveComponent;
    }

    private static readonly Dictionary<Type, ComponentFunctionPointers> ComponentTypeFunctions = new();

    [UnmanagedCallersOnly]
    public static void RegisterComponentType(byte* fullComponentTypeName,
        delegate* unmanaged[Cdecl]<UUID, void> addComponent,
        delegate* unmanaged[Cdecl]<UUID, EngineResult> hasComponent,
        delegate* unmanaged[Cdecl]<UUID, void> removeComponent)
    {
        try
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
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }
    
    #region EntitySerializer

    [UnmanagedCallersOnly]
    public static void CreateSerializationContext(IntPtr engineSerializer)
    {
        try
        {
            EntitySerializer.CreateSerializationContext(engineSerializer);
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }

    [UnmanagedCallersOnly]
    public static void DestroySerializationContext(IntPtr engineSerializer)
    {
        try
        {
            EntitySerializer.DestroySerializationContext(engineSerializer);
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }
    
    [UnmanagedCallersOnly]
    public static void EntitySerializer_Serialize(UUID entityId, IntPtr engineObject, IntPtr engineSerializer)
    {
        try
        {
            if (!EntityScriptInstances.TryGetValue(entityId, out var match))
                return;

            EntitySerializer.Serialize(match.Entity, engineObject, engineSerializer);
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }
    
    [UnmanagedCallersOnly]
    public static void EntitySerializer_Deserialize(UUID entityId, IntPtr engineObject, IntPtr engineSerializer)
    {
        try
        {
            if (!EntityScriptInstances.TryGetValue(entityId, out var match))
                return;

            EntitySerializer.Deserialize(match.Entity, engineObject, engineSerializer);
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }
    
    [UnmanagedCallersOnly]
    public static void EntitySerializer_SerializeStaticFields(byte* fullTypeName, IntPtr engineObject, IntPtr engineSerializer)
    {
        try
        {
            Type? type = GetTypeFromNativeString(fullTypeName);
            Debug.Assert(type != null);

            EntitySerializer.SerializeStaticFields(type, engineObject, engineSerializer);
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }
    
    [UnmanagedCallersOnly]
    public static void EntitySerializer_DeserializeStaticFields(byte* fullTypeName, IntPtr engineObject, IntPtr engineSerializer)
    {
        try
        {
            Type? type = GetTypeFromNativeString(fullTypeName);
            Debug.Assert(type != null);

            EntitySerializer.DeserializeStaticFields(type, engineObject, engineSerializer);
        }
        catch (Exception e)
        {
            Log.Exception(e);
        }
    }

    #endregion EntitySerializer

    #endregion

    #region Custom engine call implementations

    public static void Entity_AddComponent(UUID entityId, Type componentType)
    {
        ComponentTypeFunctions[componentType].AddComponent(entityId);
    }

    public static bool Entity_HasComponent(UUID entityId, Type componentType)
    {
        EngineResult returnValue = ComponentTypeFunctions[componentType].HasComponent(entityId);
        EngineErrors.ThrowIfError(returnValue);
        return returnValue == EngineResult.Ok;
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
        StringView fieldNameConverted = StringView.FromManagedString(fieldName);
        StringView fullTypeNameConverted = StringView.FromManagedString(fullTypeName);

        void* valueObjectConverted = null;
        bool deleteValueObject = false;

        switch (type)
        {
            case SerializationType.String:
            case SerializationType.Enum:
                if (valueObject is string stringValue)
                {
                    StringView nativeString = StringView.FromManagedString(stringValue);
                    valueObjectConverted = nativeString.Utf8Ptr;
                    deleteValueObject = true;
                }
                break;
            default:
                if (valueObject is not null)
                {
#pragma warning disable CS8500 // This takes the address of, gets the size of, or declares a pointer to a managed type
                    object?* objectRef = &valueObject;
                    // Skip Object Header (IntPtr) + Method Table (IntPtr) 
                    valueObjectConverted = (byte*)*(IntPtr*)objectRef + sizeof(IntPtr);
                }
                break;
        }
        
        _engineFunctions.Serialization_SerializeField((void*)serializationContext, type, fieldNameConverted, valueObjectConverted, fullTypeNameConverted);
        
        NativeMemory.Free(fieldNameConverted.Utf8Ptr);
        NativeMemory.Free(fullTypeNameConverted.Utf8Ptr);

        if (deleteValueObject)
            NativeMemory.Free(valueObjectConverted);
    }

    #endregion Custom engine call implementations
}
