using System;
using GlitchyEngine.Math;

namespace GlitchyEngine;

class MyTestEntity : Entity
{
    RigidBody2D _rigidBody;

    /// <summary>
    /// Called after the script component was created. (The entity might not be fully created yet)
    /// </summary>
    void OnCreate()
    {
        Log.Info($"Create! {UUID}");

        //_rigidBody = GetComponent<RigidBody2D>();
        RemoveComponent<RigidBody2D>();
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
        //Vector2 force = Vector2.Zero;

        //if (Input.IsKeyPressed(Key.A))
        //{
        //    force.X -= 1000 * deltaTime;
        //}

        //if (Input.IsKeyPressed(Key.D))
        //{
        //    force.X += 1000 * deltaTime;
        //}

        //if (Input.IsKeyPressing(Key.Space))
        //{
        //    force.Y += 2000;
        //}

        //_rigidBody.ApplyForceToCenter(force);

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
