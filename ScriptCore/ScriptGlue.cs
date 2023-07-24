using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
using System.Net.Mime;
using System.Net.Security;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Loader;
using System.Text;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine;

/// <summary>
/// All methods in here are glued to the ScriptGlue.bf in the engine.
/// </summary>
internal static class ScriptGlue
{
#region Entity
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_AddComponent(UUID entityId, Type componentType);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern bool Entity_HasComponent(UUID entityId, Type componentType);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_RemoveComponent(UUID entityId, Type componentType);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_FindEntityWithName(string name, out UUID uuid);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern object Entity_GetScriptInstance(UUID entityId);
    
#endregion Entity

#region TransformComponent

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Transform_GetTranslation(UUID entityId, out float3 translation);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Transform_SetTranslation(UUID entityId, in float3 translation);

#endregion TransformComponent

#region RigidBody2D
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void RigidBody2D_ApplyForce(UUID entityId, in float2 force, float2 point, bool wakeUp);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void RigidBody2D_ApplyForceToCenter(UUID entityId, in float2 force, bool wakeUp);

#endregion RigidBody2D

#region Physics2D
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Physics2D_GetGravity(out float2 gravity);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Physics2D_SetGravity(in float2 gravity);

#endregion Physics2D

#region Math
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern float modf_float(float x, out float integerPart);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern float2 modf_float2(float2 x, out float2 integerPart);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern float3 modf_float3(float3 x, out float3 integerPart);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern float4 modf_float4(float4 x, out float4 integerPart);

#endregion
    
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
            
            // Test the loaded assembly
            _appAssembly.GetType("Sandbox.TestClass")?.GetMethod("InternalTest")?.Invoke(null, null);

            AssemblyLoadContext.EnterContextualReflection(_appAssembly);
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
    }

    [Flags]
    public enum ScriptMethods
    {
        None = 0,
        OnCreate = 0x1,
        OnUpdate = 0x2,
        OnDestroy = 0x4,
    }


    [UnmanagedCallersOnly]
    public static unsafe void GetScriptClasses(void** outBuffer, long* length)
    {
        AssemblyLoadContext.EnterContextualReflection(_appAssembly);

        Debug.Assert(_appAssembly != null);
        
        Internal_FreeScriptClassNames();

        var types = _appAssembly.GetTypes();
        
        List<(string Name, Guid Guid, ScriptMethods Methods)> scriptClasses = new();
        
        _updateMethods.Clear();

        foreach (var type in types)
        {
            if (type.IsSubclassOf(typeof(Entity)))
            {
                string? name = type.FullName;

                if (name == null)
                    continue;

                Guid guid = type.GUID;

                ScriptMethods methods = ScriptMethods.None;

                MethodInfo? onUpdateMethod = type.GetMethod("OnUpdate");
                if (onUpdateMethod != null)
                {
                    _updateMethods[type] = onUpdateMethod;

                    methods |= ScriptMethods.OnUpdate;
                }

                scriptClasses.Add((name, guid, methods));
            }
        }

        _unsafeClasses = new NativeScriptClassInfo[scriptClasses.Count];

        for (int i = 0; i < _unsafeClasses.Length; i++)
        {
            _unsafeClasses[i] = new NativeScriptClassInfo()
            {
                Guid = scriptClasses[i].Guid,
                Name = Marshal.StringToCoTaskMemUTF8(scriptClasses[i].Name),
                Methods = scriptClasses[i].Methods
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
    private static Dictionary<Type, MethodInfo> _updateMethods = new();

    public struct ScriptFunctions
    {
        public IntPtr OnCreateMethod;
        public IntPtr OnUpdateMethod;
        public IntPtr OnDestroyMethod;
    }

    // Define delegate with the same signature as your method
    delegate void OnCreateMethodDelegate();

    // Define delegate with the same signature as your method
    delegate void OnUpdateMethodDelegate(float deltaTime);

    [UnmanagedCallersOnly]
    public static void InvokeOnUpdate(UUID entityId, float deltaTime)
    {
        AssemblyLoadContext.EnterContextualReflection(_appAssembly);

        Debug.Assert(_entityScripts.ContainsKey(entityId));

        (Entity Entity, Type Type) entity = _entityScripts[entityId];

        entity.Type.GetMethod("OnUpdate", BindingFlags.NonPublic | BindingFlags.Instance)
            .Invoke(entity.Entity, new object?[]{deltaTime });

    _updateMethods[entity.Type].Invoke(entity.Entity, BindingFlags.NonPublic | BindingFlags.Instance, null,
            new object[] { deltaTime }, null);
    }

    [UnmanagedCallersOnly]
    public static unsafe ScriptFunctions CreateScriptInstance(UUID entityId, byte* scriptClassName)
    {
        AssemblyLoadContext.EnterContextualReflection(_appAssembly);

        Debug.Assert(_appAssembly != null);

        string? typeName = Marshal.PtrToStringUTF8((IntPtr)scriptClassName);

        Debug.Assert(typeName != null);

        Type? scriptType = _appAssembly.GetType(typeName);
        
        Debug.Assert(scriptType != null, "Script class Type not found.");

        //Entity? scriptInstance = Activator.CreateInstance(scriptType, BindingFlags.Instance | BindingFlags.NonPublic, null, entityId) as Entity;
        
        // Get the private constructor
        ConstructorInfo constructor = scriptType.BaseType.GetConstructor(
            BindingFlags.Instance | BindingFlags.NonPublic, 
            null, 
            new Type[] { typeof(UUID) }, // replace this with the types of your constructor parameters
            null);

        // Call the constructor to create an instance
        Entity? scriptInstance = constructor?.Invoke(new object[] { entityId }) as Entity;

        ScriptFunctions functions = new();

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

        //MethodInfo? onUpdateMethod = scriptType.GetMethod("OnUpdate",  BindingFlags.Instance | BindingFlags.NonPublic);
        //if (onUpdateMethod != null)
        //{
        //    // Create the delegate from your method and instance
        //    OnUpdateMethodDelegate onUpdateDelegate = (OnUpdateMethodDelegate)Delegate.CreateDelegate(typeof(OnUpdateMethodDelegate), scriptInstance, onUpdateMethod);

        //    // Get the function pointer from your delegate
        //    functions.OnUpdateMethod = Marshal.GetFunctionPointerForDelegate(onUpdateDelegate);
        //}
        //    //functions.OnUpdateMethod = Marshal.GetFunctionPointerForDelegate((float deltaTime) => onUpdateMethod.Invoke(scriptInstance, new object?[]{ deltaTime }));

        //MethodInfo? onDestroyMethod = scriptType.GetMethod("OnUpdate",  BindingFlags.Instance | BindingFlags.NonPublic);
        //if (onDestroyMethod != null)
        //    functions.OnDestroyMethod = Marshal.GetFunctionPointerForDelegate(() => onDestroyMethod.Invoke(scriptInstance, null));

        return functions;
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
}
