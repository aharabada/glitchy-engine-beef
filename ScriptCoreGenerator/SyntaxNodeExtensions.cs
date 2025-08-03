#nullable enable

using System;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace ScriptCoreGenerator;

public static class SyntaxNodeExtensions
{
    public static string? ExtractName(NameSyntax? name)
    {
        return name switch
        {
            SimpleNameSyntax ins => ins.Identifier.Text,
            QualifiedNameSyntax qns => qns.Right.Identifier.Text,
            _ => null
        };
    }

    public static T GetParent<T>(this SyntaxNode node)
    {
        var parent = node.Parent;
        while (true)
        {
            if (parent == null)
            {
                throw new Exception();
            }

            if (parent is T t)
            {
                return t;
            }

            parent = parent.Parent;
        }
    }

    public static T? GetParentOrNull<T>(this SyntaxNode node) where T : SyntaxNode
    {
        SyntaxNode? parent = node.Parent;

        while (true)
        {
            switch (parent)
            {
                case null:
                    return null;
                case T t:
                    return t;
                default:
                    parent = parent.Parent;
                    break;
            }
        }
    }

    /// <summary>
    /// determine the namespace the class/enum/struct is declared in, if any
    /// </summary>
    public static string GetNamespace(this BaseTypeDeclarationSyntax syntax)
    {
        // If we don't have a namespace at all we'll return an empty string
        // This accounts for the "default namespace" case
        string nameSpace = string.Empty;

        // Get the containing syntax node for the type declaration
        // (could be a nested type, for example)
        SyntaxNode? potentialNamespaceParent = syntax.Parent;
    
        // Keep moving "out" of nested classes etc until we get to a namespace
        // or until we run out of parents
        while (potentialNamespaceParent != null &&
               potentialNamespaceParent is not NamespaceDeclarationSyntax
               && potentialNamespaceParent is not FileScopedNamespaceDeclarationSyntax)
        {
            potentialNamespaceParent = potentialNamespaceParent.Parent;
        }

        // Build up the final namespace by looping until we no longer have a namespace declaration
        if (potentialNamespaceParent is BaseNamespaceDeclarationSyntax namespaceParent)
        {
            // We have a namespace. Use that as the type
            nameSpace = namespaceParent.Name.ToString();
        
            // Keep moving "out" of the namespace declarations until we 
            // run out of nested namespace declarations
            while (true)
            {
                if (namespaceParent.Parent is not NamespaceDeclarationSyntax parent)
                {
                    break;
                }

                // Add the outer namespace as a prefix to the final namespace
                nameSpace = $"{namespaceParent.Name}.{nameSpace}";
                namespaceParent = parent;
            }
        }

        // return the final namespace
        return nameSpace;
    }

}