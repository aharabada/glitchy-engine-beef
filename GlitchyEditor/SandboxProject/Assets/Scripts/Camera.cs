using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using GlitchyEngine;
using GlitchyEngine.Math;

namespace Sandbox;
public class Camera : Entity
{
    public float DistanceFromPlayer = 5.0f;

    public float DontFollowRadius = 3.0f;

    void OnUpdate(float deltaTime)
    {
        Entity player = FindEntityWithName("Player");

        if (player != null)
        {
            Vector2 playerPosition = new Vector2(player.Transform.Translation.X, player.Transform.Translation.Y);

            Vector2 cameraPosition = new Vector2(Transform.Translation.X, Transform.Translation.Y);

            Vector2 distanceVector = playerPosition - cameraPosition;

            float distance = distanceVector.Length();

            Vector2 neededMovement = Vector2.Zero;

            if (distance > DontFollowRadius)
            {
                neededMovement = distanceVector - (distanceVector / distance) * DontFollowRadius;
            }

            Transform.Translation = new Vector3(cameraPosition + neededMovement, DistanceFromPlayer);

            //Transform.Translation = new Vector3(player.Transform.Translation.X, player.Transform.Translation.Y, DistanceFromPlayer);
        }
        else
        {
            Log.Error("Player not found!");
        }
    }
}
