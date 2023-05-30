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
        
        _rigidBody ??= GetComponent<RigidBody2D>() ?? AddComponent<RigidBody2D>();
    }
    
    /// <summary>
    /// Called every frame.
    /// </summary>
    /// <param name="deltaTime"></param>
    void OnUpdate(float deltaTime)
    {
        Vector2 force = Vector2.Zero;

        if (Input.IsKeyPressed(Key.A))
        {
            force.X -= 1000 * deltaTime;
        }

        if (Input.IsKeyPressed(Key.D))
        {
            force.X += 1000 * deltaTime;
        }

        if (Input.IsKeyPressing(Key.Space))
        {
            force.Y += 2000;
        }

        _rigidBody.ApplyForceToCenter(force);

        //if (Input.IsMouseButtonReleasing(MouseButton.MiddleButton))
        //{
        //    Log.Info("Ouha!");
        //    Physics2D.Gravity *= new Vector2(1, -1);
        //}
    }

    /// <summary>
    /// Called before the component is being destroyed.
    /// </summary>
    void OnDestroy()
    {
        Log.Trace("Destroy");
    }
}
