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
    //public delegate* unmanaged[Cdecl]<GlitchyEngine.Log.LogLevel, char*, char*, int, void> Log_LogMessage;
}

/// <summary>
/// All methods in here are glued to the ScriptGlue.bf in the engine.
/// TODO: This could be auto-generated fairly easily
/// </summary>
internal static unsafe partial class ScriptGlue
{
#region Script Glueing infrastructure

    static ScriptGlue()
    {
        NativeLibrary.SetDllImportResolver(typeof(ScriptGlue).Assembly, ImportResolver);
        // TODO: With this we can actually use the official ImGui.NET-Branch in the future!
        NativeLibrary.SetDllImportResolver(typeof(ImGui).Assembly, ImportResolver);
    }

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

    [UnmanagedCallersOnly]
    public static unsafe void SetEngineFunctions(EngineFunctions* engineFunctions)
    {
        _engineFunctions = *engineFunctions;

        Log.Info("Yeah");
    }

    private static AssemblyLoadContext? _scriptAssemblyContext;

    private static Assembly? _appAssembly;

    [UnmanagedCallersOnly]
    public static unsafe void LoadScriptAssembly(byte* assemblyData, long assemblyLength, byte* pdbData, long pdbLength)
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

    [UnmanagedCallersOnly]
    public static void UnloadAssemblies()
    {
        _scriptAssemblyContext?.Unload();
        _scriptAssemblyContext = null;
    }

    struct ScriptClassInfo
    {
        public byte[] Name;
        public Guid Guid;
    }

    private static NativeScriptClassInfo[]? _unsafeClasses;

    struct NativeScriptClassInfo
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

    [UnmanagedCallersOnly]
    public static unsafe void GetScriptClasses(void** outBuffer, long* length)
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

        *outBuffer = (void*)Marshal.UnsafeAddrOfPinnedArrayElement(_unsafeClasses, 0);
        *length = _unsafeClasses.Length;
    }

    [UnmanagedCallersOnly]
    public static void FreeScriptClassNames()
    {
        Internal_FreeScriptClassNames();
    }

    internal static void Internal_FreeScriptClassNames()
    {
        if (_unsafeClasses == null)
            return;

        foreach (NativeScriptClassInfo info in _unsafeClasses)
        {
            Marshal.FreeCoTaskMem(info.Name);
        }

        _unsafeClasses = null;
    }

    private static Dictionary<UUID, (Entity Entity, Type Type)> _entityScripts = new();

    [UnmanagedCallersOnly]
    public static void ShowEntityEditor(UUID entityId)
    {
        (Entity entity, Type type) = _entityScripts[entityId];
        EntityEditor.ShowEntityEditor(entity);
    }

    [UnmanagedCallersOnly]
    public static void InvokeEntityOnCreate(UUID entityId)
    {
        try
        {
            (Entity entity, Type type) = _entityScripts[entityId];
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

        (Entity entity, Type type) = _entityScripts[entityId];
        entity.OnUpdate(deltaTime);
    }

    [UnmanagedCallersOnly]
    public static void InvokeEntityOnDestroy(UUID entityId, float deltaTime)
    {
        (Entity entity, Type type) = _entityScripts[entityId];
        entity.OnDestroy();
    }

    [UnmanagedCallersOnly]
    public static unsafe void CreateScriptInstance(UUID entityId, byte* scriptClassName)
    {
        using var _ = AssemblyLoadContext.EnterContextualReflection(_appAssembly);

        Debug.Assert(_appAssembly != null);

        string? typeName = Marshal.PtrToStringUTF8((IntPtr)scriptClassName);

        Debug.Assert(typeName != null);

        Type? scriptType = _appAssembly.GetType(typeName);

        Debug.Assert(scriptType != null, "Script class Type not found.");

        Entity? scriptInstance = ActivatorExtension.CreateEngineObject(scriptType, entityId) as Entity;

        //
        // // Get the constructor
        // ConstructorInfo? constructor = scriptType.GetConstructor(
        //     BindingFlags.Instance | BindingFlags.Public,
        //     null,
        //     [],
        //     null);
        //
        // Debug.Assert(constructor != null, "Script class constructor not found.");
        //
        // // Call the constructor to create an instance
        // Entity? scriptInstance = constructor?.Invoke(null) as Entity;
        Debug.Assert(scriptInstance != null, "Failed to create script instance.");
        //
        // if (scriptInstance != null)
        //     scriptInstance._uuid = entityId;

        //ScriptFunctions functions = new();

        _entityScripts.Add(entityId, (scriptInstance!, scriptType));

        //MethodInfo? onCreateMethod = scriptType.GetMethod("OnCreate", BindingFlags.Instance | BindingFlags.NonPublic);
        //if (onCreateMethod != null)
        //{
        //    var v = MethodHelpers.GetFunctionPointerForNativeCode(onCreateMethod, null);
        //}
        //if (onCreateMethod != null)
        //{
        //    //Delegate del = CreateDelegateWithTarget(onCreateMethod, scriptInstance);

        //    //var createDelegate = onCreateMethod.CreateDelegate<Action>(scriptInstance);
        //    //var createDelegate = onCreateMethod.CreateDelegate(typeof(OnCreateMethodDelegate), scriptInstance);
        //    //onCreateMethod.CreateDelegate(scriptInstance);

        //    //functions.OnCreateMethod = Marshal.GetFunctionPointerForDelegate(createDelegate);
        //}
        //
        // MethodInfo? onUpdateMethod = scriptType.GetMethod("OnUpdate",  BindingFlags.Instance | BindingFlags.NonPublic);
        // if (onUpdateMethod != null)
        // {
        //     // Create the delegate from your method and instance
        //     OnUpdateMethodDelegate onUpdateDelegate = (OnUpdateMethodDelegate)Delegate.CreateDelegate(typeof(OnUpdateMethodDelegate), scriptInstance, onUpdateMethod);
        //
        //     // Get the function pointer from your delegate
        //     functions.OnUpdateMethod = Marshal.GetFunctionPointerForDelegate(onUpdateDelegate);
        // }


            //functions.OnUpdateMethod = Marshal.GetFunctionPointerForDelegate((float deltaTime) => onUpdateMethod.Invoke(scriptInstance, new object?[]{ deltaTime }));

        //MethodInfo? onDestroyMethod = scriptType.GetMethod("OnUpdate",  BindingFlags.Instance | BindingFlags.NonPublic);
        //if (onDestroyMethod != null)
        //    functions.OnDestroyMethod = Marshal.GetFunctionPointerForDelegate(() => onDestroyMethod.Invoke(scriptInstance, null));

        //return functions;
    }

    static Delegate CreateDelegate(MethodInfo method)
    {
        if (method == null)
        {
            throw new ArgumentNullException(nameof(method));
        }

        if (!method.IsStatic)
        {
            throw new ArgumentException("The provided method must be static.", nameof(method));
        }

        if (method.IsGenericMethod)
        {
            throw new ArgumentException("The provided method must not be generic.", nameof(method));
        }

        return method.CreateDelegate(Expression.GetDelegateType(
            (from parameter in method.GetParameters() select parameter.ParameterType)
            .Concat(new[] { method.ReturnType })
            .ToArray()));
    }

    /// <summary>
    /// Create delegate by methodinfo in target
    /// </summary>
    /// <param name="method">method info</param>
    /// <param name="target">A instance of the object which contains the method where will be execute</param>
    /// <returns>delegate or null</returns>
    public static Delegate? CreateDelegateWithTarget(MethodInfo? method, object? target)
    {
        if (method is null ||
            target is null)
            return null;

        //if (method.IsStatic)
        //    return null;

        if (method.IsGenericMethod)
            return null;

        return method.CreateDelegate(Expression.GetDelegateType(
            (from parameter in method.GetParameters() select parameter.ParameterType)
            .Concat(new[] { method.ReturnType })
            .ToArray()), target);
    }

    internal static class MethodHelpers
    {
        private const string DelegateTypesAssemblyName = "JitDelegateTypes";

        private static ModuleBuilder _modBuilder;

        private static ConcurrentDictionary<(string, object), Delegate> _delegatesCache;
        private static ConcurrentDictionary<string, Type>               _delegateTypesCache;

        static MethodHelpers()
        {
            AssemblyBuilder asmBuilder = AssemblyBuilder.DefineDynamicAssembly(new AssemblyName(DelegateTypesAssemblyName), AssemblyBuilderAccess.Run);

            _modBuilder = asmBuilder.DefineDynamicModule(DelegateTypesAssemblyName);

            _delegatesCache     = new ConcurrentDictionary<(string, object), Delegate>();
            _delegateTypesCache = new ConcurrentDictionary<string, Type>();
        }

        public static IntPtr GetFunctionPointerForNativeCode(MethodInfo meth, object instance = null)
        {
            string funcName = GetFullName(meth);

            Delegate dlg = _delegatesCache.GetOrAdd((funcName, instance), (_) =>
            {
                Type[] parameters = meth.GetParameters().Select(x => x.ParameterType).ToArray();

                Type delegateType = GetDelegateType(parameters, meth.ReturnType);

                return Delegate.CreateDelegate(delegateType, instance, meth);
            });

            return Marshal.GetFunctionPointerForDelegate<Delegate>(dlg);
        }

        private static string GetFullName(MethodInfo meth)
        {
            return $"{meth.DeclaringType.FullName}.{meth.Name}";
        }

        private static Type GetDelegateType(Type[] parameters, Type returnType)
        {
            string key = GetFunctionSignatureKey(parameters, returnType);

            return _delegateTypesCache.GetOrAdd(key, (_) => MakeDelegateType(parameters, returnType, key));
        }

        private const MethodAttributes CtorAttributes =
            MethodAttributes.RTSpecialName |
            MethodAttributes.HideBySig |
            MethodAttributes.Public;

        private const MethodImplAttributes ImplAttributes =
            MethodImplAttributes.Runtime |
            MethodImplAttributes.Managed;

        private const MethodAttributes InvokeAttributes =
            MethodAttributes.Public |
            MethodAttributes.HideBySig |
            MethodAttributes.NewSlot |
            MethodAttributes.Virtual;

        private const TypeAttributes DelegateTypeAttributes =
            TypeAttributes.Class |
            TypeAttributes.Public |
            TypeAttributes.Sealed |
            TypeAttributes.AnsiClass |
            TypeAttributes.AutoClass;

        private static readonly Type[] _delegateCtorSignature = { typeof(object), typeof(IntPtr) };

        private static Type MakeDelegateType(Type[] parameters, Type returnType, string name)
        {
            TypeBuilder builder = _modBuilder.DefineType(name, DelegateTypeAttributes, typeof(MulticastDelegate));

            builder.DefineConstructor(CtorAttributes, CallingConventions.Standard, _delegateCtorSignature).SetImplementationFlags(ImplAttributes);

            builder.DefineMethod("Invoke", InvokeAttributes, returnType, parameters).SetImplementationFlags(ImplAttributes);

            return builder.CreateTypeInfo();
        }

        private static string GetFunctionSignatureKey(Type[] parameters, Type returnType)
        {
            string sig = GetTypeName(returnType);

            foreach (Type type in parameters)
            {
                sig += '_' + GetTypeName(type);
            }

            return sig;
        }

        private static string GetTypeName(Type type)
        {
            return type.FullName.Replace(".", string.Empty);
        }
    }

#endregion


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
