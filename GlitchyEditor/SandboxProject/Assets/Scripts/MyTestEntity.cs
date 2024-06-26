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
        Yes = 1,
        No,
        Maybe = 1337
    }

    public struct MyStruct
    {
        public float TheFloat;
        public float2 TheVector;
        public MyEnum TheEnum;
    }

    class MyTestEntity : Entity
    {
        [ShowInEditor]
        RigidBody2D _rigidBody;

        //public bool Bo;

        //public byte By;
        //public ushort Us;
        //public uint Ui;
        //public ulong Ul;

        //public sbyte Sb;
        //public short Sh;
        //public int In;
        //public long Lo;

        //public float Fl;
        //public double Do;
        //public float2 V2;
        //public float3 V3;
        //public float4 V4;

        public Entity TheEntity;

        public float JumpForce = 2000;
        [ShowInEditor] float MoveForce = 1000;
        [ShowInEditor] private int MyNumber = 1337;
        //[ShowInEditor] public double MyDouble = 1000.0f;

        public MyStruct AStruct;

        public MyEnum AEnum = MyEnum.Maybe;
        
        public Camera Camera;

        /// <summary>
        /// Called after the script component was created. (The entity might not be fully created yet)
        /// </summary>
        void OnCreate()
        {
            Log.Info($"Create! {UUID}");

            Log.Info($"Jump Force: {JumpForce}");

            //_rigidBody ??= GetComponent<RigidBody2D>() ?? AddComponent<RigidBody2D>();

            if (_rigidBody == null)
            {
                Log.Error("_rigidBody was not set in editor.");
            }

            if (Camera == null)
            {
                Log.Warning("Camera wasn't set in editor. Searching...");
                Camera = FindEntityWithName("Camera").As<Camera>();
                
                if (Camera == null)
                {
                    Log.Error("Camera not found.");
                }
            }
            Log.Warning("Achtung.");

            try
            {
                SubVoid();
            }
            catch (Exception e)
            {
                Console.WriteLine(e);
                throw e;
            }
        }

        void SubVoid()
        {
            throw new Exception("Ouha!", new IndexOutOfRangeException("Bist du jecke2?!", new AccessViolationException("Haleluja")));
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
            
            if (Input.IsKeyPressing(Key.N))
                SubVoid();

            _rigidBody.ApplyForceToCenter(force);

            if (Input.IsMouseButtonReleasing(MouseButton.MiddleButton))
            {
                Log.Info($"Ouha! {MyNumber}");
                Physics2D.Gravity *= new float2(1, -1);
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
}