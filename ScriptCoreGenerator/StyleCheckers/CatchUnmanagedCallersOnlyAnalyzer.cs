using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Diagnostics;

namespace ScriptCoreGenerator.StyleCheckers;

/// <summary>
/// Checks that methods with UnmanagedCallersOnly attribute always have a try-catch statement to ensure that exceptions never escape out of the C# code - as this would crash the application.
/// </summary>
[DiagnosticAnalyzer(LanguageNames.CSharp)]
public class CatchUnmanagedCallersOnlyAnalyzer : DiagnosticAnalyzer
{
    public const string DiagnosticId = "GE0001";

    private static readonly LocalizableString Title =
        new LocalizableResourceString(nameof(Strings.CatchUnmanagedCallers_Title), Strings.ResourceManager,
            typeof(Strings));

    private static readonly LocalizableString MessageFormat =
        new LocalizableResourceString(nameof(Strings.CatchUnmanagedCallers_MessageFormat), Strings.ResourceManager,
            typeof(Strings));

    private static readonly LocalizableString Description =
        new LocalizableResourceString(nameof(Strings.CatchUnmanagedCallers_Description), Strings.ResourceManager,
            typeof(Strings));

    private const string Category = "Usage";

    private static readonly DiagnosticDescriptor Rule = new(DiagnosticId, Title, MessageFormat,
        Category, DiagnosticSeverity.Error, isEnabledByDefault: true, description: Description);

    public override ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics => ImmutableArray.Create(Rule);

    public override void Initialize(AnalysisContext context)
    {
        context.ConfigureGeneratedCodeAnalysis(GeneratedCodeAnalysisFlags.None);
        context.EnableConcurrentExecution();

        context.RegisterSyntaxNodeAction(AnalyzeNode, SyntaxKind.Attribute);
    }

    private void AnalyzeNode(SyntaxNodeAnalysisContext context)
    {
        var attributeNode = (AttributeSyntax)context.Node;

        if (SyntaxNodeExtensions.ExtractName(attributeNode.Name) is not ("UnmanagedCallersOnly" or "UnmanagedCallersOnlyAttribute"))
            return;

        MethodDeclarationSyntax? method = attributeNode.GetParentOrNull<MethodDeclarationSyntax>();


        if (method is null)
            return;
        
        void ReportDiagnostic()
        {
            context.ReportDiagnostic(Diagnostic.Create(Rule, attributeNode.GetLocation(), method.Identifier.ValueText));
        }

        if (method.Body is not null)
        {
            // Check if the outer most statement is a try-catch block.
            if (method.Body.Statements.FirstOrDefault() is TryStatementSyntax tryStatement)
            {
                // Check if the try block has a catch clause.
                if (tryStatement.Catches.Count == 0)
                {
                    ReportDiagnostic();
                    return;
                }

                // Report a diagnostic if there is no catch block that catches System.Exception.
                if (tryStatement.Catches.All(c =>
                    {
                        TypeSyntax? typeSyntax = c.Declaration?.Type;

                        if (typeSyntax is null)
                            return true;

                        TypeInfo typeInfo = context.SemanticModel.GetTypeInfo(typeSyntax);
                        return typeInfo.Type?.Name != "Exception";
                    }))
                {
                    ReportDiagnostic();
                    return;
                }
            }
            else
            {
                // If there is no try-catch block, report a diagnostic.
                ReportDiagnostic();
                return;
            }
        }
        else if (method.ExpressionBody is not null)
        {
            // Expression-bodied methods cannot have an outer-most try-catch block.
            ReportDiagnostic();
            return;
        }
    }
}
