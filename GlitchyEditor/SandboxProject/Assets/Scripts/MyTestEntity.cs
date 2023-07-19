using System;
using GlitchyEngine;
using GlitchyEngine.Editor;
using GlitchyEngine.Math;

//using GlitchyEngine.Math;

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
        public Vector2 TheVector;
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
        public Vector2 V2;
        public Vector3 V3;
        public Vector4 V4;

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
            Vector2 force = Vector2.Zero;

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
                Physics2D.Gravity *= new Vector2(1, -1);
            }

            Test.Test.P();

            float2 f2 = new();

            f2.X = 5;

            Log.Info($"Haleluja! {f2.X}");

            float4 floaty = new float4(f2, f2);

            Log.Info($"Haleluja2! {floaty}");
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