using System;
using GlitchyEngine.Core;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public struct BlendStateDescription
	{
		public typealias Blend = DirectX.D3D11.Blend;
		public typealias BlendOperation = DirectX.D3D11.BlendOperation;
		public typealias ColorWriteEnable = DirectX.D3D11.ColorWriteEnable;
		
		public struct RenderTargetBlend
		{
			/**
			 * Enable (or disable) blending.
			*/
			public bool BlendEnable;
			public Blend SourceBlend;
			public Blend DestinationBlend;
			public BlendOperation BlendOperation;
			public Blend SourceBlendAlpha;
			public Blend DestinationBlendAlpha;
			public BlendOperation BlendOperationAlpha;
			public ColorWriteEnable RenderTargetWriteMask;
			
			public this()
			{
				this = default;
			}

			public this(bool blendEnable, Blend sourceBlend, Blend destinationBlend, BlendOperation blendOperation,
				Blend sourceBlendAlpha, Blend destinationBlendAlpha, BlendOperation blendOperationAlpha, ColorWriteEnable renderTargetWriteMask)
			{
				BlendEnable = blendEnable;
				SourceBlend = sourceBlend;
				DestinationBlend = destinationBlend;
				BlendOperation = blendOperation;
				SourceBlendAlpha = sourceBlendAlpha;
				DestinationBlendAlpha = destinationBlendAlpha;
				BlendOperationAlpha = blendOperationAlpha;
				RenderTargetWriteMask = renderTargetWriteMask;
			}

			public static readonly RenderTargetBlend Default = RenderTargetBlend(false, .One, .Zero, .Add, .One, .Zero, .Add, .All);
		}

		/**
		 * Specifies whether to enable independent blending in simultaneous render targets. Set to TRUE to enable independent blending.
		 * If set to FALSE, only the RenderTarget[0] members are used; RenderTarget[1..7] are ignored.
		 */
		public bool IndependentBlendEnable;
		/**
		 * Specifies whether to use alpha-to-coverage as a multisampling technique when setting a pixel to a render target.
		 */
		public bool AlphaToCoverageEnable;

		public RenderTargetBlend[8] RenderTarget;

		public this()
		{
			this = default;
		}

		public this(bool independentBlend, bool alphaToCoverage, RenderTargetBlend[8] renderTarget)
		{
			IndependentBlendEnable = independentBlend;
			AlphaToCoverageEnable = alphaToCoverage;
			RenderTarget = renderTarget;
		}

		public static readonly Self Default = .(false, false, .(.Default, .Default, .Default, .Default, .Default, .Default, .Default, .Default));
	}

	public class BlendState : RefCounter
	{
		protected BlendStateDescription _desc;

		public BlendStateDescription Description => _desc;

		public this(BlendStateDescription desc)
		{
			_desc = desc;

			PlatformCreateBlendState();
		}

		protected extern void PlatformCreateBlendState();
	}
}
