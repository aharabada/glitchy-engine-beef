using GlitchyEngine.Core;

namespace GlitchyEngine;

public abstract class Component
{
    public Entity Entity { get; internal set; }
}