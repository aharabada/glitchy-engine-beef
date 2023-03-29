using System;
using GlitchyEngine.Math;

namespace GlitchyEngine;

class MyTestEntity : Entity
{
    //Rigidbody2D _rigidBody;

    /// <summary>
    /// Called after the script component was created. (The entity might not be fully created yet)
    /// </summary>
    void OnCreate()
    {
        Log.Info($"Create! {UUID}");

        //_rigidBody = GetComponent<Rigidbody2D>();
    }

    ///// <summary>
    ///// Called after the entity was created completely.
    ///// </summary>
    //void OnInstantiate()
    //{
    //    Log.Warning($"Instantiated!");
    //}

    /// <summary>
    /// Called every frame.
    /// </summary>
    /// <param name="deltaTime"></param>
    void OnUpdate(float deltaTime)
    {
        if (Input.IsKeyPressed(Key.A))
        {
            Log.Info($"HALLO!");

            Vector3 translation = Translation;
            translation.Y += 1.0f * deltaTime;

            Translation = translation;

            //_rigidBody.ApplyImpulse(new Vector2(0, 10));
        }

        if (Input.IsMouseButtonReleasing(MouseButton.LeftButton))
        {
            Log.Info("Ouha!");
        }
    }

    /// <summary>
    /// Called before the component is being destroyed.
    /// </summary>
    void OnDestroy()
    {
        Log.Trace("Destroy");
    }
}
