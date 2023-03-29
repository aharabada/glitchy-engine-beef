using System.Runtime.CompilerServices;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine;

/// <summary>
/// All methods in here are glued to the ScriptGlue.bf in the engine.
/// </summary>
internal static class ScriptGlue
{
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_GetTranslation(UUID entityId, out Vector3 translation);
    [MethodImpl(MethodImplOptions.InternalCall)]
    internal static extern void Entity_SetTranslation(UUID entityId, in Vector3 translation);
}
