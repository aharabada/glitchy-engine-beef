using System;
namespace GlitchyEngine.Test;

class TestApp
{
	/// Provide a stup implementation for CreateApplication, so that the linker is happy.
	[Export, LinkName("CreateApplication")]
	public static Application CreateApplication(String[] args)
	{
		return null;
	}
}