using GlitchyEngine.Core;

namespace GlitchyEngine;

public abstract class Component : EngineObject
{
    public Entity Entity => new(_uuid);
}