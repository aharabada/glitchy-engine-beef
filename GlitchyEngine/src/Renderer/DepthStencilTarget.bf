using GlitchyEngine.Core;

namespace GlitchyEngine.Renderer
{
	public enum DepthStencilFormat
	{
		case Unknown,
		D16_UNorm,
		D24_UNorm_S8_UInt,
		D32_Float,
		D32_Float_S8X24_UInt;

		public static Format operator explicit(Self depthFormat)
		{
			switch (depthFormat)
			{
			case D16_UNorm:
				return .D16_UNorm;
			case D24_UNorm_S8_UInt:
				return .D24_UNorm_S8_UInt;
			case D32_Float:
				return .D32_Float;
			case D32_Float_S8X24_UInt:
				return .D32_Float_S8X24_UInt;
			default:
				return .Unknown;
			}	
		}
	}

	// TODO: add all features.
	public class DepthStencilTarget : RefCounter
	{
		protected uint32 _width, _height;
		protected DepthStencilFormat _format;

		public uint32 Width => _width;
		public uint32 Height => _height;
		public DepthStencilFormat Format => _format;

		public this(uint32 width, uint32 height, DepthStencilFormat format = .D32_Float)
		{
			Log.EngineLogger.Assert(format != .Unknown, "DepthStencilFormat None is only valid for RenderTarget");

			_width = width;
			_height = height;
			_format = format;

			PlatformCreate();
		}

		protected extern void PlatformCreate();
	}
}
