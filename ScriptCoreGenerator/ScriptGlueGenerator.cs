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

    private class MappedType
    {
        public string BeefTypeName;
        public string? UnderlyingEnumTypeName;
        public bool HasUnderlyingType => UnderlyingEnumTypeName is not null;

        private string _cSharpTypeName;
        private string _cSharpWrapperType;

        public (MappedType, TypeModifier)? CSharpUnderlyingEnumType;

        public string? WrapperConvertInput;
        public string? WrapperCleanupInput;

        public string? WrapperOutConversion;

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

    private enum TypeModifier
    {
        None,
        Ref,
        In,
        Out
    }

    private static (MappedType Type, TypeModifier Modifier) DecodeType(string beefType, Dictionary<string, MappedType> beefTypeToMappedType)
    {
        TypeModifier modifier = TypeModifier.None;

        if (beefType.StartsWith("ref "))
        {
            modifier = TypeModifier.Ref;
            beefType = beefType.Substring(4);
        }
        else if (beefType.StartsWith("out "))
        {
            modifier = TypeModifier.Out;
            beefType = beefType.Substring(4);
        }
        else if (beefType.StartsWith("in "))
        {
            modifier = TypeModifier.In;
            beefType = beefType.Substring(3);
        }

        if (beefTypeToMappedType.TryGetValue(beefType, out MappedType? mappedType))
        {
            return (mappedType, modifier);
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

                return (mappedType, modifier);
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

        return (newMapping, modifier);
    }

    private static void InitializeTypes(Dictionary<string, MappedType> beefTypeToMappedType)
    {
        beefTypeToMappedType.Add("void", new MappedType
        {
            BeefTypeName = "void",
            ReturnValueConversion = null
        });

        beefTypeToMappedType.Add("Mono.MonoString*", new MappedType
        {
            BeefTypeName = "object /*TODO: Mono.MonoString**/",
            ReturnValueConversion = null
        });

        beefTypeToMappedType.Add("Mono.MonoException*", new MappedType
        {
            BeefTypeName = "object /*TODO: Mono.MonoException**/",
            ReturnValueConversion = null
        });

        beefTypeToMappedType.Add("Mono.MonoArray*", new MappedType
        {
            BeefTypeName = "object /*TODO: Mono.MonoArray**/",
            ReturnValueConversion = null
        });

        beefTypeToMappedType.Add("Mono.MonoObject*", new MappedType
        {
            BeefTypeName = "object /*TODO: Mono.MonoObject**/",
            ReturnValueConversion = null
        });

        beefTypeToMappedType.Add("Mono.MonoReflectionType*", new MappedType
        {
            BeefTypeName = "object /*TODO: Mono.MonoReflectionType**/",
            ReturnValueConversion = null
        });

        beefTypeToMappedType.Add("uint8*", new MappedType
        {
            BeefTypeName = "uint8*",
            CSharpTypeName = "byte*"
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
        
        beefTypeToMappedType.Add("char8*", new MappedType
        {
            BeefTypeName = "char8*",
            CSharpTypeName = "byte*",
            CSharpWrapperType = "string",
            ReturnValueConversion = "return Marshal.PtrToStringUTF8((IntPtr)returnValue);",
            WrapperConvertInput = "byte* {0} = (byte*)Marshal.StringToCoTaskMemUTF8({1});",
            WrapperCleanupInput = "Marshal.FreeCoTaskMem((IntPtr){0});",
            WrapperOutConversion = "{1} = Marshal.PtrToStringUTF8((IntPtr){0}) ?? \"\";"
        });

        beefTypeToMappedType.Add("int32", new MappedType
        {
            BeefTypeName = "int32",
            CSharpTypeName = "int"
        });

        beefTypeToMappedType.Add("GlitchyEngine.Math.Quaternion", new MappedType
        {
            BeefTypeName = "System.Numerics.Quaternion",
            ReturnValueConversion = null
        });
        
        beefTypeToMappedType.Add("void*", new MappedType
        {
            BeefTypeName = "void*",
            CSharpTypeName = "void*",
            CSharpWrapperType = "IntPtr",
            ReturnValueConversion = "return (IntPtr)returnValue;",
            WrapperConvertInput = "void* {0} = (void*){1};",
            WrapperOutConversion = "{1} = (IntPtr){0};"
        });
    }

    private static void GenerateFunctionPointer(GlueMethod method, Dictionary<string, MappedType> beefTypeToMappedType, StringBuilder output)
    {
        var (returnType, _) = DecodeType(method.ReturnType, beefTypeToMappedType);

        List<MappedType> parameters = new();
        StringBuilder parameterText = new();

        foreach (var param in method.Parameters)
        {
            var (parameterType, parameterModifier) = DecodeType(param.Type, beefTypeToMappedType);
            parameters.Add(parameterType);

            switch (parameterModifier)
            {
                case TypeModifier.In:
                    parameterText.Append("in ");
                    break;
                case TypeModifier.Out:
                    parameterText.Append("out ");
                    break;
                case TypeModifier.Ref:
                    parameterText.Append("ref ");
                    break;
            }

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

        var (returnType, _) = DecodeType(method.ReturnType, beefTypeToMappedType);

        if (returnType.ReturnValueConversion is not null)
        {
            call.Append("var returnValue = ");
        }

        call.Append($"_engineFunctions.{method.Name}(");

        foreach (var param in method.Parameters)
        {
            var (parameterType, parameterModifier) = DecodeType(param.Type, beefTypeToMappedType);
            parameters.Add(parameterType);

            if (parameterText.Length > 0)
            {
                parameterText.Append(", ");
                call.Append(", ");
            }

            switch (parameterModifier)
            {
                case TypeModifier.In:
                    parameterText.Append("in ");
                    break;
                case TypeModifier.Out:
                    parameterText.Append("out ");
                    break;
                case TypeModifier.Ref:
                    parameterText.Append("ref ");
                    break;
            }

            parameterText.Append($"{parameterType.CSharpWrapperType} {param.Name}");

            switch (parameterModifier)
            {
                case TypeModifier.In:
                    call.Append("in ");
                    break;
                case TypeModifier.Out:
                    call.Append("out ");
                    break;
                case TypeModifier.Ref:
                    call.Append("ref ");
                    break;
            }

            if (parameterModifier == TypeModifier.Out && parameterType.WrapperOutConversion is not null)
            {
                string tmpArgName = $"{param.Name}Tmp";

                call.Append($"var {tmpArgName}");
                
                cleanup.Append("\t\t");
                cleanup.AppendFormat(parameterType.WrapperOutConversion, tmpArgName, param.Name);
                cleanup.AppendLine();
            }
            else if (parameterType.WrapperConvertInput is not null)
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

                 (MappedType newMapping, _) = DecodeType(beefTypeName, beefTypeToMappedType);
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
                       """);

         wrappers.Append("""
                    // <auto-generated />
                    using System;
                    using System.Collections.Generic;
                    using System.Runtime.InteropServices;

                    namespace GlitchyEngine;

                    internal static unsafe partial class ScriptGlue
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

         engineFunctions.Append("\n}");
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
