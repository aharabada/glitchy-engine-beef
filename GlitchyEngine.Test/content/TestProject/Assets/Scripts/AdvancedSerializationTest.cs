using GlitchyEngine;
using GlitchyEngine.Math;
using System;
using System.Collections.Generic;
using System.Text;

namespace TestProject.Assets.Scripts;

public class SimpleGenericClass<T>
{
    public T MyField;
}

public struct SimpleGenericStruct<T>
{
    public T MyField;
}

public class AdvancedSerializationTest : Entity
{
    public (int Prim, float2 Struc, BClass Ref) LeTuple;

    public List<(int Prim, float2 Struc, BClass Ref)> LeListDeTuple;

    public SimpleGenericStruct<float> GenericStructField = new SimpleGenericStruct<float>();

    public SimpleGenericClass<double> GenericClassField = new SimpleGenericClass<double>();
}
