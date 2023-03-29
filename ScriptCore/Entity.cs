using System;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine;

internal struct EntityHandle
{
    public uint Version;
    public uint Index;
}

public abstract class Entity : EngineObject
{
    //private UUID _uuid;

    //public UUID UUID => _uuid;

    ///// <summary>
    ///// Empty constructor not used. Do NOT USE!
    ///// </summary>
    //protected Entity()
    //{}

    //internal Entity(UUID uuid)
    //{
    //    _uuid = uuid;
    //}

    public T GetComponent<T>() where T : Component
    {
        return null;
    }

    //public Transform Transform => new (){_uuid = _uuid};

    public Vector3 Translation
    {
        get
        {
            ScriptGlue.Entity_GetTranslation(_uuid, out Vector3 translation);
            return translation;
        }

        set => ScriptGlue.Entity_SetTranslation(_uuid, value);
    }
    
    // Will be executed once after the entity as be created.
    // void OnCreate();

    // Will be executed every frame.
    // void OnUpdate(GameTime);

    // Will be executed once when the entity is being destroyed.
    // void OnDestroy();
}
