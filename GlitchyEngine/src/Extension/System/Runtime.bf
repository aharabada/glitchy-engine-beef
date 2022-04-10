namespace System
{
	extension Runtime
	{
		[NoReturn, Warn("The method is not implemented.")]
#unwarn
		public static void NotImplemented(String filePath = Compiler.CallerFilePath, int line = Compiler.CallerLineNum)
		{
			String failStr = scope .()..AppendF("Not Implemented at line {} in {}", line, filePath);
			Internal.FatalError(failStr, 1);
		}
	}
}