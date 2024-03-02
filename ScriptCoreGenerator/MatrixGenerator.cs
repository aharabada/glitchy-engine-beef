using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace ScriptCoreGenerator;

[Generator]
public class MatrixGenerator : ISourceGenerator
{
    public void Initialize(GeneratorInitializationContext context)
    {
        context.RegisterForSyntaxNotifications(() => new MatrixSyntaxReceiver());
    }

    public void Execute(GeneratorExecutionContext context)
    {
        var receiver = (MatrixSyntaxReceiver?)context.SyntaxReceiver;

        if (receiver == null) return;

        StringBuilder builder = new();

        foreach (var matrix in receiver.Matrices)
        {
            builder.Clear();

            // Copy all usings from the original file
            builder.AppendLine(matrix.Struct.GetParent<CompilationUnitSyntax>().Usings.ToFullString());

            builder.Append($$"""
                             #nullable enable
                             
                             using System;
                             // For "DebuggerBrowsable" and "DebuggerBrowsableState"
                             using System.Diagnostics;

                             namespace {{matrix.Struct.GetNamespace()}};

                             public partial struct {{matrix.Name}}
                             {

                             """);

            GenerateFields(matrix, builder);
            GenerateConstructors(matrix, builder);

            GenerateCasts(matrix, builder);

            GenerateArrayAccess(matrix, builder);
            
            GenerateEqualityOperators(matrix, builder);

            GenerateEqualsMethod(matrix, builder);

            GenerateGetHashCode(matrix, builder);
            
            if (receiver.ComparableReceiver.Matrices.Contains(matrix.Name))
            {
                GenerateComparisonOperators(matrix, builder);
            }
            
            if (receiver.MathReceiver.Matrices.Contains(matrix.Name))
            {
                GenerateMathOperators(matrix, builder);
            }
            
            if (receiver.LogicReceiver.Matrices.Contains(matrix.Name))
            {
                GenerateLogicOperators(matrix, builder);
            }
            
            GenerateCastOperators(receiver.Matrices, matrix, matrix.ElementTypeName, builder, context);
            
            foreach (var cast in receiver.CastReceiver.Casts.Where(c => c.SourceTypeName == matrix.Name))
            {
                GenerateCastOperators(receiver.Matrices, matrix, cast.TargetElementTypeName, builder, context);

            }

            foreach (var vectorMultiplication in receiver.VectorMultiplicationReceiver.Multiplications.Where(c => c.MatrixType == matrix.Name))
            {
                VectorSyntaxReceiver.VectorDefinition vectorDefinition = receiver.VectorReceiver.Vectors.First(v => v.Name == vectorMultiplication.VectorType);

                if (vectorDefinition.ComponentCount != matrix.Rows && vectorDefinition.ComponentCount != matrix.Columns)
                {
                    context.ReportDiagnostic(Diagnostic.Create(
                        new DiagnosticDescriptor(
                            "SG0002",
                            "Vector dimensions don't match matrix dimensions.",
                            $"Cannot generate vector-matrix multiplication for \"{vectorDefinition.Name}\" to \"{matrix.Name}\" because the dimensions don't match. The vectors component-count must match the matrices rows or columns or both.",
                            "Vector Generator",
                            DiagnosticSeverity.Error,
                            true), matrix.Struct.GetLocation()));

                    continue;
                }

                GenerateMatrixMulVector(matrix, vectorDefinition, builder);
                GenerateVectorMulMatrix(matrix, vectorDefinition, builder);
            }
            
            GenerateToString(matrix, builder);
            
            // There are too many swizzles for 4x4 matrices, Rider is literally dying :(
            //GenerateSwizzle(matrix, builder);

            builder.AppendLine("}");

            context.AddSource($"{matrix.Name}.g.cs", builder.ToString());
        }
    }

    private void GenerateEqualsMethod(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append($$"""
                             public override bool Equals(object? obj)
                             {
                                 if (obj == null || obj is not {{matrix.Name}} other)
                                     return false;
                         
                                 return {{string.Join(" && ", Enumerable.Range(0, matrix.Rows).SelectMany(i => 
                                     Enumerable.Range(0, matrix.Columns).Select(j => 
                                         $"M{j + 1}{i + 1} == other.M{j + 1}{i + 1}")))}};
                             }
                         
                         
                         """);
    }
    
    private void GenerateGetHashCode(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append("""
                           public override int GetHashCode()
                           {
                               // Unchecked to allow overflow
                               unchecked
                               {
                                   int hash = 17;

                       """);

        for (int c = 0; c < matrix.Columns; c++)
        for (int r = 0; r < matrix.Rows; r++)
        {
            builder.Append($"\t\t\thash = hash * 23 + M{r + 1}{c + 1}.GetHashCode();\n");
        }

        builder.Append("""
                                   return hash;
                               }
                           }


                       """);
    }

    private void GenerateEqualityOperators(MatrixDefinition matrix, StringBuilder builder)
    {
        GenerateComparisonOperator("==", matrix, builder);
        GenerateComparisonOperator("!=", matrix, builder);
    }

    private void GenerateComparisonOperator(string op, MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append($$"""
                             public static bool{{matrix.Columns}}x{{matrix.Rows}} operator {{op}}({{matrix.Name}} left, {{matrix.Name}} right)
                             {
                                {{ComponentWiseCore(op, matrix)}}
                             }
                         
                         
                         """);
    }

    private void GenerateFields(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append($"\tpublic {matrix.ElementTypeName} ");

        for (int i = 0; i < matrix.Rows; i++)
        {
            for (int j = 0; j < matrix.Columns; j++)
            {
                if (i != 0 || j != 0)
                    builder.Append(", ");

                builder.Append($"M{j + 1}{i + 1}");
            }
        }

        builder.Append(";\n\n");
    }

    private void GenerateConstructors(MatrixDefinition matrix, StringBuilder builder)
    {
        GenerateSingleConstructor(matrix, builder);
        GenerateSingleElementConstructor(matrix, builder);
    }

    private void GenerateSingleConstructor(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append($$"""
                             /// <summary>
                             /// Creates a new {{matrix.Rows}}x{{matrix.Columns}} matrix with all elements set to the specified value.
                             /// </summary>
                             /// <param name="value">The value that all elements will be initialized with.</param>
                             public {{matrix.Name}}({{matrix.ElementTypeName}} value)
                             {
                        
                         """);

        for (int i = 0; i < matrix.Rows; i++)
        {
            for (int j = 0; j < matrix.Columns; j++)
            {
                builder.Append($"\t\tM{j + 1}{i + 1} = value;\n");
            }
        }

        builder.Append("\t}\n\n");
    }

    /// <summary>
    /// Generates a constructor that takes an argument for each element in the matrix.
    /// </summary>
    private void GenerateSingleElementConstructor(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append($$"""
                        /// <summary>
                        /// Creates a new {{matrix.Rows}}x{{matrix.Columns}} matrix with the specified elements.
                        /// </summary>
                        public {{matrix.Name}}({{string.Join(", ", 
                         Enumerable.Range(0, matrix.Rows).SelectMany(i => 
                             Enumerable.Range(0, matrix.Columns).Select(j => 
                                 $"{matrix.ElementTypeName} m{j + 1}{i + 1}")))
                        }})
                        {
                    
                    """);
        
        for (int i = 0; i < matrix.Rows; i++)
        {
            for (int j = 0; j < matrix.Columns; j++)
            {
                builder.Append($"\t\tM{j + 1}{i + 1} = m{j + 1}{i + 1};\n");
            }
        }
        
        builder.Append("\t}\n\n");
    }

    private void GenerateCasts(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append($$"""
                             public static implicit operator {{matrix.Name}}({{matrix.ElementTypeName}} value)
                             {
                                 return new {{matrix.Name}}(value);
                             }


                         """);
        
        // TODO: Casts to other matrix sizes?
    }

    private void GenerateArrayAccess(MatrixDefinition matrix, StringBuilder builder)
    {
        Generate1DArrayAccess(matrix, builder);
        Generate2DArrayAccess(matrix, builder);
    }
    
    private void Generate1DArrayAccess(MatrixDefinition matrix, StringBuilder builder)
    {
        StringBuilder getterSwitch = new();
        StringBuilder setterSwitch = new();

        for (int i = 0; i < matrix.Rows; i++)
        {
            for (int j = 0; j < matrix.Columns; j++)
            {
                getterSwitch.Append($$"""
                                  
                                              case {{i * matrix.Columns + j}}:
                                                  return M{{j + 1}}{{i + 1}};
                                  """);

                setterSwitch.Append($$"""
                                  
                                              case {{i * matrix.Columns + j}}:
                                                  M{{j + 1}}{{i + 1}} = value;
                                                  break;
                                  """);
            }
        }

        builder.Append($$"""
                             /// <summary>
                             /// Gets or sets the value at the specified index, indexed in a column-major order.
                             /// </summary>
                             /// <param name="index">The index of the element to get or set.</param>
                             /// <exception cref="IndexOutOfRangeException">Thrown when the index is out of range.</exception>
                             public {{matrix.ElementTypeName}} this[int index]
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

    private void Generate2DArrayAccess(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append($$"""
                             /// <summary>
                             /// Gets or sets the value at the specified row and column.
                             /// </summary>
                             /// <param name="row">The row of the element to get or set.</param>
                             /// <param name="column">The column of the element to get or set.</param>
                             /// <exception cref="IndexOutOfRangeException">Thrown when the index is out of range.</exception>
                             public {{matrix.ElementTypeName}} this[int row, int column]
                             {
                                 get => this[row * {{matrix.Columns}} + column];

                                 set => this[row * {{matrix.Columns}} + column] = value;
                             }


                         """);
    }
    
    private void GenerateComparisonOperators(MatrixDefinition matrix, StringBuilder builder)
    {
        GenerateComparisonOperator(">", matrix, builder);
        GenerateComparisonOperator("<", matrix, builder);
        GenerateComparisonOperator(">=", matrix, builder);
        GenerateComparisonOperator("<=", matrix, builder);
    }

    private void GenerateMathOperators(MatrixDefinition matrix, StringBuilder builder)
    {
        GenerateUnaryOperatorOverload("+", matrix, builder);
        GenerateUnaryOperatorOverload("-", matrix, builder);
        
        GenerateComponentWiseOperator("+", matrix, builder);
        GenerateComponentWiseOperator("-", matrix, builder);
        
        GenerateMatrixMultiplications(matrix, builder);
    }

    private void GenerateUnaryOperatorOverload(string op, MatrixDefinition matrix, StringBuilder builder)
    {
        string args = string.Join(",\n", Enumerable.Range(0, matrix.Rows).SelectMany(i => 
            Enumerable.Range(0, matrix.Columns).Select(j => 
                $"\t\t\t{op}value.M{j + 1}{i + 1}")));
        
        builder.Append($$"""
                             public static {{matrix.Name}} operator {{op}}({{matrix.Name}} value)
                             {
                                 return new(
                         {{args}});
                             }


                         """);
    }

    private void GenerateComponentWiseOperator(string op, MatrixDefinition matrix, StringBuilder builder)
    {
        string arguments = string.Join(",\n", Enumerable.Range(0, matrix.Rows).SelectMany(i => 
            Enumerable.Range(0, matrix.Columns).Select(j => 
                $"\t\t\tleft.M{j + 1}{i + 1} {op} right.M{j + 1}{i + 1}")));

        builder.Append($$"""
                             public static {{matrix.Name}} operator {{op}}({{matrix.Name}} left, {{matrix.Name}} right)
                             {
                                 {{ComponentWiseCore(op, matrix)}}
                             }


                         """);
    }

    private string ComponentWiseCore(string op, MatrixDefinition matrix)
    {
        string arguments = string.Join(",\n", Enumerable.Range(0, matrix.Rows).SelectMany(i => 
            Enumerable.Range(0, matrix.Columns).Select(j => 
                $"\t\t\tleft.M{j + 1}{i + 1} {op} right.M{j + 1}{i + 1}")));

        StringBuilder builder = new();
        
        builder.Append($$"""
                         return new(
                         {{arguments}});
                         """);

        return builder.ToString();
    }

    private void GenerateLogicOperators(MatrixDefinition matrix, StringBuilder builder)
    {
        GenerateComponentWiseOperator("&", matrix, builder);
        GenerateComponentWiseOperator("^", matrix, builder);
        GenerateComponentWiseOperator("|", matrix, builder);
    }

    private void GenerateCastOperators(List<MatrixDefinition> matrices, MatrixDefinition sourceMatrix, string targetElementTypeName, StringBuilder builder, GeneratorExecutionContext context)
    {
        IEnumerable<MatrixDefinition> targetMatrices =
            matrices.Where(target => target.ElementTypeName == targetElementTypeName && 
                                     target.Columns <= sourceMatrix.Columns && target.Rows <= sourceMatrix.Rows &&
                                     (target.Columns < sourceMatrix.Columns || target.Rows < sourceMatrix.Rows));

        foreach (var targetMatrixDefinition in targetMatrices)
        {
            MatrixCastSyntaxReceiver.Cast cast = new MatrixCastSyntaxReceiver.Cast(sourceMatrix.Name, targetMatrixDefinition.Name, true); 
                
            GenerateCastOperator(cast, sourceMatrix, targetMatrixDefinition, builder, context);
        }
    }

    private void GenerateCastOperator(MatrixCastSyntaxReceiver.Cast cast, MatrixDefinition sourceMatrix, MatrixDefinition targetMatrix, StringBuilder builder, GeneratorExecutionContext context)
    {
        if (sourceMatrix.Columns < targetMatrix.Columns || sourceMatrix.Rows < targetMatrix.Rows)
        {
            context.ReportDiagnostic(Diagnostic.Create(
                new DiagnosticDescriptor(
                    "SG0001",
                    "Matrix-Dimensions don't match for cast.",
                    $"Cannot cast from \"{sourceMatrix.Name}\" to \"{targetMatrix.Name}\" because the source matrix is smaller than the target matrix.",
                    "Matrix Generator",
                    DiagnosticSeverity.Error,
                    true), sourceMatrix.Struct.GetLocation()));

            return;
        }

        builder.Append($$"""
                    public static {{(cast.IsExplicit ? "explicit" : "implicit")}} operator {{targetMatrix.Name}}({{sourceMatrix.Name}} value)
                    {
                        {{targetMatrix.Name}} result = new();
                {{string.Join("\n", Enumerable.Range(0, targetMatrix.Rows).SelectMany(i =>
                    Enumerable.Range(0, targetMatrix.Columns).Select(j =>
                    $"\t\tresult.M{j + 1}{i + 1} = ({targetMatrix.ElementTypeName})value.M{j + 1}{i + 1};")))}}
                        
                        return result;
                    }
                
                
                """);
    }

    private void GenerateMatrixMultiplications(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append($$"""
                 public static {{matrix.Name}} operator *({{matrix.ElementTypeName}} left, {{matrix.Name}} right)
                 {
                     return new(
             {{string.Join(",\n", Enumerable.Range(0, matrix.Rows).SelectMany(i => 
                 Enumerable.Range(0, matrix.Columns).Select(j => 
                     $"\t\t\tleft * right.M{j + 1}{i + 1}")))}}
                        );
                 }
             
                 public static {{matrix.Name}} operator *({{matrix.Name}} left, {{matrix.ElementTypeName}} right)
                 {
                     return new(
             {{string.Join(",\n", Enumerable.Range(0, matrix.Rows).SelectMany(i => 
                 Enumerable.Range(0, matrix.Columns).Select(j => 
                     $"\t\t\tleft.M{j + 1}{i + 1} * right")))}}
                        );
                 }
             
                 public static {{matrix.Name}} ComponentWiseMultiply({{matrix.Name}} left, {{matrix.Name}} right)
                 {
                     {{ComponentWiseCore("*", matrix)}}
                 }
             
                 public static {{matrix.Name}} ComponentWiseDivide({{matrix.Name}} left, {{matrix.Name}} right)
                 {
                     {{ComponentWiseCore("/", matrix)}}
                 }
             
                 public static {{matrix.Name}} ComponentWiseModulo({{matrix.Name}} left, {{matrix.Name}} right)
                 {
                     {{ComponentWiseCore("%", matrix)}}
                 }
             
             
             """);

        GenerateMatrixMulMatrix(matrix, builder);
    }

    /// <summary>
    /// Overloads the multiplication operator for the matrix multiplication from linear algebra.
    /// </summary>
    private void GenerateMatrixMulMatrix(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append($$"""
                     public static {{matrix.Name}} operator *({{matrix.Name}} left, {{matrix.Name}} right)
                     {
                         {{matrix.Name}} result = new();
                 
                 """);

        for (int r = 0; r < matrix.Rows; r++)
        {
            for (int c = 0; c < matrix.Columns; c++)
            {
                builder.Append($"\t\tresult.M{r + 1}{c + 1} = ");
                
                for (int k = 0; k < matrix.Columns; k++)
                {
                    if (k != 0)
                        builder.Append(" + ");
                    
                    builder.Append($"left.M{r + 1}{k + 1} * right.M{k + 1}{c + 1}");
                }
                
                builder.Append(";\n");
            }
        }
        
        builder.Append("""
                         
                                 return result;
                             }

                         
                         """);
    }

    private void GenerateMatrixMulVector(MatrixDefinition matrix, VectorSyntaxReceiver.VectorDefinition vector, StringBuilder builder)
    {
        if (vector.ComponentCount != matrix.Columns)
            return;
        
        builder.Append($$"""
                             public static {{vector.Name}} operator *({{matrix.Name}} left, {{vector.Name}} right)
                             {
                                 {{vector.Name}} result = new();

                         """);

        for (int i = 0; i < vector.ComponentCount; i++)
        {
            builder.Append($"\t\tresult.{VectorGenerator.ComponentNames[i]} = ");
            
            for (int j = 0; j < matrix.Columns; j++)
            {
                if (j != 0)
                    builder.Append(" + ");
                
                builder.Append($"left.M{i + 1}{j + 1} * right.{VectorGenerator.ComponentNames[j]}");
            }

            builder.Append(";\n");
        }
        
        builder.Append("""
                       
                               return result;
                           }


                       """);
    }
    
    private void GenerateVectorMulMatrix(MatrixDefinition matrix, VectorSyntaxReceiver.VectorDefinition vector, StringBuilder builder)
    {
        if (vector.ComponentCount != matrix.Rows)
            return;
        
        builder.Append($$"""
                             public static {{vector.Name}} operator *({{vector.Name}} left, {{matrix.Name}} right)
                             {
                                 {{vector.Name}} result = new();

                         """);

        for (int i = 0; i < vector.ComponentCount; i++)
        {
            builder.Append($"\t\tresult.{VectorGenerator.ComponentNames[i]} = ");
            
            for (int j = 0; j < matrix.Rows; j++)
            {
                if (j != 0)
                    builder.Append(" + ");

                builder.Append($"left.{VectorGenerator.ComponentNames[j]} * right.M{j + 1}{i + 1}");
            }

            builder.Append(";\n");
        }
        
        builder.Append("""
                       
                               return result;
                           }


                       """);
    }
    
    private void GenerateToString(MatrixDefinition matrix, StringBuilder builder)
    {
        builder.Append("""
                           public override string ToString() => $"
                       """);
        
        for (int i = 0; i < matrix.Rows; i++)
        {
            if (i != 0)
                builder.Append(", ");
            
            builder.Append("{{");
            
            for (int c = 0; c < matrix.Columns; c++)
            {
                if (c != 0)
                    builder.Append(", ");
                
                builder.Append($"M{c + 1}{i + 1}: {{M{c + 1}{i + 1}}}");
            }
            
            builder.Append("}}");
        }

        builder.Append("\";\n\n");
    }

    private string BuildSwizzleName(IEnumerable<int> components)
    {
        StringBuilder builder = new();
        
        foreach (var component in components)
        {
            //Reconstruct row and column from index
            builder.Append($"M{component % 4 + 1}{component / 4 + 1}");
        }
        
        return builder.ToString();
    }

    /**
     * Returns true if the swizzle operator is invalid (same component assigned twice).
    */
    static bool IsSwizzleSetterValid(IEnumerable<int> components)
    {
        return components.Distinct().Count() == components.Count();
    }
    
    private void GenerateSwizzle(MatrixDefinition matrix, StringBuilder builder)
    {
        int[] cmp = new int[4];
        
        for (int componentCount = 2; componentCount <= 4; componentCount++)
        {
            int cmp2max = componentCount > 2 ? matrix.Rows * matrix.Columns : 1;
            int cmp3max = componentCount > 3 ? matrix.Rows * matrix.Columns : 1;

            for (cmp[0] = 0; cmp[0] < matrix.Rows * matrix.Columns; cmp[0]++)
            for (cmp[1] = 0; cmp[1] < matrix.Rows * matrix.Columns; cmp[1]++)
            for (cmp[2] = 0; cmp[2] < cmp2max; cmp[2]++)
            for (cmp[3] = 0; cmp[3] < cmp3max; cmp[3]++)
            {
                StringBuilder swizzleName = new();
                StringBuilder swizzleGetterConstructor = new();
                StringBuilder swizzleSetterConstructor = new();

                bool setterValid = IsSwizzleSetterValid(cmp.Take(componentCount));
                
                for (int c = 0; c < componentCount; c++)
                {
                    int elementIndex = cmp[c]; 
                    
                    //Reconstruct row and column from index
                    string element = $"M{elementIndex % 4 + 1}{elementIndex / 4 + 1}";
                    
                    swizzleName.Append(element);
                    
                    if(c != 0)
                    {
                        swizzleGetterConstructor.Append(", ");
                    }
                    swizzleGetterConstructor.Append(element);

                    if (setterValid)
                    {
                        swizzleSetterConstructor.Append($"\n\t\t\t{element} = value.{VectorGenerator.ComponentNames[c]};");
                    }
                }
                
                builder.Append($$"""
                                     [DebuggerBrowsable(DebuggerBrowsableState.Never)]
                                     public {{matrix.BaseName}}{{componentCount}} {{swizzleName}}
                                     {
                                         get => new({{swizzleGetterConstructor}});

                                 """);
                
                if (setterValid)
                {
                    builder.Append($$"""
                                             set
                                             {{{swizzleSetterConstructor}}
                                             }

                                     """);
                }
                
                builder.Append("\t}\n\n");
            }
        }
    }
}

public class MatrixDefinition
{
    public string Name { get; }
    public StructDeclarationSyntax Struct { get; }
    
    public int Rows { get; }
    public int Columns { get; }
    
    public string BaseName { get; }
    
    public string ElementTypeName { get; }
    
    public MatrixDefinition(string name, StructDeclarationSyntax @struct, int rows, int columns, string baseName, string elementTypeName)
    {
        Name = name;
        Struct = @struct;
        Rows = rows;
        Columns = columns;
        BaseName = baseName;
        ElementTypeName = elementTypeName;
    }
}

public class MatrixSyntaxReceiver : ISyntaxReceiver
{
    public ComparableMatrixSyntaxReceiver ComparableReceiver = new();
    public MatrixMathSyntaxReceiver MathReceiver = new();
    public MatrixLogicSyntaxReceiver LogicReceiver = new();
    public MatrixVectorMultiplicationSyntaxReceiver VectorMultiplicationReceiver = new();
    public MatrixCastSyntaxReceiver CastReceiver = new();

    public VectorSyntaxReceiver VectorReceiver = new();
    
    public List<MatrixDefinition> Matrices { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        VectorReceiver.OnVisitSyntaxNode(syntaxNode);
        
        ComparableReceiver.OnVisitSyntaxNode(syntaxNode);
        MathReceiver.OnVisitSyntaxNode(syntaxNode);
        LogicReceiver.OnVisitSyntaxNode(syntaxNode);
        VectorMultiplicationReceiver.OnVisitSyntaxNode(syntaxNode);
        CastReceiver.OnVisitSyntaxNode(syntaxNode);
        
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "Matrix" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;
        
        if (attr?.ArgumentList?.Arguments == null || attr.ArgumentList.Arguments.Count != 4)
            return;
        
        string? elementTypeName = (attr.ArgumentList.Arguments[0].Expression as TypeOfExpressionSyntax)?.Type.ToFullString();
        
        if (elementTypeName == null)
            return;

        int? columnCount = (attr.ArgumentList.Arguments[1].Expression as LiteralExpressionSyntax)?.Token.Value as int?;
        
        if (columnCount == null)
            return;
        
        int? rowCount = (attr.ArgumentList.Arguments[2].Expression as LiteralExpressionSyntax)?.Token.Value as int?;
        
        if (rowCount == null)
            return;
        
        string? baseName = (attr.ArgumentList.Arguments[3].Expression as LiteralExpressionSyntax)?.Token.ValueText;

        if (baseName == null)
            return;
        
        Matrices.Add(new MatrixDefinition(name, @struct, rowCount.Value, columnCount.Value, baseName, elementTypeName));
    }
}

public class ComparableMatrixSyntaxReceiver : ISyntaxReceiver
{
    public List<string> Matrices { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "ComparableMatrix" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;
        
        Matrices.Add(name);
    }
}

public class MatrixMathSyntaxReceiver : ISyntaxReceiver
{
    public List<string> Matrices { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "MatrixMath" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;
        
        Matrices.Add(name);
    }
}

public class MatrixLogicSyntaxReceiver : ISyntaxReceiver
{
    public List<string> Matrices { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "MatrixLogic" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var name = @struct.Identifier.Text;
        
        Matrices.Add(name);
    }
}

public class MatrixVectorMultiplicationSyntaxReceiver : ISyntaxReceiver
{
    public List<Multiplication> Multiplications { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "MatrixVectorMultiplication" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var matrixType = @struct.Identifier.Text;
        
        string? vectorType = (attr.ArgumentList?.Arguments[0].Expression as TypeOfExpressionSyntax)?.Type.ToFullString();
        
        if (vectorType == null)
            return;

        Multiplications.Add(new Multiplication(matrixType, vectorType));
    }

    public record Multiplication(string MatrixType, string VectorType)
    {
        public string MatrixType { get; } = MatrixType;
        public string VectorType { get; } = VectorType;
    }
}

public class MatrixCastSyntaxReceiver : ISyntaxReceiver
{
    public List<Cast> Casts { get; } = new();
    
    public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
    {
        if (syntaxNode is not AttributeSyntax { Name: IdentifierNameSyntax { Identifier.Text: "MatrixCast" } } attr)
            return;

        var @struct = attr.GetParent<StructDeclarationSyntax>();
        var sourceTypeName = @struct.Identifier.Text;

        var targetElementTypeName = (attr.ArgumentList?.Arguments[0].Expression as TypeOfExpressionSyntax)?.Type.ToFullString();
        
        if (targetElementTypeName == null)
            return;
        
        var isExplicit = (attr.ArgumentList?.Arguments[1].Expression as LiteralExpressionSyntax)?.Token.Value as bool?;
        
        if (isExplicit == null)
            return;

        Casts.Add(new Cast(sourceTypeName, targetElementTypeName, isExplicit.Value));
    }

    public record Cast (string SourceTypeName, string TargetElementTypeName, bool IsExplicit)
    {
        public string SourceTypeName { get; } = SourceTypeName;
        public string TargetElementTypeName { get; } = TargetElementTypeName;
        public bool IsExplicit { get; } = IsExplicit;
    }
}
