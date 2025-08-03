using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Threading.Tasks;

using VerifyCS = MakeConst.Test.CSharpCodeFixVerifier<
    ScriptCoreGenerator.StyleCheckers.CatchUnmanagedCallersOnlyAnalyzer,
    ScriptCoreGenerator.StyleCheckers.CatchUnmanagedCallersOnlyFixProvider>;

namespace ScriptCoreGenerator.Test.StyleCheckers
{
    [TestClass]
    public class CatchUnmanagedCallersOnlyTest
    {
        //No diagnostics expected to show up
        [TestMethod]
        public async Task TestEmpty()
        {
            var test = @"";

            await VerifyCS.VerifyAnalyzerAsync(test);
        }

        [TestMethod]
        public async Task TestNoDiagnosticsMethodWithStatementBlock()
        {
            var test = @"""
                using System;

                class Program
                {
                    static void Main()
                    {
                        Console.WriteLine(i);
                    }
                }
                """;

            await VerifyCS.VerifyAnalyzerAsync(test);
        }

        [TestMethod]
        public async Task TestNoDiagnosticsWithArrowFunction()
        {
            var test = @"""
                using System;

                class Program
                {
                    static void Main() => Console.WriteLine(i);
                }
                """;

            await VerifyCS.VerifyAnalyzerAsync(test);
        }

        [TestMethod]
        public async Task TestNoDiagnosticWithCorrectMethod()
        {
            await VerifyCS.VerifyAnalyzerAsync(@"
using System;
using System.Runtime.InteropServices;

class Program
{
    [UnmanagedCallersOnly]
    static void Main()
    {
        try
        {
            const int i = 0;
            Console.WriteLine(i);
        }
        catch (Exception e)
        {
        }
    }
}
");
        }

        [TestMethod]
        public async Task LocalIntCouldBeConstant_Diagnostic()
        {
            await VerifyCS.VerifyCodeFixAsync(
                @"""
                using System;
                using System.Runtime.InteropServices;

                class Program
                {
                    [[|UnmanagedCallersOnly|]]
                    static void Main()
                    {
                        int i = 0;
                        Console.WriteLine(i);
                    }
                }
                """,
                @"""
                using System;
                using System.Runtime.InteropServices;

                class Program
                {
                    [UnmanagedCallersOnly]
                    static void Main()
                    {
                        try
                        {
                            const int i = 0;
                            Console.WriteLine(i);
                        }
                        catch (Exception e)
                        {
                        }
                    }
                }
                """);
        }
    }
}
