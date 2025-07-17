using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.IO;
using System.Linq;
using System.Reflection.Metadata;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace ScriptCoreGenerator;

internal class GlueMethod
{
    [JsonPropertyName("name")]
    public string Name { get; set; }
    [JsonPropertyName("return_type")]
    public string ReturnType { get; set; }
    [JsonPropertyName("parameters")]
    public List<Parameter> Parameters { get; set; }

    internal class Parameter
    {
        [JsonPropertyName("name")]
        public string Name { get; set; }
        [JsonPropertyName("type")]
        public string Type { get; set; }
    }
}

[Generator]
public class ScriptGlueGenerator : IIncrementalGenerator
{
    public class GeneratorInput
    {
        public ImmutableArray<ITypeSymbol?> TypeMappings;
        public ImmutableArray<string> GlueFunctionDefinitions;
        public ImmutableArray<string> ExistingScriptGlueClasses;
        public ImmutableArray<string> ExistingEngineFunctionStructs;
    }

    public void Initialize(IncrementalGeneratorInitializationContext context)
    {
        var mappedTypes = context.SyntaxProvider
            .CreateSyntaxProvider(
                CouldBeMappedType, GetTypeOrNull)
            .Where(type => type is not null)
            .Collect();

        var manualScriptGlueWrappers = context.SyntaxProvider
            .CreateSyntaxProvider(
                IsScriptGlueClass, GetSymbol<ClassDeclarationSyntax>)
            .Where(type => type is not null)
            .SelectMany((type, _) => type!.MemberNames)
            .Collect();

        var manualEngineFunctions = context.SyntaxProvider
            .CreateSyntaxProvider(
                IsEngineFunctionsStruct, GetSymbol<StructDeclarationSyntax>)
            .Where(type => type is not null)
            .SelectMany((type, _) => type!.MemberNames)
            .Collect();

        var glueFunctions = context.AdditionalTextsProvider
            .Where(text => text.Path.EndsWith("ScriptGlue.json",
                StringComparison.OrdinalIgnoreCase))
            .Select((text, token) => text.GetText(token)?.ToString())
            .Where(text => text is not null)!
            .Collect<string>();

        // Kombiniere zu einem sauberen Record
        var combinedProvider = mappedTypes
            .Combine(manualScriptGlueWrappers)
            .Combine(manualEngineFunctions)
            .Combine(glueFunctions)
            .Select((input, _) => new GeneratorInput{
                TypeMappings = input.Left.Left.Left,
                ExistingScriptGlueClasses = input.Left.Left.Right,
                ExistingEngineFunctionStructs = input.Left.Right,
                GlueFunctionDefinitions = input.Right
            });

        context.RegisterSourceOutput(combinedProvider, GenerateCode);
    }

    public class MappedType
    {
        public string BeefTypeName;
        public string? UnderlyingEnumTypeName;
        public bool HasUnderlyingType => UnderlyingEnumTypeName is not null;

        private string _cSharpTypeName;
        private string _cSharpWrapperType;

        public MappedType? CSharpUnderlyingEnumType;

        public string? WrapperConvertInput;
        public string? WrapperCleanupInput;

        public string? ReturnValueConversion = "return returnValue;";

        public string CSharpWrapperType
        {
            get => _cSharpWrapperType ?? CSharpTypeName;
            set => _cSharpWrapperType = value;
        }

        public string CSharpTypeName
        {
            get => _cSharpTypeName ?? BeefTypeName;
            set => _cSharpTypeName = value;
        }
    }

    private static MappedType DecodeType(string beefType, Dictionary<string, MappedType> beefTypeToMappedType)
    {
        if (beefTypeToMappedType.TryGetValue(beefType, out MappedType? mappedType))
        {
            return mappedType;
        }

        int colonIndex = beefType.IndexOf(':');
        bool isEnum = colonIndex != -1;

        string beefTypeName = beefType;
        string? underlyingEnumType = null;

        if (isEnum)
        {
            beefTypeName = beefType.Substring(0, colonIndex).Trim();
            underlyingEnumType = beefType.Substring(colonIndex + 1).Trim();

            if (beefTypeToMappedType.TryGetValue(beefTypeName, out mappedType))
            {
                if (mappedType.UnderlyingEnumTypeName is null)
                {
                    mappedType.UnderlyingEnumTypeName = underlyingEnumType;
                    mappedType.CSharpUnderlyingEnumType = DecodeType(underlyingEnumType, beefTypeToMappedType);
                }

                return mappedType;
            }
        }

        MappedType newMapping = new MappedType()
        {
            BeefTypeName = beefTypeName,
            UnderlyingEnumTypeName = underlyingEnumType,
            CSharpUnderlyingEnumType = underlyingEnumType == null ? null : DecodeType(underlyingEnumType,beefTypeToMappedType),
        };

        beefTypeToMappedType[beefType] = newMapping;
        beefTypeToMappedType[beefTypeName] = newMapping;

        return newMapping;
    }

    private static void InitializeTypes(Dictionary<string, MappedType> beefTypeToMappedType)
    {
        beefTypeToMappedType.Add("void", new MappedType
        {
            BeefTypeName = "void",
            ReturnValueConversion = null
        });

        beefTypeToMappedType.Add("char16*", new MappedType
        {
            BeefTypeName = "char16*",
            CSharpTypeName = "char*",
            CSharpWrapperType = "string",
            ReturnValueConversion = null, // TODO!
            WrapperConvertInput = "fixed (char* {0} = {1}) {{",
            WrapperCleanupInput = "}}"
        });
    }

    private static void GenerateFunctionPointer(GlueMethod method, Dictionary<string, MappedType> beefTypeToMappedType, StringBuilder output)
    {
        MappedType returnType = DecodeType(method.ReturnType, beefTypeToMappedType);

        List<MappedType> parameters = new();
        StringBuilder parameterText = new();

        foreach (var param in method.Parameters)
        {
            MappedType parameterType = DecodeType(param.Type, beefTypeToMappedType);
            parameters.Add(parameterType);

            parameterText.Append(parameterType.CSharpTypeName);
            parameterText.Append(", ");
        }

        output.AppendLine($"    public delegate* unmanaged[Cdecl]<{parameterText}{returnType.CSharpTypeName}> {method.Name};");
    }

    private static void GenerateWrapper(GlueMethod method, Dictionary<string, MappedType> beefTypeToMappedType, StringBuilder output)
    {
        // MappedType returnType = DecodeType(method.ReturnType, beefTypeToMappedType);
        //
        List<MappedType> parameters = new();
        StringBuilder parameterText = new();
        StringBuilder parameterConversion = new();
        StringBuilder cleanup = new();
        StringBuilder call = new();

        MappedType returnType = DecodeType(method.ReturnType, beefTypeToMappedType);

        if (returnType.ReturnValueConversion is not null)
        {
            call.Append("var returnValue = ");
        }

        call.Append($"_engineFunctions.{method.Name}(");

        foreach (var param in method.Parameters)
        {
            MappedType parameterType = DecodeType(param.Type, beefTypeToMappedType);
            parameters.Add(parameterType);

            if (parameterText.Length > 0)
            {
                parameterText.Append(", ");
                call.Append(", ");
            }

            parameterText.Append($"{parameterType.CSharpWrapperType} {param.Name}");

            if (parameterType.WrapperConvertInput is not null)
            {
                string convertedParamName = $"{param.Name}Converted";

                parameterConversion.AppendLine();
                parameterConversion.Append("\t\t");
                parameterConversion.AppendFormat(parameterType.WrapperConvertInput, convertedParamName, param.Name);

                if (parameterType.WrapperCleanupInput is not null)
                {
                    cleanup.Append("\t\t");
                    cleanup.AppendFormat(parameterType.WrapperCleanupInput, convertedParamName);
                    cleanup.AppendLine();
                }

                call.Append(convertedParamName);
            }
            else
            {
                call.Append(param.Name);
            }
        }

        call.Append(");");

        output.AppendLine($$"""
                                public static {{returnType.CSharpWrapperType}} {{method.Name}}({{parameterText}})
                                {{{parameterConversion}}
                                    {{call}}
                            {{cleanup}}
                                    {{returnType.ReturnValueConversion}}
                                }

                            """);


    }

    private static void GenerateCode(
        SourceProductionContext context,
        GeneratorInput input)
    {
         Dictionary<string, MappedType> beefTypeToMappedType = new();

         InitializeTypes(beefTypeToMappedType);

         foreach (ITypeSymbol? mapping in input.TypeMappings)
         {
             if (mapping is null)
                 continue;

             string csharpTypeName = mapping.ToDisplayString();

             foreach (AttributeData attribute in mapping.GetAttributes()
                 .Where(attribute => attribute.AttributeClass?.Name == "EngineClassAttribute"))
             {
                 string? beefTypeName = attribute.ConstructorArguments[0].Value?.ToString();

                 if (beefTypeName is null)
                     continue;

                 MappedType newMapping = DecodeType(beefTypeName, beefTypeToMappedType);
                 newMapping.CSharpTypeName = csharpTypeName;
             }
         }

         StringBuilder engineFunctions = new StringBuilder();
         StringBuilder wrappers = new StringBuilder();

         engineFunctions.Append("""
                       // <auto-generated />
                       using System.Collections.Generic;

                       namespace GlitchyEngine;

                       unsafe internal partial struct EngineFunctions
                       {
                       /*
                       """);

         wrappers.Append("""
                    // <auto-generated />
                    using System.Collections.Generic;

                    namespace GlitchyEngine;

                    unsafe internal partial class ScriptGlue
                    {
                    """);

         List<GlueMethod> methods = new List<GlueMethod>();

         foreach (string glueFunctions in input.GlueFunctionDefinitions)
         {
             methods.AddRange(JsonSerializer.Deserialize<GlueMethod[]>(glueFunctions) ?? []);
         }

         foreach (GlueMethod method in methods)
         {
             if (!input.ExistingEngineFunctionStructs.Contains(method.Name))
             {
                 GenerateFunctionPointer(method, beefTypeToMappedType, engineFunctions);
             }

             if (!input.ExistingScriptGlueClasses.Contains(method.Name))
             {
                 GenerateWrapper(method, beefTypeToMappedType, wrappers);
             }
         }

         //
         // foreach (var type in input.enumerations)
         // {
         //     if (type is null)
         //         continue;
         //
         //     GenerateCode(type, output);
         //     var typeNamespace = type.ContainingNamespace.IsGlobalNamespace
         //         ? null
         //         : $"{type.ContainingNamespace}.";
         //
         // }

         engineFunctions.Append("\n*/}");
         wrappers.Append("\n}");

         context.AddSource("EngineFunctions.g.cs", engineFunctions.ToString());
         context.AddSource("ScriptGlue.g.cs", wrappers.ToString());
    }

    private static bool IsScriptGlueClass(
        SyntaxNode syntaxNode,
        CancellationToken cancellationToken)
    {
        return syntaxNode is ClassDeclarationSyntax { Identifier.ValueText: "ScriptGlue" };
    }

    private static bool IsEngineFunctionsStruct (
        SyntaxNode syntaxNode,
        CancellationToken cancellationToken)
    {
        return syntaxNode is StructDeclarationSyntax { Identifier.ValueText: "EngineFunctions" };
    }

    private static INamedTypeSymbol? GetSymbol<T>(GeneratorSyntaxContext context,
        CancellationToken cancellationToken) where T : BaseTypeDeclarationSyntax
    {
        var classDecl = (T)context.Node;
        return context.SemanticModel.GetDeclaredSymbol(classDecl) as INamedTypeSymbol;
    }

    private static bool CouldBeMappedType(
        SyntaxNode syntaxNode,
        CancellationToken cancellationToken)
    {
        if (syntaxNode is not AttributeSyntax attribute)
            return false;

        var name = ExtractName(attribute.Name);

        return name is "EngineClass" or "EngineClassAttribute";
    }

    private static string? ExtractName(NameSyntax? name)
    {
        return name switch
        {
            SimpleNameSyntax ins => ins.Identifier.Text,
            QualifiedNameSyntax qns => qns.Right.Identifier.Text,
            _ => null
        };
    }

    private static ITypeSymbol? GetTypeOrNull(
        GeneratorSyntaxContext context,
        CancellationToken cancellationToken)
    {
        var attributeSyntax = (AttributeSyntax)context.Node;

        // "attribute.Parent" is "AttributeListSyntax"
        // "attribute.Parent.Parent" is a C# fragment the attributes are applied to
        if (attributeSyntax.Parent?.Parent is not BaseTypeDeclarationSyntax typeDeclaration)
            return null;

        return context.SemanticModel.GetDeclaredSymbol(typeDeclaration) as ITypeSymbol;
    }
}
