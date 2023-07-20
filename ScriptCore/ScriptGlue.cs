using System;
using System.Runtime.CompilerServices;
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

}
