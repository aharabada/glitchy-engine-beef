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

#endregion Entity

#region TransformComponent

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Transform_GetTranslation(UUID entityId, out Vector3 translation);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Transform_SetTranslation(UUID entityId, in Vector3 translation);

#endregion TransformComponent

#region RigidBody2D
    
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void RigidBody2D_ApplyForce(UUID entityId, in Vector2 force, Vector2 point, bool wakeUp);

    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void RigidBody2D_ApplyForceToCenter(UUID entityId, in Vector2 force, bool wakeUp);

#endregion RigidBody2D

}
