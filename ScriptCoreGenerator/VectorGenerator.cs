using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Mail;
using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using static ScriptCoreGenerator.VectorSyntaxReceiver;

namespace ScriptCoreGenerator;

[Generator]
public class VectorGenerator : ISourceGenerator
{
    public static readonly string[] ComponentNames = {"X", "Y", "Z", "W"};

    public static readonly string[] LowerComponentNames = {"x", "y", "z", "w"};

    public void Execute(GeneratorExecutionContext context)
    {
        var receiver = (VectorSyntaxReceiver)context.SyntaxReceiver;

        if (receiver == null) return;

        StringBuilder builder = new();

        foreach (var vector in receiver.Vectors)
        {
            builder.Clear();

            // Copy all usings from the original file
            builder.AppendLine(vector.Struct.GetParent<CompilationUnitSyntax>().Usings.ToFullString());

            builder.Append($$"""
                    namespace {{vector.Struct.GetNamespace()}};

                    public partial struct {{vector.VectorName}}
                    {

                    """);
            
            GenerateFields(vector, builder);
            GenerateConstructors(vector, builder);

            //var swizzle = receiver.VectorSwizzle.Swizzles.FirstOrDefault(s => s.VectorName == vector.VectorName);

            //if (swizzle != null)
            GenerateSwizzle(vector, builder);
            
            builder.Append('}');
        
            context.AddSource($"{vector.VectorName}.g.cs", builder.ToString());
        }
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

                builder.Append($$"""
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
    public List<VectorDefinition> Vectors { get; } = new();

    public VectorSwizzleReceiver VectorSwizzle { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        VectorSwizzle.OnVisitSyntaxNode(syntaxNode);

        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "Vector" } } attr)
        {
            return;
        }
        
        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;

        // ToFullString should like probably always work
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

public class VectorSwizzleReceiver : ISyntaxReceiver
{
    public List<VectorSwizzle> Swizzles { get; } = new();

    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "SwizzleVector" } } attr)
        {
            return;
        }
        
        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;

       // var baseName = (attr.ArgumentList.Arguments[0].Expression as LiteralExpressionSyntax).Token.ValueText;
        
        Swizzles.Add(new VectorSwizzle(name));//, baseName));
    }
    
    public class VectorSwizzle
    {
        public string VectorName { get; }

        //public string BaseName { get; }

        public VectorSwizzle(string vectorName)//, string baseName)
        {
            VectorName = vectorName;
            //BaseName = baseName;
        }
    }
}
