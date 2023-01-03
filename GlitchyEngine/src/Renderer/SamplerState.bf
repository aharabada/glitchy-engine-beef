using System;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using System.Collections;
using Bon;

namespace GlitchyEngine.Renderer
{
	/**
	 * Defines the filter function used when sampling from a texture.
	 */
	[BonTarget, Reflect]
	public enum FilterFunction
	{
		/// Use point filtering (nearest neighbor) for sampling.
		Point,
		/// Use linear interpolation for sampling.
		Linear,
		/// Use anisotropic interpolation for sampling.
		Anisotropic
	}
	
	[BonTarget, Reflect]
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
	
	[BonTarget, Reflect]
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
	
	[BonTarget, Reflect]
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
	
	[BonTarget]
	public struct SamplerStateDescription : IHashable
	{
		/// Sampling method used for minification.
		/// If set to "Anisotropic" all Filters are set to "Anisotropic" internally.
		public FilterFunction MinFilter = .Linear;
		/// Sampling method used for magnification.
		/// If set to "Anisotropic" all Filters are set to "Anisotropic" internally.
		public FilterFunction MagFilter = .Linear;
		/// Method used for mip-level sampling.
		/// If set to "Anisotropic" all Filters are set to "Anisotropic" internally.
		public FilterFunction MipFilter = .Linear;

		/// Filtering method to use when sampling a texture.
		public FilterMode FilterMode = .Default;
		
		/**
		 * The function that is used to compare the sampled data against the existing sampled data.
		 * Only applies if FilterMode is set to FilterMode.Comparison.
		 */
		public ComparisonFunction ComparisonFunction = .Never;

		/// Method to use for resolving a u texture coordinate that is outside the 0 to 1 range.
		public TextureAddressMode AddressModeU = .Clamp;
		/// Method to use for resolving a v texture coordinate that is outside the 0 to 1 range.
		public TextureAddressMode AddressModeV = .Clamp;
		/// Method to use for resolving a w texture coordinate that is outside the 0 to 1 range.
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
		public uint8 MaxAnisotropy = 1; // TODO: we could use a smaller int

		/**
		 * Border color to use if TextureAddressMode.Border is specified for AddressModeU, AddressModeV, or AddressModeW.
		 */
		public ColorRGBA BorderColor = .White;

		public int GetHashCode()
		{
			// Put integers into one integer
			int intHash = ((int)MinFilter) | ((int)MagFilter << 2) | ((int)MipFilter << 4) | ((int)FilterMode << 6) | ((int)ComparisonFunction << 8) |
				((int)AddressModeU << 12) | ((int)AddressModeU << 15) | ((int)AddressModeU << 18) | ((int)(MaxAnisotropy & 0x1F) << 21); // (26 bit)

			// Put BorderColor into hash.
			int colorHash = ((BorderColor.R.GetHashCode() * 397 ^ BorderColor.G.GetHashCode()) * 397 ^ BorderColor.B.GetHashCode()) * 397 ^ BorderColor.A.GetHashCode();

			return (((colorHash * 397 ^ MipLODBias.GetHashCode()) * 397 ^ MipMinLOD.GetHashCode()) * 397 ^ MipMaxLOD.GetHashCode()) * 397 ^ intHash;
		}
	}

	public static class SamplerStateManager
	{
		static Dictionary<SamplerStateDescription, SamplerState> _samplers;

		public static SamplerState PointClamp;
		public static SamplerState PointWrap;
		public static SamplerState LinearClamp;
		public static SamplerState LinearWrap;
		public static SamplerState AnisotropicClamp;
		public static SamplerState AnisotropicWrap;

		public static void Init()
		{
			Debug.Profiler.ProfileFunction!();

			_samplers = new .();

			// Init point samplers
			{
				var clampDesc = SamplerStateDescription()
					{
						MinFilter = .Point,
						MagFilter = .Point,
						MipFilter = .Point
					};
				PointClamp = GetSampler(clampDesc);
				
				var wrapDesc = SamplerStateDescription()
					{
						MinFilter = .Point,
						MagFilter = .Point,
						MipFilter = .Point,
						AddressModeU = .Wrap,
						AddressModeV = .Wrap,
						AddressModeW = .Wrap
					};
				PointWrap = GetSampler(wrapDesc);
			}

			// Init linear samplers
			{
				// Default Sampler ist LinearClamp
				var clampDesc = SamplerStateDescription();
				LinearClamp = GetSampler(clampDesc);
				
				var wrapDesc = SamplerStateDescription()
					{
						AddressModeU = .Wrap,
						AddressModeV = .Wrap,
						AddressModeW = .Wrap
					};
				LinearWrap = GetSampler(wrapDesc);
			}

			// Init anisotropic samplers
			{
				var clampDesc = SamplerStateDescription()
					{
						MinFilter = .Anisotropic,
						MagFilter = .Anisotropic,
						MipFilter = .Anisotropic,
						MaxAnisotropy = 16
					};
				AnisotropicClamp = GetSampler(clampDesc);
				
				var wrapDesc = SamplerStateDescription()
					{
						MinFilter = .Anisotropic,
						MagFilter = .Anisotropic,
						MipFilter = .Anisotropic,
						MaxAnisotropy = 16,
						AddressModeU = .Wrap,
						AddressModeV = .Wrap,
						AddressModeW = .Wrap
					};
				AnisotropicWrap = GetSampler(wrapDesc);
			}
		}

		public static void Uninit()
		{
			Debug.Profiler.ProfileFunction!();

			PointClamp.ReleaseRef();
			PointWrap.ReleaseRef();
			LinearClamp.ReleaseRef();
			LinearWrap.ReleaseRef();
			AnisotropicClamp.ReleaseRef();
			AnisotropicWrap.ReleaseRef();

			delete _samplers;
			_samplers = null;
		}

		/**
		 * Returns a Sampler State that has the specified settings.
		 * @param desc The Struct containing the sampler state options.
		 * @returns A SamplerState with the given options.
		 * @remarks This Function increases the SamplerStates reference counter, so remember to release it.
		 */
		public static SamplerState GetSampler(SamplerStateDescription desc)
		{
			Debug.Profiler.ProfileResourceFunction!();

			Log.EngineLogger.AssertDebug(_samplers != null, "SamplerStateManager was not initialized.");

			if(_samplers.TryGetValue(desc, let sampler))
			{
				return sampler..AddRef();
			}

			SamplerState newState = new SamplerState(desc);
			ManageSampler(newState);

			return newState;
		}

		public static void ManageSampler(SamplerState samplerState)
		{
			Log.EngineLogger.AssertDebug(_samplers != null, "SamplerStateManager was not initialized.");

			_samplers.Add(samplerState.Description, samplerState);
		}

		/**
		 * Removes the given SamplerState from the manager.
		 * Only allows to remove samplerState with a reference count of 0.
		 */
		internal static void Remove(SamplerState samplerState)
		{
			Log.EngineLogger.AssertDebug(samplerState.RefCount == 0, "Tried to delete sampler with nonzero reference count.");

			_samplers?.Remove(samplerState.Description);
		}
	}

	public class SamplerState : RefCounter
	{
		protected SamplerStateDescription _desc;

		[Inline]
		public FilterFunction MinificationFilter => _desc.MinFilter;
		[Inline]
		public FilterFunction MagnificationFilter => _desc.MagFilter;
		[Inline]
		public FilterFunction MipFilter => _desc.MipFilter;
		[Inline]
		public FilterMode FilterMode => _desc.FilterMode;
		
		[Inline]
		public SamplerStateDescription Description => _desc;

		public this(SamplerStateDescription desc)
		{
			Debug.Profiler.ProfileResourceFunction!();

			_desc = desc;

			PlatformCreateSamplerState();
		}

		public ~this()
		{
			Debug.Profiler.ProfileResourceFunction!();

			SamplerStateManager.[Friend]Remove(this);
		}

		/// Creates the platform specific Sampler State
		protected extern void PlatformCreateSamplerState();

		public extern void Bind(uint32 slot = 0);
	}
}
