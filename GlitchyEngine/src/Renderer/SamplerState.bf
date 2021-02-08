using System;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public enum FilterFunction
	{
		/// Use point filtering (nearest neighbor) for sampling.
		Point,
		/// Use linear interpolation for sampling.
		Linear,
		/// Use anisotropic interpolation for sampling.
		Anisotropic
	}

	public enum FilterMode
	{
		/// Just sample the texture.
		Default,
		/// Sample the texture and compares it with a comparison value.
		Comparison,
		/// Return the minimum value of the fetched texels.
		Minimum,
		/// Return the maximum value of the fetched texels.
		Maximum
	}

	public enum ComparisonFunction
	{
		/**
		 * Never pass the comparison.
		 */
		Never = 1,
		/**
		 * If the source data is less than the destination data, the comparison passes. 
		 */
		Less = 2,
		/**
		 * If the source data is equal to the destination data, the comparison passes. 
		 */
		Equal = 3,
		/**
		 * If the source data is less than or equal to the destination data, the comparison passes. 
		 */
		LessOrEqual = 4,
		/**
		 * If the source data is greater than the destination data, the comparison passes. 
		 */
		Greater = 5,
		/**
		 * If the source data is not equal to the destination data, the comparison passes. 
		 */
		NotEqual = 6,
		/**
		 * If the source data is greater than or equal to the destination data, the comparison passes. 
		 */
		GreaterOrEqual = 7,
		/**
		 * Always pass the comparison. 
		 */
		Always = 8
	}

	public enum TextureAddressMode
	{
		/// Tile the texture at every (u,v) integer junction.
		Wrap = 1,
		/*
		 * Tile the texture at every (u,v) integer junction. However it is flipped every other tile.
		 * Example
		 * Between 0 and 1 the texture is addressed normally.
		 * Between 1 and 2 the texture is flipped.
		 * Between 2 and 3 the texture is addressed normally.
		 */
		Mirror,
		/**
		 * Texture coordinates outside the range [0.0, 1.0] are set to the texture color at 0.0 or 1.0, respectively.
		 */
		Clamp,
		/**
		 * Texture coordinates outside the range [0.0, 1.0] are set to the border color.
		 */
		Border,
		/**
		 * Like a combination of Mirror and Clamp.
		 * Sample using the absolute value and clamp to 1.0.
		 */
		MirrorOnce 
	}

	public struct SamplerStateDescription
	{
		public FilterFunction MinFilter = .Linear;
		public FilterFunction MagFilter = .Linear;
		public FilterFunction MipFilter = .Linear;

		public FilterMode FilterMode = .Default;
		
		/**
		 * The function that is used to compare the sampled data against the existing sampled data.
		 * Only applies if FilterMode is set to FilterMode.Comparison.
		 */
		public ComparisonFunction ComparisonFunction = .Never;

		public TextureAddressMode AddressModeU = .Clamp;
		public TextureAddressMode AddressModeV = .Clamp;
		public TextureAddressMode AddressModeW = .Clamp;
		
		/**
		 * Offset from the calculated mipmap level.
		 * For example, if Direct3D calculates that a texture should be sampled at mipmap level 3 and MipLODBias is 2, then the texture will be sampled at mipmap level 5.
		*/
		public float MipLODBias = 0;
		
		/**
		 * Lower end of the mipmap range to clamp access to, where 0 is the largest and most detailed mipmap level and any level higher than that is less detailed.
		 */
		public float MipMinLOD = float.MinValue;
		/**
		 * Upper end of the mipmap range to clamp access to, where 0 is the largest and most detailed mipmap level and any level higher than that is less detailed.
		 * This value must be greater than or equal to MinLOD. To have no upper limit on LOD set this to a large value such as float.MaxValue.
		 */
		public float MipMaxLOD = float.MaxValue;

		/**
		 * Clamping value used if FilterMode.Anisotropic is specified in the Filters.
		 * Valid values are between 1 and 16.
		*/
		public uint32 MaxAnisotropy = 1; // TODO: we could use a smaller int

		/**
		 * Border color to use if TextureAddressMode.Border is specified for AddressModeU, AddressModeV, or AddressModeW.
		 */
		public ColorRGBA BorderColor = .White;
	}

	public class SamplerState : RefCounted
	{
		protected GraphicsContext _context ~ _?.ReleaseRef();

		protected SamplerStateDescription _desc;

		[Inline]
		public FilterFunction MinificationFilter => _desc.MinFilter;
		[Inline]
		public FilterFunction MagnificationFilter => _desc.MagFilter;
		[Inline]
		public FilterFunction MipFilter => _desc.MipFilter;
		[Inline]
		public FilterMode FilterMode => _desc.FilterMode;

		protected this(GraphicsContext context)
		{
			_context = context..AddRef();
		}

		public this(GraphicsContext context, SamplerStateDescription desc) : this(context)
		{
			_desc = desc;

			PlatformCreateSamplerState();
		}

		/// Creates the platform specific Sampler State
		protected extern void PlatformCreateSamplerState();

		public extern void Bind(uint32 slot = 0);
	}
}
