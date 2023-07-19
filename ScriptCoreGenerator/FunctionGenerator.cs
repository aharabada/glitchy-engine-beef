using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace ScriptCoreGenerator
{
    [Generator]
    public class HelloSourceGenerator : ISourceGenerator
    {
        public void Execute(GeneratorExecutionContext context)
        {
            var receiver = (MainSyntaxReceiver)context.SyntaxReceiver;



            string output = @"
namespace Test{
public class Test
{
    public static void P() => GlitchyEngine.Log.Error(""Hello World"");
}}
";

            // Code generation goes here
            context.AddSource("Test/Hello.g.cs", output);
        }

        public void Initialize(GeneratorInitializationContext context)
        {
            context.RegisterForSyntaxNotifications(() => new MainSyntaxReceiver());
        }
    }

    public class MainSyntaxReceiver : ISyntaxReceiver
    {
        public DefinitionAggregate Definitions { get; } = new();
        public GivethsAggregate Giveths { get; } = new();

        public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
        {
            Definitions.OnVisitSyntaxNode(syntaxNode);
            Giveths.OnVisitSyntaxNode(syntaxNode);
        }
    }

    public class DefinitionAggregate : ISyntaxReceiver
    {
        public List<Capture> Captures { get; } = new();

        public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
        {
            if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "Define" } } attr)
            {
                return;
            }

            var method = attr.GetParent<MethodDeclarationSyntax>();
            var key = method.Identifier.Text;

            Captures.Add(new Capture(key, method));
        }

        public record Capture(string Key, MethodDeclarationSyntax Method)
        {
            public string Key { get; } = Key;
            public MethodDeclarationSyntax Method { get; } = Method;
        }
    }

    public class GivethsAggregate : ISyntaxReceiver
    {
        public List<Capture> Captures { get; } = new();

        public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
        {
            if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "Give" } } attr)
            {
                return;
            }

            var target = (attr.ArgumentList.Arguments.Single().Expression as LiteralExpressionSyntax).Token.ValueText;
            
            var method = attr.GetParent<MethodDeclarationSyntax>();
            var @class = attr.GetParent<ClassDeclarationSyntax>();

            Captures.Add(new Capture(target, method, @class));
        }

        public record Capture(string TargetImplementation, MethodDeclarationSyntax Method, ClassDeclarationSyntax Class)
        {
            public string TargetImplementation { get; } = TargetImplementation;
            public MethodDeclarationSyntax Method { get; } = Method;
            public ClassDeclarationSyntax Class { get; } = Class;
        }
    }
}
