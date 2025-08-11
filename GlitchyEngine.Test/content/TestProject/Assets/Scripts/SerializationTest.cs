using System;
using System.Collections.Generic;
using System.ComponentModel;
using GlitchyEngine;
using GlitchyEngine.Core;
using GlitchyEngine.Editor;
using GlitchyEngine.Extensions;
using GlitchyEngine.Physics;
using GlitchyEngine.Serialization;

namespace TestProject;

class AClass
{
    public AStruct MyStruct = new AStruct();

    public bool Test;
}

public class BClass
{
    public float F;

    private BClass()
    {

    }

    public BClass(float f)
    {
        F = f;
    }
}

enum MyTestEnum
{
    Case1 = 0,
    [Label("What have I done!?")]
    Yes = 1,
    No = 17,
    Maybe = 12,
    OhHellNaw = 33,
    [Label(null)]
    ___OhHellNaw2,
    ___OhH_e123llNaw3,
}

struct AStruct
{
    public double Do = 5.5;

    public string Hello = "World!";

    public AStruct()
    {
    }
}

class SerializationTest : Entity
{
    public static int StaticNumber;

    public float Floaty1 = 1; // Serialized, Visible
    [DontSerializeField]
    public float Floaty2 = -2.5f; // NOT Serialized, Visible
    [HideInEditor]
    public float Floaty3 = 1; // Serialized, Hidden
    [HideInEditor, DontSerializeField]
    public float Floaty4 = 1; // NOT Serialized, Hidden

    // "private", "protected" and "internal" work the same way

    private float Floaty5 = 1; // NOT Serialized, Hidden
    [SerializeField]
    private float Floaty6 = 7; // Serialized, Hidden
    [ShowInEditor]
    private float Floaty7 = 12.4f; // Serialized, Visible
    [ShowInEditor, DontSerializeField]
    private float Floaty8 = 69; // NOT Serialized, Visible
    
    public double Doubly = 1337;
    public double Doubly2 = 1337.69;

    [SerializeField]
    public decimal Decimaly = 420.69m;

    public AClass Classy = new AClass();
    public AClass NullClass = null;

    public MyTestEnum Enumy = MyTestEnum.Maybe;

    public List<BClass> Listy = new List<BClass>()
    {
        new BClass(1),
        new BClass(2),
        new BClass(3),
    };

    public List<BClass> NullList = null;

    public List<List<BClass>> JaggeredList = null;

    public BClass SecondReference;

    public int[] ArrayInts = new[] { 4, 5, 6 };
    
    public int[] NullArray = null;

    public AStruct MyStruct = new ();

    public List<AStruct> StructList = new List<AStruct>()
    {
        new AStruct(),
        new AStruct()
        {
            Do = 15,
            Hello = "Hi"
        }
    };
    
    public AStruct[] StructArray = {
        new()
        {
            Do = 123,
            Hello = "How are you doing?"
        },
        new()
    };

    public BClass[] ClassArray = {
        null,
        new(5),
        null
    };

    public Entity JustAnEntity;
    public Rigidbody2D RocketsRigidBody;

    public Dictionary<string, int> TestDictionary = null;

    public SerializationTest()
    {
        SecondReference = Listy[0];
        ClassArray[0] = SecondReference;
    }
    
    // TODO: Dictionary mit custom serializer?

    [ShowButton("Try Serialization")]
    void Serialize()
    {
        TestDictionary = new()
        {
            { "Test", 1 },
            { "Taste", 2 }
        };

        //try
        //{
        //    //EntitySerializer.SerializationContext ctx = new();
        //    //EntitySerializer.Serialize(this, ctx);

        //    //string ser = ctx.ToString();
        //}
        //catch (Exception e)
        //{
        //    Console.WriteLine(e);
        //    throw;
        //}
    }
    
    protected override void OnCreate()
    {
        //Log.Info($"Entity: {JustAnEntity?.UUID}");
        //Log.Info($"TheRocket: {TheRocket?.UUID}");
        //Log.Info($"RocketsRigidBody: {RocketsRigidBody?.UUID}");

        //if (TestDictionary != null)
        //{
        //    foreach (var (key, value) in TestDictionary)
        //    {
        //        Log.Info($"Key: {key}, Value: {value}");
        //    }
        //}
    }
}

/*

Expected output:

Object 0:
    Type = SerializationTest
    Floaty1 (float) = 1
    Floaty3 (float) = 1
    Floaty7 (float) = 12
    Classy (Object Reference) = (REF: Object 1)
    NullClass (Object Reference) = NULL
    Enumy (Enum) = MyTestEnum.Maybe
    Listy (List) = (REF: List 0)
    NullList (List) = NULL
    SecondReference (Object Reference) = (REF: Object 2) // Notice, how we reference the same Object as Listy[0]
    ArrayInts (List) = (REF: List 1)
    NullArray (List) = NULL
    MyStruct.Do (double) = 5.5
    MyStruct.Hello (string) = "World!"

    StructList (List) = (REF: List 2)

Object 1: // Classy
    Type = AClass
    
Object 2: // Listy[0]
    Type = BClass
    F (float) = 1.0f

Object 3: // Listy[1]
    Type = BClass
    F (float) = 2.0f

Object 4: // Listy[2]
    Type = BClass
    F (float) = 3.0f
   
List 0:
    ElementType = BClass
    Serialization Type = Object Reference
    Element 0 = (REF: Object 2)
    Element 1 = (REF: Object 3)
    Element 2 = (REF: Object 4)

List 1:
    ElementType = int32
    Serialization Type = int32
    Element 0 = 4
    Element 1 = 5
    Element 2 = 6

List 2:
    ElementType = AStruct
    Serialization Type = Struct
    Element 0:
        Do (double) = 5.5
        Hello (string) = "World!"
    Element 1:
        Do (double) = 15
        Hello (string) = "Hi"
 */
