using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
using System.Numerics;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Loader;
using GlitchyEngine.Core;
using GlitchyEngine.Editor;
using GlitchyEngine.Extensions;
using GlitchyEngine.Graphics;
using GlitchyEngine.Graphics.Text;
using GlitchyEngine.Math;
using GlitchyEngine.Physics;
using GlitchyEngine.Serialization;
using ImGuiNET;

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
            Console.WriteLine(e);
            // TODO: Log exceptions to console
        }
    }

    [UnmanagedCallersOnly]
    public static void InvokeEntityOnUpdate(UUID entityId, float deltaTime)
    {
        // using var _ = AssemblyLoadContext.EnterContextualReflection(_appAssembly); // TODO: Check if reflection works correctly in entities

        (Entity entity, Type type) = EntityScriptInstances[entityId];
        entity.OnUpdate(deltaTime);
    }

    [UnmanagedCallersOnly]
    public static void InvokeEntityOnDestroy(UUID entityId, float deltaTime)
    {
        (Entity entity, Type type) = EntityScriptInstances[entityId];
        entity.OnDestroy();
    }

    [UnmanagedCallersOnly]
    public static void CreateScriptInstance(UUID entityId, byte* scriptClassName)
    {
        using var _ = AssemblyLoadContext.EnterContextualReflection(_appAssembly);

        Debug.Assert(_appAssembly != null);

        string? typeName = Marshal.PtrToStringUTF8((IntPtr)scriptClassName);

        Debug.Assert(typeName != null);

        Type? scriptType = _appAssembly.GetType(typeName);

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

            break;
        }
    }

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
                    valueObjectConverted = Unsafe.AsPointer(ref Unsafe.Unbox<byte>(valueObject));
                break;
        }
        
        _engineFunctions.Serialization_SerializeField((void*)serializationContext, type, fieldNameConverted, valueObjectConverted, fullTypeNameConverted);

        Marshal.FreeCoTaskMem((IntPtr)fieldNameConverted);
        Marshal.FreeCoTaskMem((IntPtr)fullTypeNameConverted);

        if (deleteValueObject)
            Marshal.FreeCoTaskMem((IntPtr)valueObjectConverted);
    }

//#region Log

//    //public unsafe static void Log_LogMessage(GlitchyEngine.Log.LogLevel logLevel, string messagePtr, string fileNamePtr, int lineNumber)
//    //{
//    //     fixed (char* messagePtrConverted = messagePtr) {
//    //         fixed (char* fileNamePtrConverted = fileNamePtr) {
//    //             _engineFunctions.Log_LogMessage(logLevel, messagePtrConverted, fileNamePtrConverted, lineNumber);
//    //         }
//    //     }
//    //
//    //
//    //}
//     //internal static unsafe void Log_LogMessage(Log.LogLevel logLevel, string message, string filePath, int line)
//     //{
//    //     // unsafe
//    //     // {
//    //     //     byte* mess = (byte*)Marshal.StringToCoTaskMemUTF8(message);
//    //     //
//    //     //     fixed (char* messagePtr = message)
//    //     //     fixed (char* filePathPtr = filePath)
//    //     //     {
//    //     //         _engineFunctions.Log_LogMessage(logLevel, messagePtr, filePathPtr, line);
//    //     //     }
//    //     //
//    //     //     Marshal.FreeCoTaskMem((IntPtr)mess);
//    //     // }
//     //}


//    [MethodImpl(MethodImplOptions.InternalCall)]
//    public static extern void Log_LogException(Exception exception);

//#endregion

//#region Entity

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Entity_Create(object scriptInstance, string? entityName, Type[]? componentTypes, out UUID entityId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Entity_Destroy(UUID entityId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Entity_CreateInstance(UUID entityId, out UUID newEntityId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Entity_AddComponent(UUID entityId, Type componentType);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Entity_AddComponents(UUID entityId, Type[] componentTypes);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool Entity_HasComponent(UUID entityId, Type componentType);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Entity_RemoveComponent(UUID entityId, Type componentType);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Entity_FindEntityWithName(string name, out UUID uuid);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Entity_GetScriptInstance(UUID entityId, out object? instance);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern object Entity_SetScript(UUID entityId, Type scriptType);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Entity_RemoveScript(UUID entityId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    public static extern string Entity_GetName(UUID entityId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    public static extern string Entity_SetName(UUID entityId, string name);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    public static extern void Entity_GetEditorFlags(UUID uuid, out EditorFlags flags);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    public static extern void Entity_SetEditorFlags(UUID uuid, EditorFlags editorFlags);

//#endregion Entity

//#region TransformComponent

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_GetParent(UUID entityId, out UUID parentId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_SetParent(UUID entityId, in UUID parentId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_GetTranslation(UUID entityId, out float3 translation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_SetTranslation(UUID entityId, in float3 translation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_GetWorldTranslation(UUID entityId, out float3 translation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_SetWorldTranslation(UUID entityId, in float3 translation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_GetRotation(UUID entityId, out Quaternion rotation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_SetRotation(UUID entityId, in Quaternion rotation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_GetRotationEuler(UUID entityId, out float3 rotationEuler);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_SetRotationEuler(UUID entityId, in float3 rotationEuler);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_GetRotationAxisAngle(UUID entityId, out RotationAxisAngle translation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_SetRotationAxisAngle(UUID entityId, RotationAxisAngle translation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_GetScale(UUID entityId, out float3 scale);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Transform_SetScale(UUID entityId, in float3 scale);

//#endregion TransformComponent

//#region RigidBody2D

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_ApplyForce(UUID entityId, in float2 force, float2 point, bool wakeUp);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_ApplyForceToCenter(UUID entityId, in float2 force, bool wakeUp);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_SetPosition(UUID entityId, in float2 position);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_GetPosition(UUID entityId, out float2 position);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_SetRotation(UUID entityId, in float rotation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_GetRotation(UUID entityId, out float rotation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_SetLinearVelocity(UUID entityId, in float2 velocity);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_GetLinearVelocity(UUID entityId, out float2 velocity);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_SetAngularVelocity(UUID entityId, in float velocity);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_GetAngularVelocity(UUID entityId, out float velocity);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_GetBodyType(UUID entityId, out BodyType bodyType);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_SetBodyType(UUID entityId, in BodyType bodyType);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_IsFixedRotation(UUID entityId, out bool isFixedRotation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_SetFixedRotation(UUID entityId, in bool isFixedRotation);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_GetGravityScale(UUID entityId, out float gravityScale);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Rigidbody2D_SetGravityScale(UUID entityId, in float gravityScale);

//#endregion RigidBody2D

//#region Camera

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_GetProjectionType(UUID entityId, out ProjectionType projectionType);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_SetProjectionType(UUID entityId, in ProjectionType projectionType);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_GetPerspectiveFovY(UUID entityId, out float fovY);
//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_SetPerspectiveFovY(UUID entityId, float fovY);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_GetPerspectiveNearPlane(UUID entityId, out float nearPlane);
//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_SetPerspectiveNearPlane(UUID entityId, float nearPlane);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_GetPerspectiveFarPlane(UUID entityId, out float farPlane);
//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_SetPerspectiveFarPlane(UUID entityId, float farPlane);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_GetOrthographicHeight(UUID entityId, out float height);
//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_SetOrthographicHeight(UUID entityId, float height);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_GetOrthographicNearPlane(UUID entityId, out float nearPlane);
//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_SetOrthographicNearPlane(UUID entityId, float nearPlane);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_GetOrthographicFarPlane(UUID entityId, out float farPlane);
//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_SetOrthographicFarPlane(UUID entityId, float farPlane);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_GetAspectRatio(UUID entityId, out float aspectRatio);
//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_SetAspectRatio(UUID entityId, float aspectRatio);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_GetFixedAspectRatio(UUID entityId, out bool fixedAspectRatio);
//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Camera_SetFixedAspectRatio(UUID entityId, bool fixedAspectRatio);


//#endregion

//#region Physics2D

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Physics2D_GetGravity(out float2 gravity);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Physics2D_SetGravity(in float2 gravity);

//#endregion Physics2D

//#region CircleRenderer

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void CircleRenderer_GetColor(UUID entityId, out ColorRGBA color);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void CircleRenderer_SetColor(UUID entityId, ColorRGBA color);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void CircleRenderer_GetUvTransform(UUID entityId, out float4 uvTransform);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void CircleRenderer_SetUvTransform(UUID entityId, float4 uvTransform);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void CircleRenderer_GetInnerRadius(UUID entityId, out float innerRadius);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void CircleRenderer_SetInnerRadius(UUID entityId, float innerRadius);

//#endregion

//#region SpriteRenderer

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void SpriteRenderer_GetColor(UUID entityId, out ColorRGBA color);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void SpriteRenderer_SetColor(UUID entityId, ColorRGBA color);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void SpriteRenderer_GetUvTransform(UUID entityId, out UVTransform uvTransform);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void SpriteRenderer_SetUvTransform(UUID entityId, UVTransform uvTransform);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void SpriteRenderer_GetMaterial(UUID entityId, out UUID materialId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void SpriteRenderer_SetMaterial(UUID entityId, UUID materialId);

//#endregion

//#region TextRenderer

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool TextRenderer_GetIsRichText(UUID entityId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void TextRenderer_SetIsRichText(UUID entityId, bool isRichText);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void TextRenderer_GetText(UUID entityId, out string text);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void TextRenderer_SetText(UUID entityId, string text);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void TextRenderer_GetColor(UUID entityId, out ColorRGBA color);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void TextRenderer_SetColor(UUID entityId, ColorRGBA color);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void TextRenderer_GetHorizontalAlignment(UUID entityId, out HorizontalTextAlignment horizontalAlignment);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void TextRenderer_SetHorizontalAlignment(UUID entityId, HorizontalTextAlignment horizontalAlignment);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void TextRenderer_GetFontSize(UUID uuid, out float fontSize);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void TextRenderer_SetFontSize(UUID uuid, float fontSize);

//#endregion

//#region MeshRenderer

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void MeshRenderer_GetMaterial(UUID entityId, out UUID materialId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void MeshRenderer_SetMaterial(UUID entityId, UUID materialId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void MeshRenderer_GetSharedMaterial(UUID entityId, out UUID materialId);

//#endregion

//#region Math

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern float modf_float(float x, out float integerPart);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern float2 modf_float2(float2 x, out float2 integerPart);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern float3 modf_float3(float3 x, out float3 integerPart);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern float4 modf_float4(float4 x, out float4 integerPart);

//#endregion

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void UUID_CreateNew(out UUID uuid);

//#region Application

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool Application_IsEditor();

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool Application_IsPlayer();

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool Application_IsInEditMode();

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool Application_IsInPlayMode();

//#endregion

//#region Serialization

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Serialization_SerializeField(IntPtr serializationContext, SerializationType type, string name, object? value, string? fullTypeName = null);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Serialization_CreateObject(IntPtr currentContext, bool isStatic, string fullTypeName, out IntPtr context, out UUID id);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    public static extern unsafe void Serialization_DeserializeField(IntPtr internalContext, SerializationType expectedType, string fieldName, byte* value, out SerializationType actualType);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    public static extern void Serialization_GetObject(IntPtr internalContext, UUID id, out IntPtr objectContext);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    public static extern void Serialization_GetObjectTypeName(IntPtr internalContext, out string fullTypeName);

//#endregion

//#region Asset

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Asset_GetIdentifier(UUID assetId, out string text);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void Asset_SetIdentifier(UUID assetId, string text);

//#endregion

//#region Material

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern unsafe bool Material_SetVariable(UUID assetId, string variableName, Material.ShaderVariableType elementType, int rows, int columns, int arrayLength, void* rawData, int dataLength);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool Material_ResetVariable(UUID assetId, string variableName);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool Material_SetTexture(UUID materialId, string textureName, UUID textureId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool Material_GetTexture(UUID materialId, string textureName, out UUID textureId);

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool Material_ResetTexture(UUID materialId, string textureName);

//#endregion

//#region ImGui

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern void ImGuiExtension_ListElementGrabber();

//    [MethodImpl(MethodImplOptions.InternalCall)]
//    internal static extern bool ImGuiExtension_ShowAssetDropTarget(ref UUID assetId);

//#endregion
}
