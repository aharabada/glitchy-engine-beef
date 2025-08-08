using System;
using GlitchyEngine.Scripting;
using System.Diagnostics;
using System.IO;

namespace GlitchyEngine.Test.Base;

class ScriptEngineTestBase
{
	[Test]
	public static void TestSomeScriptStuff()
	{
		Debug.WriteLine(Directory.GetCurrentDirectory(.. scope .()));

		ScriptEngine.Init();



		ScriptEngine.Shutdown();
	}
}