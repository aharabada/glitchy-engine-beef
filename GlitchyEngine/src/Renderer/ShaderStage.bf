using System;
namespace GlitchyEngine.Renderer
{
	[AllowDuplicates]
	public enum ShaderStage
	{
		Vertex = 1,
		Pixel = 2,

		All = Vertex | Pixel
	}
}