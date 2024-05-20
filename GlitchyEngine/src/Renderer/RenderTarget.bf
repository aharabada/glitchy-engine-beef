using GlitchyEngine.Core;
using System;
using System.Collections;
using GlitchyEngine.Math;
using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer
{
	public struct RenderTarget2DDescription
	{
		public uint32 Width;
		public uint32 Height;
		public uint32 ArraySize;
		public uint32 MipLevels;
		public Format PixelFormat;
		public CPUAccessFlags CpuAccess;
		public uint32 SampleCount;
		public uint32 SampleQuality;
		public DepthStencilFormat DepthStencilFormat;
		public bool IsSwapchainTarget;

		public this(Format pixelFormat, uint32 width, uint32 height, uint32 arraySize = 1, uint32 mipLevels = 1,
			DepthStencilFormat depthStencilFormat = .Unknown, CPUAccessFlags cpuAccess = .None, uint32 sampleCount = 1, uint32 sampleQuality = 0, bool isSwapchainTarget = false)
		{
			PixelFormat = pixelFormat;
			Width = width;
			Height = height;
			ArraySize = arraySize;
			MipLevels = mipLevels;
			CpuAccess = cpuAccess;
			DepthStencilFormat = depthStencilFormat;

			SampleCount = sampleCount;
			SampleQuality = sampleQuality;

			IsSwapchainTarget = isSwapchainTarget;
		}
	}

	public class RenderTarget2D : Texture
	{
		private RenderTarget2DDescription _description;

		public RenderTarget2DDescription Description => _description;

		public override uint32 Width => _description.Width;
		public override uint32 Height => _description.Height;
		public override uint32 Depth => 1;
		public override uint32 ArraySize => _description.ArraySize;
		public override uint32 MipLevels => _description.MipLevels;
		public override Format Format => _description.PixelFormat;

		public override TextureDimension Dimension => .Texture2D;

		protected internal DepthStencilTarget _depthStenilTarget ~ _?.ReleaseRef();
		
		// TODO: DepthStencilTarget is just a renderTarget
		public DepthStencilTarget DepthStencilTarget => _depthStenilTarget;

		public this(RenderTarget2DDescription description)
		{
			Debug.Profiler.ProfileResourceFunction!();

			_description = description;

			ApplyChanges();
		}

		/// Recreates the render target using the current description
		public void ApplyChanges()
		{
			PlatformApplyChanges();
		}

		public extern void Resize(uint32 width, uint32 height);

		protected extern void PlatformApplyChanges();
		
		public override TextureViewBinding GetViewBinding()
		{
			return PlatformGetViewBinding();
		}

		protected extern TextureViewBinding PlatformGetViewBinding();

		protected extern void PlatformSneakySwappyTexture(RenderTarget2D otherTexture);
	}

	[AllowDuplicates]
	public enum RenderTargetFormat : uint8
	{
		/// Sets the most significant bit to 1.
		const uint8 DepthMarker = 1 << 7;

		case None = 0;

		case R8_SInt;
		case R32_UInt;

		case R8G8B8A8_UNorm;
		case R8G8B8A8_SNorm;
		
		case R16G16B16A16_SNorm;
		case R16G16B16A16_Float;

		case R32G32B32A32_Float;

		case D24_UNorm_S8_UInt = DepthMarker | 1;

		/// Default depth format
		case Depth = D24_UNorm_S8_UInt;

		public bool IsDepth => HasFlag(DepthMarker);

		public bool IsInt()
		{
			switch(this)
			{
			case R8_SInt:
				return true;
			default:
				return false;
			}
		}

		public bool IsUInt()
		{
			switch(this)
			{
			case R32_UInt:
				return true;
			default:
				return false;
			}
		}
	}

	public enum ClearColor
	{
		/// Clears the render target to the default value (Zero).
		case Default;
		/// The render target will be cleared with a RGBA color.
		case Color(ColorRGBA ClearColor);
		/// The render target will be cleared with a UInt value.
		/// @remarks Some platforms don't support clearing a UInt render target.
		/// 	In these cases a draw call will be performed that draws a solid color into the target.
		/// 	This can result in modified context state so it is recommended to rebind effects, etc. after clearing a uint rendertarget.
		case UInt(uint32 ClearValue);
		/// Only valid for depth buffers.
		case DepthStencil(float Depth, uint8 Stencil);

		public static implicit operator ClearColor(ColorRGBA color)
		{
			return .Color(color);
		}
	}

	public struct TargetDescription : IDisposable
	{
		public RenderTargetFormat Format = .None;

		public bool IsSwapchainTarget = false;

		public bool IsShaderReadable = true;

		public ClearColor ClearColor = .Default;

		public SamplerStateDescription SamplerDescription = .();
		
		public String DebugName = null;

		public this() {  }

		public this(RenderTargetFormat format, bool isSwapchainTarget = false, bool isShaderReadable = true, ClearColor clearColor = .Default, SamplerStateDescription samplerDescription = .(), String ownDebugName = null)
		{
			Format = format;
			IsSwapchainTarget = isSwapchainTarget;
			IsShaderReadable = isShaderReadable;
			SamplerDescription = samplerDescription;
			ClearColor = clearColor;
			DebugName = ownDebugName;
		}

		public static implicit operator Self(RenderTargetFormat format)
		{
			return Self(format);
		}

		public void Dispose()
		{
			delete DebugName;
		}
	}

	public struct RenderTargetGroupDescription
	{
		public uint32 Width = 0, Height = 0, ArraySize = 1, MipLevels = 1;

		public uint32 Samples = 1; // TODO: SampleQuality?

		public Span<TargetDescription> ColorTargetDescriptions = null;

		public TargetDescription DepthTargetDescription = .(.None);

		// TODO: CpuAccess

		public this() {  }

		public this(uint32 width, uint32 height, Span<TargetDescription> colorTargetDescriptions = null, TargetDescription depthTargetDescription = .())
		{
			Width = width;
			Height = height;
			ColorTargetDescriptions = colorTargetDescriptions;
			DepthTargetDescription = depthTargetDescription;
		}
	}

	public class RenderTargetGroup : Asset
	{
		internal RenderTargetGroupDescription _description;

		internal TargetDescription[] _colorTargetDescriptions ~ {
			for (var desc in _)
			{
				desc.Dispose();
			}

			delete _;
		};
		internal SamplerState[] _colorSamplerStates ~ DeleteContainerAndReleaseItems!(_);
		internal SamplerState _depthSamplerState ~ _?.ReleaseRef();

		internal TargetDescription _depthTargetDescription ~ _.Dispose();

		public uint32 Width => _description.Width;
		public uint32 Height => _description.Height;
		public uint32 ArraySize => _description.ArraySize;
		public uint32 MipLevels => _description.MipLevels;

		public uint32 Samples => _description.Samples;

		public int TargetCount => _colorTargetDescriptions.Count + (_depthTargetDescription.Format.IsDepth ? 1 : 0);
		public int ColorTargetCount => _colorTargetDescriptions.Count;

		public bool HasDepth => _depthTargetDescription.Format.IsDepth;

		[AllowAppend]
		public this(RenderTargetGroupDescription description)
		{
			_description = description;

			Log.EngineLogger.AssertDebug(_description.Width != 0);
			Log.EngineLogger.AssertDebug(_description.Height != 0);

			var colorTargets = description.ColorTargetDescriptions;

			if (!colorTargets.IsNull && !colorTargets.IsEmpty)
			{
				_colorTargetDescriptions = new TargetDescription[colorTargets.Length];
				_colorSamplerStates = new SamplerState[colorTargets.Length];

				bool swapchainTargetBound = false;

				for (int i < colorTargets.Length)
				{
					Log.EngineLogger.AssertDebug(!colorTargets[i].Format.IsDepth, "Cannot use depth format as color target.");
					
					_colorTargetDescriptions[i] = colorTargets[i];

					if (colorTargets[i].IsSwapchainTarget)
					{
						Log.EngineLogger.AssertDebug(!swapchainTargetBound, "Cannot bind swapchaintarget multiple times.");
					
						swapchainTargetBound = true;
					}

					_colorSamplerStates[i] = SamplerStateManager.GetSampler(_colorTargetDescriptions[i].SamplerDescription);
					
					if (_colorTargetDescriptions[i].ClearColor case .Default)
						_colorTargetDescriptions[i].ClearColor = .Color(.Black);
				}
			}
			
			_depthTargetDescription = description.DepthTargetDescription;

			if (_depthTargetDescription.Format != .None)
			{
				Log.EngineLogger.AssertDebug(_depthTargetDescription.Format.IsDepth, "Depth target must have depth format.");
				
				if (_depthTargetDescription.ClearColor case .Default)
					_depthTargetDescription.ClearColor = .DepthStencil(0.0f, 0);

				Log.EngineLogger.AssertDebug(_depthTargetDescription.ClearColor case .DepthStencil, "Clear color for depth stencil target must be of type DepthStencil.");

				_depthSamplerState = SamplerStateManager.GetSampler(_depthTargetDescription.SamplerDescription);
			}

			ApplyChanges();
		}

		public extern void ApplyChanges();

		public extern void Resize(uint32 width, uint32 height);
		
		/// -1 for Depthbuffer
		public TextureViewBinding GetViewBinding(int index)
		{
			return PlatformGetViewBinding(index);
		}

		public TargetDescription GetTargetDescription(int index)
		{
			if (index == -1 && HasDepth)
			{
				return _depthTargetDescription;
			}
			else
			{
				return _colorTargetDescriptions[index];
			}
		}

		protected extern TextureViewBinding PlatformGetViewBinding(int index);

		protected extern Result<void> PlatformGetData(void* destination, uint32 elementSize,
			uint32 x, uint32 y, uint32 width, uint32 height, int renderTarget, uint32 arraySlice, uint32 mipLevel); // mapType?

		public Result<void> GetData<T>(T* data, int renderTarget, uint32 left, uint32 top, uint32 width, uint32 height, uint32 arraySlice = 0, uint32 mipSlice = 0)
		{
			Log.EngineLogger.AssertDebug(left + width < Width);
			Log.EngineLogger.AssertDebug(top + height < Height);

			return PlatformGetData(data, (.)sizeof(T), left, top, width, height, renderTarget, arraySlice, mipSlice);
		}

		public extern void CopyTo(RenderTargetGroup destination, int dstTarget, int2 dstTopLeft, int2 size, int2 srcTopLeft, int srcTarget);
	}
}
