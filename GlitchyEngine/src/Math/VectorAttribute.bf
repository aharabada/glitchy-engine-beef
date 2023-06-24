using System;

namespace GlitchyEngine.Math;

[AttributeUsage(.Struct | .Class)]
struct VectorAttribute<T, ComponentCount> : Attribute, IComptimeTypeApply where ComponentCount : const int
{
	public const String[4] ComponentNames = .("X", "Y", "Z", "W");
	public const String[4] LowerComponentNames = .("x", "y", "z", "w");

	[Comptime]
	public void ApplyToType(Type type)
	{
		GenerateFields(type);

		GenerateCasts(type);

		GenerateConstructors(type);

		GenerateEqualityOperators(type);

		GenerateArrayAccess(type);
	}
	
	[Comptime]
	private void GenerateFields(Type type)
	{
		String fields = scope $"public {typeof(T)} ";

		for (int i < ComponentCount)
		{
			if (i != 0)
				fields.Append(", ");

			fields.Append(ComponentNames[i]);
		}
		fields.Append(";\n\n");

		Compiler.EmitTypeBody(type, fields);
	}
	
	[Comptime]
	private void GenerateCasts(Type type)
	{
		String constructorBody = scope String();
		
		for (int i < ComponentCount)
		{
			if (i != 0)
				constructorBody.Append(", ");

			constructorBody.Append("value");
		}

		String castSingleToVector = scope $"""
			public static implicit operator Self({typeof(T)} value)
			{{
				return Self({constructorBody});
			}}


			""";

		Compiler.EmitTypeBody(type, castSingleToVector);

		String castVectorToArray = scope $"""
			[System.Inline]
			#unwarn
			public static explicit operator {typeof(T)}[{ComponentCount}](Self value) => *({typeof(T)}[{ComponentCount}]*)&value;


			""";

		Compiler.EmitTypeBody(type, castVectorToArray);
	}

#region Constructors

	[Comptime]
	private void GenerateConstructors(Type type)
	{
		// Default constructor
		//Compiler.EmitTypeBody(type, "public this() => this = default;\n\n");

		// Single constructor
		GenerateSingleConstructor(type);

		if (ComponentCount == 3)
		{
			GenerateVector3Constructors(type);
		}
		else if (ComponentCount == 4)
		{
			GenerateVector4Constructors(type);
		}
	}
	
	[Comptime]
	private void GenerateSingleConstructor(Type type)
	{
		String parameters = scope .();

		for (int i < ComponentCount)
		{
			if (i != 0)
				parameters.Append(", ");

			parameters.AppendF($"{typeof(T)} {LowerComponentNames[i]}");
		}

		String body = scope .();
		
		for (int i < ComponentCount)
		{
			body.AppendF($"\t{ComponentNames[i]} = {LowerComponentNames[i]};\n");
		}

		String constructor = scope $"""
			public this({parameters})
			{{
			{body}
			}}


			""";

		Compiler.EmitTypeBody(type, constructor);
	}

	[Comptime]
	private void GenerateVector3Constructors(Type type)
	{
		String baseName = type.GetName(.. scope String());

		// Remove number from name
		baseName.RemoveFromEnd(1);

		String constructor1 = scope $"""
			public this({baseName}2 xy, {typeof(T)} z)
			{{
				X = xy.X;
				Y = xy.Y;
				Z = z;
			}}

			""";
		
		Compiler.EmitTypeBody(type, constructor1);

		String constructor2 = scope $"""
			public this({typeof(T)} x, {baseName}2 yz)
			{{
				X = x;
				Y = yz.X;
				Z = yz.Y;
			}}

			""";

		Compiler.EmitTypeBody(type, constructor2);
	}

	[Comptime]
	private void GenerateVector4Constructors(Type type)
	{
		String baseName = type.GetName(.. scope String());

		// Remove number from name
		baseName.RemoveFromEnd(1);

		String constructor1 = scope $"""
			public this({baseName}2 xy, {typeof(T)} z, {typeof(T)} w)
			{{
				X = xy.X;
				Y = xy.Y;
				Z = z;
				W = w;
			}}

			""";
		
		Compiler.EmitTypeBody(type, constructor1);

		String constructor2 = scope $"""
			public this({typeof(T)} x, {baseName}2 yz, {typeof(T)} w)
			{{
				X = x;
				Y = yz.X;
				Z = yz.Y;
				W = w;
			}}

			""";

		Compiler.EmitTypeBody(type, constructor2);

		String constructor3 = scope $"""
			public this({typeof(T)} x, {typeof(T)} y, {baseName}2 zw)
			{{
				X = x;
				Y = y;
				Z = zw.X;
				W = zw.Y;
			}}

			""";

		Compiler.EmitTypeBody(type, constructor3);
		

		String constructor4 = scope $"""
			public this({baseName}3 xyz, {typeof(T)} w)
			{{
				X = xyz.X;
				Y = xyz.Y;
				Z = xyz.Z;
				W = w;
			}}

			""";

		Compiler.EmitTypeBody(type, constructor4);

		String constructor5 = scope $"""
			public this({typeof(T)} x, {baseName}3 yzw)
			{{
				X = x;
				Y = yzw.X;
				Z = yzw.Y;
				W = yzw.Z;
			}}

			""";

		Compiler.EmitTypeBody(type, constructor5);
	}

#endregion Constructors

	[Comptime]
	private void GenerateEqualityOperators(Type type)
	{
		GenerateComparison(type, "==");
		GenerateComparison(type, "!=");
	}

	[Comptime]
	public static void GenerateComparison(Type type, String op)
	{
		String boolConstructor = scope .();
		
		for (int i < ComponentCount)
		{
			if (i != 0)
				boolConstructor.Append(", ");

			boolConstructor.AppendF($"left.{ComponentNames[i]} {op} right.{ComponentNames[i]}");
		}

		String typeName = type.GetName(.. scope String());

		String func = scope $"""
			public static bool{ComponentCount} operator{op}({typeName} left, {typeName} right)
			{{
				return bool{ComponentCount}({boolConstructor});
			}}

			""";

		Compiler.EmitTypeBody(type, func);
	}

	[Comptime]
	private static void GenerateArrayAccess(Type type)
	{
		String arrayAccess = scope $"""
			public {typeof(T)} this[int index]
			{{
				get
				{{
					if(index < 0 || index >= {ComponentCount})
						System.Internal.ThrowIndexOutOfRange(1);

			#unwarn
					return (&X)[index];		
				}}
				set mut
				{{
					if(index < 0 || index >= {ComponentCount})
						System.Internal.ThrowIndexOutOfRange(1);

			#unwarn
					(&X)[index] = value;	
				}}
			}}
			""";

		Compiler.EmitTypeBody(type, arrayAccess);
	}
}

[AttributeUsage(.Struct | .Class)]
struct ComparableVectorAttribute<T, ComponentCount> : Attribute, IComptimeTypeApply where ComponentCount : const int
{
	[Comptime]
	public void ApplyToType(Type type)
	{
		VectorAttribute<T, ComponentCount>.GenerateComparison(type, ">");
		VectorAttribute<T, ComponentCount>.GenerateComparison(type, ">=");
		VectorAttribute<T, ComponentCount>.GenerateComparison(type, "<");
		VectorAttribute<T, ComponentCount>.GenerateComparison(type, "<=");
	}
}

[AttributeUsage(.Struct | .Class)]
struct VectorMathAttribute<T, ComponentCount> : Attribute, IComptimeTypeApply where ComponentCount : const int
{
	public const String[4] ComponentNames = .("X", "Y", "Z", "W");

	[Comptime]
	public void ApplyToType(Type type)
	{
		GenerateUnaryOperatorOverloads(type);

		GenerateOperatorOverloads(type, "+");
		GenerateOperatorOverloads(type, "-");
		GenerateOperatorOverloads(type, "*");
		GenerateOperatorOverloads(type, "/");
		GenerateOperatorOverloads(type, "%");
	}

	[Comptime]
	public static void GenerateUnaryOperatorOverloads(Type type)
	{
		String typeName = type.GetName(.. scope String());
		
		String unaryAdd = scope $"""
			public static {typeName} operator+({typeName} value) => value; 

			""";

		Compiler.EmitTypeBody(type, unaryAdd);



		String resultArguments = scope .();
		
		for (int i < ComponentCount)
		{
			if (i != 0)
				resultArguments.Append(", ");

			resultArguments.AppendF($"-value.{ComponentNames[i]}");
		}

		String unaryMinus = scope $"""
			public static {typeName} operator-({typeName} value)
			{{
				return {typeName}({resultArguments});
			}}

			""";

		Compiler.EmitTypeBody(type, unaryMinus);
	}

	[Comptime]
	public static void GenerateOperatorOverloads(Type type, String op)
	{
		String typeName = type.GetName(.. scope String());
		String componentTypeName = typeof(T).GetName(.. scope String());
		
		[Comptime]
		void EmitOperatorOverload(String leftType, String rightType, String resultArguments)
		{
			String func = scope $"""
				public static {typeName} operator{op}({leftType} left, {rightType} right)
				{{
					return {typeName}({resultArguments});
				}}

				""";

			Compiler.EmitTypeBody(type, func);
		}

		// Vector + Vector
		String resultArguments = scope .();
		
		for (int i < ComponentCount)
		{
			if (i != 0)
				resultArguments.Append(", ");

			resultArguments.AppendF($"left.{ComponentNames[i]} {op} right.{ComponentNames[i]}");
		}

		EmitOperatorOverload(typeName, typeName, resultArguments);
		
		// Vector + Scalar
		resultArguments.Clear();
		
		for (int i < ComponentCount)
		{
			if (i != 0)
				resultArguments.Append(", ");

			resultArguments.AppendF($"left.{ComponentNames[i]} {op} right");
		}

		EmitOperatorOverload(typeName, componentTypeName, resultArguments);
		
		// Scalar + Vector
		resultArguments.Clear();
		
		for (int i < ComponentCount)
		{
			if (i != 0)
				resultArguments.Append(", ");

			resultArguments.AppendF($"left {op} right.{ComponentNames[i]}");
		}

		EmitOperatorOverload(componentTypeName, typeName, resultArguments);
	}
}
