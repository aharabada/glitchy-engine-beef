using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Diagnostics;

namespace GlitchyEngine.StyleChecker;

//[DiagnosticAnalyzer(LanguageNames.CSharp)]
public class StyleChecker : DiagnosticAnalyzer
{
    public const string DiagnosticId = "MakeConst2";

    private static readonly LocalizableString Title =
        new LocalizableResourceString(nameof(Strings.AnalyzerTitle), Strings.ResourceManager, typeof(Strings));
    private static readonly LocalizableString MessageFormat =
        new LocalizableResourceString(nameof(Strings.AnalyzerMessageFormat), Strings.ResourceManager, typeof(Strings));
    private static readonly LocalizableString Description =
        new LocalizableResourceString(nameof(Strings.AnalyzerDescription), Strings.ResourceManager, typeof(Strings));

    private const string Category = "Usage";

    private static readonly DiagnosticDescriptor Rule = new DiagnosticDescriptor(DiagnosticId, Title, MessageFormat,
        Category, DiagnosticSeverity.Warning, isEnabledByDefault: true, description: Description);

    public override ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics => ImmutableArray.Create(Rule);

    public override void Initialize(AnalysisContext context)
    {
        context.ConfigureGeneratedCodeAnalysis(GeneratedCodeAnalysisFlags.None);
        context.EnableConcurrentExecution();
        
        context.RegisterSyntaxNodeAction(AnalyzeNode, SyntaxKind.LocalDeclarationStatement);
    }

    private void AnalyzeNode(SyntaxNodeAnalysisContext context)
    {
        var localDeclaration = (LocalDeclarationStatementSyntax)context.Node;

        if (localDeclaration.Modifiers.Any(SyntaxKind.ConstKeyword))
        {
            return;
        }

        // Perform data flow analysis on the local declaration.
        DataFlowAnalysis dataFlowAnalysis = context.SemanticModel.AnalyzeDataFlow(localDeclaration);

        // Retrieve the local symbol for each variable in the local declaration
        // and ensure that it is not written outside of the data flow analysis region.
        VariableDeclaratorSyntax variable = localDeclaration.Declaration.Variables.Single();
        ISymbol variableSymbol = context.SemanticModel.GetDeclaredSymbol(variable, context.CancellationToken);
        if (dataFlowAnalysis.WrittenOutside.Contains(variableSymbol))
        {
            return;
        }

        context.ReportDiagnostic(Diagnostic.Create(Rule, context.Node.GetLocation(), localDeclaration.Declaration.Variables.First().Identifier.ValueText));
    }
}
