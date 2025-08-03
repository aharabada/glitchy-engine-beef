using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CodeActions;
using Microsoft.CodeAnalysis.CodeFixes;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Rename;
using Microsoft.CodeAnalysis.Text;
using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Composition;
using System.Linq;
using System.Linq.Expressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.CodeAnalysis.Formatting;

namespace ScriptCoreGenerator.StyleCheckers
{
    [ExportCodeFixProvider(LanguageNames.CSharp, Name = nameof(CatchUnmanagedCallersOnlyAnalyzer)), Shared]
    public class CatchUnmanagedCallersOnlyFixProvider : CodeFixProvider
    {
        public sealed override ImmutableArray<string> FixableDiagnosticIds => ImmutableArray.Create(CatchUnmanagedCallersOnlyAnalyzer.DiagnosticId);

        public sealed override FixAllProvider GetFixAllProvider()
        {
            // See https://github.com/dotnet/roslyn/blob/main/docs/analyzers/FixAllProvider.md for more information on Fix All Providers
            return WellKnownFixAllProviders.BatchFixer;
        }

        public sealed override async Task RegisterCodeFixesAsync(CodeFixContext context)
        {
            var root = await context.Document.GetSyntaxRootAsync(context.CancellationToken).ConfigureAwait(false);

            var diagnostic = context.Diagnostics.First();
            var diagnosticSpan = diagnostic.Location.SourceSpan;

            // Find the type declaration identified by the diagnostic.
            var declaration = root.FindToken(diagnosticSpan.Start).Parent.AncestorsAndSelf().OfType<MethodDeclarationSyntax>().First();

            // Register a code action that will invoke the fix.
            context.RegisterCodeFix(
                CodeAction.Create(
                    title: Strings.CatchUnmanagedCallers_FixTitle,
                    createChangedDocument: c => AddTryCatchAsync(context.Document, declaration, c),
                    equivalenceKey: nameof(Strings.CatchUnmanagedCallers_FixTitle)),
                diagnostic);
        }

        private async Task<Document> AddTryCatchAsync(Document contextDocument, MethodDeclarationSyntax method, CancellationToken cancellationToken)
        {
            if (method.Body is not null)
            {
                // Create a try-catch block
                var tryBlock = SyntaxFactory.Block(method.Body.Statements);
                var catchClause = SyntaxFactory.CatchClause()
                    .WithDeclaration(SyntaxFactory.CatchDeclaration(SyntaxFactory.IdentifierName("Exception"))
                    .WithIdentifier(SyntaxFactory.Identifier("ex")))
                    .WithBlock(SyntaxFactory.Block(
                        SyntaxFactory.SingletonList<StatementSyntax>(
                            SyntaxFactory.ExpressionStatement(
                                SyntaxFactory.InvocationExpression(
                                    SyntaxFactory.IdentifierName("Console.WriteLine"))
                                .WithArgumentList(
                                    SyntaxFactory.ArgumentList(
                                        SyntaxFactory.SingletonSeparatedList(
                                            SyntaxFactory.Argument(
                                                SyntaxFactory.IdentifierName("ex.Message")))))))));

                var tryStatement = SyntaxFactory.TryStatement()
                    .WithBlock(tryBlock)
                    .WithCatches(SyntaxFactory.SingletonList(catchClause));

                // Replace the method body with the new try-catch block
                var newMethodBody = method.Body.WithStatements(SyntaxFactory.SingletonList<StatementSyntax>(tryStatement));
                var newMethod = method.WithBody(newMethodBody);

                // Update the syntax tree
                var oldRoot = await contextDocument.GetSyntaxRootAsync(cancellationToken).ConfigureAwait(false);
                var newRoot = oldRoot.ReplaceNode(method, newMethod);

                return contextDocument.WithSyntaxRoot(newRoot);
            }

            return contextDocument;
        }
    }
}
