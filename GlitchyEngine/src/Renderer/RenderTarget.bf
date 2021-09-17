using System;
namespace GlitchyEngine.Renderer
{
	public class RenderTarget2D : Texture2D
	{
		public this(GraphicsContext context, uint32 width, uint32 height, Format format, uint32 arraySize = 1, uint32 mipLevels = 1, CPUAccessFlags cpuAccess = .None)
			 : base(context)
		{
			Texture2DDesc desc;

			desc.Width = width;
			desc.Height = height;
			desc.Format = format;
			desc.ArraySize = arraySize;
			desc.MipLevels = mipLevels;
			// RenderTargets only can do default (I think)
			desc.Usage = .Default;
			desc.CpuAccess = cpuAccess;

			CreateRenderTargetPlatform(desc);
		}
		
		protected extern void CreateRenderTargetPlatform(Texture2DDesc desc);
	}
}
