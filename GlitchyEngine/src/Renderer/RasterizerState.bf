using System;
using GlitchyEngine.Core;

namespace GlitchyEngine.Renderer
{
	public enum FillMode
	{
		Wireframe,
		Solid
	}

	public enum CullMode
	{
		None,
		Front,
		Back
	}

	public struct RasterizerStateDescription
	{
		public FillMode FillMode;
		public CullMode CullMode;
		public bool FrontCounterClockwise;
		public int32 DepthBias;
		public float DepthBiasClamp;
		public float SlopeScaledDepthBias;
		public bool DepthClipEnabled;
		public bool ScissorEnabled;
		public bool MultisampleEnabled;
		public bool AntialiasedLineEnabled;

		public this() => this = default; 

		/**
		Initializes the RasterizerStateDescription with the specified values
		*/
		public this(FillMode fillMode, CullMode cullMode = .Back, bool frontCounterClockwise = false, int32 depthBias = 0, float depthBiasClamp = 0.0f,
			float slopeScaledDepthBias = 0.0f, bool depthClipEnabled = true, bool scissorEnabled = false, bool multisampleEnabled = false, bool antialiasedLineEnabled = false)
		{
			FillMode = fillMode;
			CullMode = cullMode;
			FrontCounterClockwise = frontCounterClockwise;
			DepthBias = depthBias; 
			DepthBiasClamp = depthBiasClamp;
			SlopeScaledDepthBias = slopeScaledDepthBias;
			DepthClipEnabled = depthClipEnabled;
			ScissorEnabled = scissorEnabled;
			MultisampleEnabled = multisampleEnabled;
			AntialiasedLineEnabled = antialiasedLineEnabled;
		}

		public static readonly RasterizerStateDescription Default = .(.Solid, .Back, false, 0, 0f, 0f, true, false, false, false);
	}

	public class RasterizerState : RefCounter
	{
		private RasterizerStateDescription _description;

		public RasterizerStateDescription Description => _description;

		public extern this(RasterizerStateDescription description);
	}
}
