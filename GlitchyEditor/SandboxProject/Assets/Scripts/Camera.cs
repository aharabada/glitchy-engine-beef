using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using GlitchyEngine;
using GlitchyEngine.Math;

using static GlitchyEngine.Math.Math;

namespace Sandbox;
public class Camera : Entity
{
    public float DistanceFromPlayer = 5.0f;

    public float DontFollowRadius = 3.0f;

    void OnCreate()
    {
        Log.Info("Camera Create");
    }

    public void OnUpdate(float deltaTime)
    {
        Log.Info($"Camera Update {deltaTime}");

        //Entity player = FindEntityWithName("Player");

        //if (player != null)
        //{
        //    float2 playerPosition = player.Transform.Translation.XY;

        //    float2 cameraPosition = Transform.Translation.XY;

        //    float2 distanceVector = playerPosition - cameraPosition;

        //    float distance = length(distanceVector);

        //    float2 neededMovement = float2.Zero;

        //    if (distance > DontFollowRadius)
        //    {
        //        neededMovement = distanceVector - (distanceVector / distance) * DontFollowRadius;
        //    }

        //    Transform.Translation = new float3(cameraPosition + neededMovement, DistanceFromPlayer);
        //}
        //else
        //{
        //    Log.Error("Player not found!");
        //}
    }
}
