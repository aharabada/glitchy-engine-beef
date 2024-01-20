using System;
using System.Runtime.CompilerServices;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using GlitchyEngine.Serialization;

namespace GlitchyEngine;

/// <summary>
/// All methods in here are glued to the ScriptGlue.bf in the engine.
/// </summary>
internal static class ScriptGlue
{
#region Log
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Log_LogMessage(Log.LogLevel logLevel, string message, string filePath, int line);
    

    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern void Log_LogException(Exception exception);

#endregion

#region Entity

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_Create(object scriptInstance, string? entityName, Type[]? componentTypes, out UUID entityId);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_Destroy(UUID entityId);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_CreateInstance(UUID entityId, out UUID newEntityId);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_AddComponent(UUID entityId, Type componentType);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_AddComponents(UUID entityId, Type[] componentTypes);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern bool Entity_HasComponent(UUID entityId, Type componentType);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_RemoveComponent(UUID entityId, Type componentType);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_FindEntityWithName(string name, out UUID uuid);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_GetScriptInstance(UUID entityId, out object? instance);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern object Entity_SetScript(UUID entityId, Type scriptType);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_RemoveScript(UUID entityId);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern string Entity_GetName(UUID entityId);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern string Entity_SetName(UUID entityId, string name);
    
#endregion Entity

#region TransformComponent

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Transform_GetTranslation(UUID entityId, out float3 translation);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Transform_SetTranslation(UUID entityId, in float3 translation);

#endregion TransformComponent

#region RigidBody2D
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_ApplyForce(UUID entityId, in float2 force, float2 point, bool wakeUp);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_ApplyForceToCenter(UUID entityId, in float2 force, bool wakeUp);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_SetPosition(UUID entityId, in float2 position);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_GetPosition(UUID entityId, out float2 position);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_SetRotation(UUID entityId, in float rotation);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_GetRotation(UUID entityId, out float rotation);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_SetLinearVelocity(UUID entityId, in float2 velocity);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_GetLinearVelocity(UUID entityId, out float2 velocity);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_SetAngularVelocity(UUID entityId, in float velocity);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Rigidbody2D_GetAngularVelocity(UUID entityId, out float velocity);

#endregion RigidBody2D

#region Camera
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_GetProjectionType(UUID entityId, out ProjectionType projectionType);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_SetProjectionType(UUID entityId, in ProjectionType projectionType);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_GetPerspectiveFovY(UUID entityId, out float fovY);
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_SetPerspectiveFovY(UUID entityId, float fovY);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_GetPerspectiveNearPlane(UUID entityId, out float nearPlane);
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_SetPerspectiveNearPlane(UUID entityId, float nearPlane);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_GetPerspectiveFarPlane(UUID entityId, out float farPlane);
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_SetPerspectiveFarPlane(UUID entityId, float farPlane);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_GetOrthographicHeight(UUID entityId, out float height);
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_SetOrthographicHeight(UUID entityId, float height);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_GetOrthographicNearPlane(UUID entityId, out float nearPlane);
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_SetOrthographicNearPlane(UUID entityId, float nearPlane);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_GetOrthographicFarPlane(UUID entityId, out float farPlane);
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_SetOrthographicFarPlane(UUID entityId, float farPlane);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_GetAspectRatio(UUID entityId, out float aspectRatio);
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_SetAspectRatio(UUID entityId, float aspectRatio);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_GetFixedAspectRatio(UUID entityId, out bool fixedAspectRatio);
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Camera_SetFixedAspectRatio(UUID entityId, bool fixedAspectRatio);


#endregion

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
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void UUID_CreateNew(out UUID uuid);

    #region Application

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern bool Application_IsEditor();

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern bool Application_IsPlayer();

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern bool Application_IsInEditMode();

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern bool Application_IsInPlayMode();

    #endregion

    #region Serialization

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Serialization_SerializeField(IntPtr serializationContext, SerializationType type, string name, object? value, string? fullTypeName = null);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Serialization_CreateObject(IntPtr currentContext, string fullTypeName, out IntPtr context, out UUID id);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern unsafe void Serialization_DeserializeField(IntPtr internalContext, SerializationType expectedType, string fieldName, byte* value, out SerializationType actualType);
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern void Serialization_GetObject(IntPtr internalContext, UUID id, out IntPtr objectContext);

    [MethodImpl(MethodImplOptions.InternalCall)]
    public static extern void Serialization_GetObjectTypeName(IntPtr internalContext, out string fullTypeName);

    #endregion
}
