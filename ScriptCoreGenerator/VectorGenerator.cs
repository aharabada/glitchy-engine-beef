using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Mail;
using System.Numerics;
using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using static ScriptCoreGenerator.VectorSyntaxReceiver;

namespace ScriptCoreGenerator;

[Generator]
public class VectorGenerator : ISourceGenerator
{
    public static readonly string[] ComponentNames = {"X", "Y", "Z", "W"};

    public static readonly string[] LowerComponentNames = {"x", "y", "z", "w"};

    private GeneratorExecutionContext _context;

    public void Execute(GeneratorExecutionContext context)
    {
        _context = context;

        var receiver = (VectorSyntaxReceiver)context.SyntaxReceiver;

        if (receiver == null) return;

        StringBuilder builder = new();
        
        //foreach(var vector in receiver.Vectors)
        //{
        //    var symbol = context.Compilation.GetSymbolsWithName(vector.VectorName);

        //    var firstSym = symbol.FirstOrDefault();

        //    context.ReportDiagnostic(Diagnostic.Create(
        //        new DiagnosticDescriptor(
        //            "SG0001",
        //            "Non-void method return type",
        //            "Type {0} iscool!.",
        //            "yeet",
        //            DiagnosticSeverity.Error,
        //            true), firstSym?.Locations.FirstOrDefault(), firstSym?.Name));

        //    //if(symbol.ReturnType.SpecialType != SpecialType.System_Void)
        //    //{
        //    //    context.ReportDiagnostic(Diagnostic.Create(
        //    //        new DiagnosticDescriptor(
        //    //            "SG0001",
        //    //            "Non-void method return type",
        //    //            "Method {0} returns {1}. All methods must return void.",
        //    //            "yeet",
        //    //            DiagnosticSeverity.Error,
        //    //            true), symbol.Locations.FirstOrDefault(), symbol.Name, symbol.ReturnType.Name));
        //    //}
        //}

        foreach (var vector in receiver.Vectors)
        {
            builder.Clear();

            // Copy all usings from the original file
            builder.AppendLine(vector.Struct.GetParent<CompilationUnitSyntax>().Usings.ToFullString());

            builder.Append($$"""
                    // For "DebuggerBrowsable" and "DebuggerBrowsableState"
                    using System.Diagnostics;

                    namespace {{vector.Struct.GetNamespace()}};

                    public partial struct {{vector.VectorName}}
                    {

                    """);
            
            GenerateFields(vector, builder);
            GenerateCasts(vector, builder);
            GenerateConstructors(vector, builder);

            GenerateArrayAccess(vector, builder);

            GenerateEqualityOperators(vector, builder);

            if (receiver.ComparableReceiver.ComparableVectors.Contains(vector.VectorName))
            {
                GenerateComparisonOperators(vector, builder);
            }

            if (receiver.MathReceiver.MathVectors.Contains(vector.VectorName))
            {
                GenerateMathOperators(vector, builder);
            }

            if (receiver.LogicReceiver.LogicVectors.Contains(vector.VectorName))
            {
                GenerateLogicOperators(vector, builder);
            }

            foreach (var cast in receiver.CastReceiver.VectorCasts.Where(c => c.FromType == vector.VectorName))
            {
                VectorDefinition toVectorDefinition = receiver.Vectors.First(v => v.VectorName == cast.ToType);

                GenerateCastOperator(cast, vector, toVectorDefinition, builder);
            }

            GenerateToString(vector, builder);

            GenerateSwizzle(vector, builder);

            builder.Append('}');
        
            context.AddSource($"{vector.VectorName}.g.cs", builder.ToString());
        }
    }

    private void GenerateToString(VectorDefinition vector, StringBuilder builder)
    {
        builder.Append("public override string ToString() => $\"{{");

        for (int i = 0; i < vector.ComponentCount; i++)
        {
            if (i > 0)
                builder.Append(", ");

            builder.Append($"{ComponentNames[i]}: {{{ComponentNames[i]}}}");
        }
        
        builder.Append("}}\";\n\n");
    }

    private void GenerateCastOperator(VectorCastSyntaxReceiver.VectorCast cast, VectorDefinition fromVector, VectorDefinition toVector, StringBuilder builder)
    {
        if (fromVector.ComponentCount != toVector.ComponentCount)
        {
            _context.ReportDiagnostic(Diagnostic.Create(
                new DiagnosticDescriptor(
                    "SG0001",
                    "Vector-Dimensions don't match for cast.",
                    $"Cannot cast from \"{fromVector.VectorName}\" to \"{toVector.VectorName}\" because the dimensions don't match.",
                    "Vector Generator",
                    DiagnosticSeverity.Error,
                    true), fromVector.Struct.GetLocation()));

            return;
        }

        StringBuilder castBuilder = new();

        for (int i = 0; i < fromVector.ComponentCount; i++)
        {
            if (i != 0)
                castBuilder.Append(", ");

            castBuilder.Append($"({toVector.ElementTypeName})value.{ComponentNames[i]}");
        }


        builder.Append($$"""
                public static {{(cast.IsExplicit ? "explicit" : "implicit")}} operator {{cast.ToType}}({{cast.FromType}} value)
                {
                    return new {{cast.ToType}}({{castBuilder}});
                }


            """);
    }

    private void GenerateFields(VectorDefinition vector, StringBuilder builder)
    {
        builder.Append($"\tpublic {vector.ElementTypeName} ");
        
        for (int i = 0; i < vector.ComponentCount; i++)
        {
            if (i != 0)
                builder.Append(", ");

            builder.Append(ComponentNames[i]);
        }

        builder.Append(";\n\n");
    }

    private void GenerateCasts(VectorDefinition vector, StringBuilder builder)
    {
        StringBuilder castBuilder = new();

        for (int i = 0; i < vector.ComponentCount; i++)
        {
            if (i != 0)
                castBuilder.Append(", ");
        
            castBuilder.Append("value");
        }

        builder.Append($$"""
                public static implicit operator {{vector.VectorName}}({{vector.ElementTypeName}} value)
                {
                    return new {{vector.VectorName}}({{castBuilder}});
                }


            """);

        // ???
        //     StringBuilder constructorBody = new();

        //     for (int i = 0; i < vector.ComponentCount; i++)
        //     {
        //         if (i != 0)
        //             constructorBody.Append(", ");

        //         constructorBody.Append("value");
        //     }

        //     builder.Append($$"""
        //         public static implicit operator {{}}
        //         """);

        //     String castSingleToVector = scope $"""

        //public static implicit operator Self({typeof(T)} value)
        //{{
        //     return Self({constructorBody});
        //     }}


        //""";
    }

    private void GenerateConstructors(VectorDefinition vector, StringBuilder builder)
    {
        GenerateSingleConstructor(vector, builder);

        if (vector.ComponentCount == 3)
        {
            Generatefloat3Constructors(vector, builder);
        }
        else if (vector.ComponentCount == 4)
        {
            Generatefloat4Constructors(vector, builder);
        }
    }

    private void GenerateSingleConstructor(VectorDefinition vector, StringBuilder builder)
    {
        StringBuilder parameters = new();
        StringBuilder body = new();
        
        for (int i = 0; i < vector.ComponentCount; i++)
        {
            if (i != 0)
                parameters.Append(", ");
            
            parameters.Append($"{vector.ElementTypeName} {LowerComponentNames[i]}");
        }
        
        for (int i = 0; i < vector.ComponentCount; i++)
        {
            body.Append($"\n\t\t{ComponentNames[i]} = {LowerComponentNames[i]};");
        }

        builder.Append($$"""
                public {{vector.VectorName}} ({{parameters}})
                {{{body}}
                }


            """);
    }
    
    private void Generatefloat3Constructors(VectorDefinition vector, StringBuilder builder)
    {
        builder.Append($$"""
            public {{vector.VectorName}}({{vector.BaseName}}2 xy, {{vector.ElementTypeName}} z)
            {
                X = xy.X;
                Y = xy.Y;
                Z = z;
            }

        """);

        builder.Append($$"""
            public {{vector.VectorName}}({{vector.ElementTypeName}} x, {{vector.BaseName}}2 yz)
            {
                X = x;
                Y = yz.X;
                Z = yz.Y;
            }

        """);
    }
    
    private void Generatefloat4Constructors(VectorDefinition vector, StringBuilder builder)
    {
        builder.Append($$"""
            public {{vector.VectorName}}({{vector.BaseName}}2 xy, {{vector.BaseName}}2 zw)
            {
                //XY = xy;
                //ZW = zw;
                X = xy.X;
                Y = xy.Y;
                Z = zw.X;
                W = zw.Y;
            }


        """);

        builder.Append($$"""
            public {{vector.VectorName}}({{vector.BaseName}}2 xy, {{vector.ElementTypeName}} z, {{vector.ElementTypeName}} w)
            {
                X = xy.X;
                Y = xy.Y;
                Z = z;
                W = w;
            }


        """);

        builder.Append($$"""
            public {{vector.VectorName}}({{vector.ElementTypeName}} x, {{vector.BaseName}}2 yz, {{vector.ElementTypeName}} w)
            {
                X = x;
                Y = yz.X;
                Z = yz.Y;
                W = w;
            }


        """);

        builder.Append($$"""
            public {{vector.VectorName}}({{vector.ElementTypeName}} x, {{vector.ElementTypeName}} y, {{vector.BaseName}}2 zw)
            {
                X = x;
                Y = y;
                Z = zw.X;
                W = zw.Y;
            }


        """);

        builder.Append($$"""
            public {{vector.VectorName}}({{vector.BaseName}}3 xyz, {{vector.ElementTypeName}} w)
            {
                X = xyz.X;
                Y = xyz.Y;
                Z = xyz.Z;
                W = w;
            }


        """);

        builder.Append($$"""
            public {{vector.VectorName}}({{vector.ElementTypeName}} x, {{vector.BaseName}}3 yzw)
            {
                X = x;
                Y = yzw.X;
                Z = yzw.Y;
                W = yzw.Z;
            }


        """);
    }
    
    private static void GenerateArrayAccess(VectorDefinition vector, StringBuilder builder)
    {
        StringBuilder getterSwitch = new();
        StringBuilder setterSwitch = new();

        for (int i = 0; i < vector.ComponentCount; i++)
        {
            getterSwitch.Append($$"""

                            case {{i}}:
                                return {{ComponentNames[i]}};
                """);

            setterSwitch.Append($$"""

                            case {{i}}:
                                {{ComponentNames[i]}} = value;
                                break;
                """);
        }


        builder.Append($$"""
                public {{vector.ElementTypeName}} this[int index]
                {
                    get
                    {
                        switch (index)
                        {{{getterSwitch}}
                        default:
                            throw new IndexOutOfRangeException();
                        }
                    }

                    set
                    {
                        switch (index)
                        {{{setterSwitch}}
                        default:
                            throw new IndexOutOfRangeException();
                        }
                    }
                }


            """);
    }

    private void GenerateEqualityOperators(VectorDefinition vector, StringBuilder builder)
    {
        GenerateComparison("==", vector, builder);
        GenerateComparison("!=", vector, builder);
    }

    public static void GenerateComparison(string op, VectorDefinition vector, StringBuilder builder)
    {
        StringBuilder arguments = new();
        
        for (int i = 0; i < vector.ComponentCount; i++)
        {
            if (i != 0)
                arguments.Append(", ");

            arguments.Append($"left.{ComponentNames[i]} {op} right.{ComponentNames[i]}");
        }

        builder.Append($$"""
                public static bool{{vector.ComponentCount}} operator {{op}}({{vector.VectorName}} left, {{vector.VectorName}} right)
                {
                    return new bool{{vector.ComponentCount}}({{arguments}});
                }


            """);
    }
    
    private void GenerateComparisonOperators(VectorDefinition vector, StringBuilder builder)
    {
        GenerateComparison(">", vector, builder);
        GenerateComparison(">=", vector, builder);
        GenerateComparison("<", vector, builder);
        GenerateComparison("<=", vector, builder);
    }

    public static void GenerateMathOperators(VectorDefinition vector, StringBuilder builder)
    {
        GenerateUnaryOperatorOverload("+", vector, builder);
        GenerateUnaryOperatorOverload("-", vector, builder);

        GenerateOperatorOverloads("+", vector, builder);
        GenerateOperatorOverloads("-", vector, builder);
        GenerateOperatorOverloads("*", vector, builder);
        GenerateOperatorOverloads("/", vector, builder);
        GenerateOperatorOverloads("%", vector, builder);
    }
    
    public static void GenerateUnaryOperatorOverload(string op, VectorDefinition vector, StringBuilder builder)
    {
        StringBuilder negativeArguments = new();
        
        for (int i = 0; i < vector.ComponentCount; i++)
        {
            if (i != 0)
                negativeArguments.Append(", ");

            negativeArguments.Append($"{op}value.{ComponentNames[i]}");
        }

        builder.Append($$"""
                public static {{vector.VectorName}} operator {{op}}({{vector.VectorName}} value)
                {
                    return new {{vector.VectorName}}({{negativeArguments}});
                }


            """);
    }

    public static void GenerateOperatorOverloads(string op, VectorDefinition vector, StringBuilder builder)
    {
        StringBuilder arguments = new();
        
        // Vector <op> Vector

        for (int i = 0; i < vector.ComponentCount; i++)
        {
            if (i != 0)
                arguments.Append(", ");

            arguments.Append($"left.{ComponentNames[i]} {op} right.{ComponentNames[i]}");
        }
        
        builder.Append($$"""
                public static {{vector.VectorName}} operator {{op}}({{vector.VectorName}} left, {{vector.VectorName}} right)
                {
                    return new {{vector.VectorName}}({{arguments}});
                }


            """);

        // Vector <op> Scalar
        arguments.Clear();
        for (int i = 0; i < vector.ComponentCount; i++)
        {
            if (i != 0)
                arguments.Append(", ");

            arguments.Append($"left.{ComponentNames[i]} {op} right");
        }
        
        builder.Append($$"""
                public static {{vector.VectorName}} operator {{op}}({{vector.VectorName}} left, {{vector.ElementTypeName}} right)
                {
                    return new {{vector.VectorName}}({{arguments}});
                }


            """);

        // Scalar <op> Vector
        arguments.Clear();
        for (int i = 0; i < vector.ComponentCount; i++)
        {
            if (i != 0)
                arguments.Append(", ");

            arguments.Append($"left {op} right.{ComponentNames[i]}");
        }
        
        builder.Append($$"""
                public static {{vector.VectorName}} operator {{op}}({{vector.ElementTypeName}} left, {{vector.VectorName}} right)
                {
                    return new {{vector.VectorName}}({{arguments}});
                }


            """);
    }
    
    public static void GenerateLogicOperators(VectorDefinition vector, StringBuilder builder)
    {
        GenerateOperatorOverloads("&", vector, builder);
        GenerateOperatorOverloads("|", vector, builder);
        GenerateOperatorOverloads("^", vector, builder);
    }

    /**
	 * Returns true if the swizzle operator is invalid (same component assigned twice).
	*/
    static bool IsSwizzleSetterValid(int[] cmp, int vecSize)
    {
        return cmp[0] == cmp[1] || (vecSize >= 3 && cmp[0] == cmp[2]) || (vecSize == 4 && cmp[0] == cmp[3]) ||
               (vecSize >= 3 && cmp[1] == cmp[2]) || (vecSize == 4 && cmp[1] == cmp[3]) ||
               (vecSize == 4 && cmp[2] == cmp[3]);
    }

    private void GenerateSwizzle(VectorDefinition vector, StringBuilder builder)
    {
        for(int swizzleCount = 2; swizzleCount <= 4; swizzleCount++)
        {
            int[] cmp = new int[4];

            int cmp2max = swizzleCount > 2 ? vector.ComponentCount : 1;
            int cmp3max = swizzleCount > 3 ? vector.ComponentCount : 1;

            for(cmp[0] = 0; cmp[0] < vector.ComponentCount; cmp[0]++)
            for(cmp[1] = 0; cmp[1] < vector.ComponentCount; cmp[1]++)
            for(cmp[2] = 0; cmp[2] < cmp2max; cmp[2]++)
            for(cmp[3] = 0; cmp[3] < cmp3max; cmp[3]++)
            {
                StringBuilder swizzleName = new StringBuilder(4);
                StringBuilder swizzleConstructor = new StringBuilder(swizzleCount * 3);
                StringBuilder setter = new StringBuilder();

                bool setterInvalid = IsSwizzleSetterValid(cmp, swizzleCount);

                for(int c = 0; c < swizzleCount; c++)
                {
                    swizzleName.Append(ComponentNames[cmp[c]]);

                    if(c != 0)
                    {
                        swizzleConstructor.Append(", ");
                    }
                    swizzleConstructor.Append(ComponentNames[cmp[c]]);

                    if(!setterInvalid && c < vector.ComponentCount)
                    {
                        setter.Append($"\n\t\t\t{ComponentNames[cmp[c]]} = value.{ComponentNames[c]};");
                    }
                }
       //         if (!setterInvalid)
       //         {
       //             setter.Append(
       //                 """
							//	set mut
							//	{
							//""");
       //         }

                // DebuggerBrowsableState.Never to hide swizzle properties in debugger view

                builder.Append($$"""
                        [DebuggerBrowsable(DebuggerBrowsableState.Never)]
                        public {{vector.BaseName}}{{swizzleCount}} {{swizzleName}}
                        {
                            get => new({{swizzleConstructor}});

                    """);

                if (!setterInvalid)
                {
                    builder.Append($$"""
							        set
							        {{{setter}}
							        }

							""");
                }

                builder.Append("\t}\n\n");

                //          string swizzleString = $$"""
                //public {{swizzle.BaseName}}{{swizzleCount}} {{swizzleName}}
                //{
                //get => {{swizzleConstructor}};
                //{{setter}}
                //}

                //""";

                //builder.Append(swizzleString);
            }
        }
    }

    public void Initialize(GeneratorInitializationContext context)
    {
        context.RegisterForSyntaxNotifications(() => new VectorSyntaxReceiver());
    }
}

public class VectorSyntaxReceiver : ISyntaxReceiver
{
    public ComparableVectorSyntaxReceiver ComparableReceiver = new();
    public VectorMathSyntaxReceiver MathReceiver = new();
    public VectorLogicSyntaxReceiver LogicReceiver = new();
    public VectorCastSyntaxReceiver CastReceiver = new();

    public List<VectorDefinition> Vectors { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        ComparableReceiver.OnVisitSyntaxNode(syntaxNode);
        MathReceiver.OnVisitSyntaxNode(syntaxNode);
        LogicReceiver.OnVisitSyntaxNode(syntaxNode);
        CastReceiver.OnVisitSyntaxNode(syntaxNode);

        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "Vector" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;
        
        var elementTypeName = (attr.ArgumentList.Arguments[0].Expression as TypeOfExpressionSyntax).Type.ToFullString();

        var componentCount = (attr.ArgumentList.Arguments[1].Expression as LiteralExpressionSyntax).Token.Value as int?;
        
        if (componentCount == null)
            return;
        
        var baseName = (attr.ArgumentList.Arguments[2].Expression as LiteralExpressionSyntax).Token.ValueText;

        Vectors.Add(new VectorDefinition(name, @struct, componentCount.Value, baseName, elementTypeName));
    }

    public class VectorDefinition
    {
        public string VectorName { get; }
        public StructDeclarationSyntax Struct { get; }

        public int ComponentCount { get; }
        
        public string BaseName { get; }

        public string ElementTypeName { get; }

        public VectorDefinition(string vectorName, StructDeclarationSyntax @struct, int componentCount, string baseName, string elementTypeName)
        {
            VectorName = vectorName;
            Struct = @struct;
            ComponentCount = componentCount;
            BaseName = baseName;
            ElementTypeName = elementTypeName;
        }
    }
}

public class ComparableVectorSyntaxReceiver : ISyntaxReceiver
{
    public List<string> ComparableVectors { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "ComparableVector" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;
        
        ComparableVectors.Add(name);
    }
}

public class VectorMathSyntaxReceiver : ISyntaxReceiver
{
    public List<string> MathVectors { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "VectorMath" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;
        
        MathVectors.Add(name);
    }
}

public class VectorLogicSyntaxReceiver : ISyntaxReceiver
{
    public List<string> LogicVectors { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "VectorLogic" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;
        
        LogicVectors.Add(name);
    }
}

public class VectorCastSyntaxReceiver : ISyntaxReceiver
{
    public List<VectorCast> VectorCasts { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "VectorCast" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var fromType = @struct.Identifier.Text;

        var toType = (attr.ArgumentList.Arguments[0].Expression as TypeOfExpressionSyntax).Type.ToFullString();
        
        var isExplicit = (attr.ArgumentList.Arguments[1].Expression as LiteralExpressionSyntax).Token.Value as bool?;
        
        if (isExplicit == null)
            return;

        VectorCasts.Add(new VectorCast(fromType, toType, isExplicit.Value));
    }

    public record VectorCast (string FromType, string ToType, bool IsExplicit)
    {
        public string FromType { get; } = FromType;
        public string ToType { get; } = ToType;
        public bool IsExplicit { get; } = IsExplicit;
    }
}
