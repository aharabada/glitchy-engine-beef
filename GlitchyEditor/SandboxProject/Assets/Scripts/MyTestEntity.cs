using System;
using System.Runtime.Remoting.Metadata.W3cXsd2001;
using GlitchyEngine;
using GlitchyEngine.Editor;
using GlitchyEngine.Math;

using static GlitchyEngine.Math.Math;

namespace Sandbox
{

    public enum MyEnum
    {
        Yes,
        No,
        Maybe
    }

    public struct MyStruct
    {
        public float TheFloat;
        public float2 TheVector;
        public MyEnum TheEnum;
    }

    class MyTestEntity : Entity
    {
        //[ShowInEditor]
        RigidBody2D _rigidBody;

        public bool Bo;

        public byte By;
        public ushort Us;
        public uint Ui;
        public ulong Ul;

        public sbyte Sb;
        public short Sh;
        public int In;
        public long Lo;

        public float Fl;
        public double Do;
        public float2 V2;
        public float3 V3;
        public float4 V4;

        public Entity TheEntity;

        public float JumpForce = 2000;
        [ShowInEditor] float MoveForce = 1000;
        [ShowInEditor] private int MyNumber = 1337;
        [ShowInEditor] public double MyDouble = 1000.0f;

        public MyStruct AStruct;

        public Camera Camera;

        /// <summary>
        /// Called after the script component was created. (The entity might not be fully created yet)
        /// </summary>
        void OnCreate()
        {
            Log.Info($"Create! {UUID}");

            Log.Info($"Jump Force: {JumpForce}");

            _rigidBody ??= GetComponent<RigidBody2D>() ?? AddComponent<RigidBody2D>();

            Camera = FindEntityWithName("Camera").As<Camera>();

            if (Camera == null)
            {
                Log.Error("Camera not found.");
            }
        }

        /// <summary>
        /// Called every frame.
        /// </summary>
        /// <param name="deltaTime"></param>
        void OnUpdate(float deltaTime)
        {
            float2 force = float2.Zero;

            if (Input.IsKeyPressed(Key.A))
            {
                force.X -= MoveForce * deltaTime;
            }

            if (Input.IsKeyPressed(Key.D))
            {
                force.X += MoveForce * deltaTime;
            }

            if (Input.IsKeyPressed(Key.Q))
                Camera.DistanceFromPlayer -= deltaTime;

            if (Input.IsKeyPressed(Key.E))
                Camera.DistanceFromPlayer += deltaTime;

            if (Input.IsKeyPressing(Key.Space))
            {
                force.Y += JumpForce;
            }

            _rigidBody.ApplyForceToCenter(force);

            if (Input.IsMouseButtonReleasing(MouseButton.MiddleButton))
            {
                Log.Info($"Ouha! {MyNumber}");
                Physics2D.Gravity *= new float2(1, -1);
            }

            Test.Test.P();

            float2 f2 = new();

            f2.X = 5;

            Log.Info($"Haleluja! {f2.X}");

            float4 floaty = new float4(f2, f2);
            
            float4 megaFloat = floaty.WXYZ;
            
            if (all(abs(normalize(megaFloat).YZWX - normalize(floaty)) < 0.01f))
            {
                Log.Info($"Haleluja3!");
            }

            float frac = modf(5.6f, out var intPart);

            Log.Info($"Haleluja2! {frac} {intPart}");
        }

        /// <summary>
        /// Called before the component is being destroyed.
        /// </summary>
        void OnDestroy()
        {
            Log.Trace("Destroy");
        }
    }
}