using GlitchyEngine.Content;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using System;
using System.IO;
using System.Diagnostics;

namespace GlitchyEngine.Renderer
{
	public abstract class Texture : Asset
	{
		protected SamplerState _samplerState ~ _?.ReleaseRef();
	
		public SamplerState SamplerState
		{
			get => _samplerState;
			set
			{
				if(_samplerState == value)
					return;
				
				SetReference!(_samplerState, value);
			}
		}

		public abstract uint32 Width {get;}
		public abstract uint32 Height {get;}
		public abstract uint32 Depth {get;}
		public abstract uint32 ArraySize {get;}
		public abstract uint32 MipLevels {get;}

		public abstract TextureViewBinding GetViewBinding();
		
		/// Very dirtily swaps the internals with the given texture.
		/// TODO: Please do this differently!!!!!!!!!!!!!!!!!!!!!!
		/// This is for texture hot reloading POC, I know... it's bad...
		protected internal abstract void SneakySwappyTexture(Texture otherTexture);
	}

	public struct Texture2DDesc
	{
		public uint32 Width;
		public uint32 Height;
		public uint32 ArraySize;
		public uint32 MipLevels;
		public Format Format;
		public Usage Usage;
		public CPUAccessFlags CpuAccess;

		public this() => this = default;

		public this(uint32 width, uint32 height, Format format, uint32 arraySize = 1, uint32 mipLevels = 1, Usage usage = .Default, CPUAccessFlags cpuAccess = .None)
		{
			Width = width;
			Height = height;
			Format = format;
			ArraySize = arraySize;
			MipLevels = mipLevels;
			Usage = usage;
			CpuAccess = cpuAccess;
		}
	}

	public class Texture2D : Texture
	{
		//public override extern uint32 Width {get;}
		//public override extern uint32 Height {get;}
		public override uint32 Depth => 1;
		//public override extern uint32 ArraySize {get;}
		//public override extern uint32 MipLevels {get;}

		// TODO: remove
		private this(Stream data)
		{
			LoadDds(data);
		}
		
		protected void LoadDds(Stream stream)
		{
			LoadDdsPlatform(stream);
		}

		public this(Texture2DDesc desc)
		{
			PrepareTexturePlatform(desc, false);
		}

		public void SetData<T>(T* data, uint32 arraySlice = 0, uint32 mipSlice = 0)
		{
			PlatformSetData(data, (.)sizeof(T), 0, 0, Width, Height, arraySlice, mipSlice, .Write);
		}

		public void SetData<T>(T* data, uint32 x, uint32 y, uint32 width, uint32 height, uint32 arraySlice = 0, uint32 mipSlice = 0)
		{
			PlatformSetData(data, (.)sizeof(T), x, y, width, height, arraySlice, mipSlice, .Write);
		}

		/*
		uint32 width, uint32 height, Format format,
		uint32 mipLevels = 1, uint32 arraySize = 1, Usage usage = .Default, CPUAccessFlags cpuAccess = .None
		*/

		protected extern void LoadDdsPlatform(Stream stream);
		
		protected extern void CreateTexturePlatform(Texture2DDesc desc, bool isRenderTarget, void* data, uint32 linePitch);

		/**
		 * Prepares the texture so that a call to SetData can successfully upload the data to the gpu.
		 */
		protected extern void PrepareTexturePlatform(Texture2DDesc desc, bool isRenderTarget);

		protected extern Result<void> PlatformSetData(void* data, uint32 elementSize, uint32 destX,
			uint32 destY, uint32 destWidth, uint32 destHeight, uint32 arraySlice, uint32 mipLevel, GlitchyEngine.Renderer.MapType mapType);

		/**
		 * Copies the texel-data of this texture to the given destination texture.
		 */
		public static extern void CopySubresourceRegion(Texture2D source, Texture2D destination,
			ResourceBox sourceBox = default, uint32 destX = 0, uint32 destY = 0,
			uint32 srcArraySlice = 0, uint32 srcMipSlice = 0, uint32 destArraySlice = 0, uint32 destMipSlice = 0);

		/**
		 * Copies the data to the given destination.
		 */
		public extern void CopyTo(Texture2D destination);

		public override TextureViewBinding GetViewBinding()
		{
			return PlatformGetViewBinding();
		}

		protected extern TextureViewBinding PlatformGetViewBinding();

		protected internal override void SneakySwappyTexture(Texture otherTexture)
		{
			Log.EngineLogger.AssertDebug(otherTexture is Texture2D, "Swapping texture must be a Texture2D!");
			
			SamplerState = otherTexture.SamplerState;

			PlatformSneakySwappyTexture(otherTexture as Texture2D);
		}

		protected extern void PlatformSneakySwappyTexture(Texture2D otherTexture);
	}

	public class TextureCube : Texture
	{
		protected String _path ~ delete _;
		
		// public override extern uint32 Width {get;}
		// public override extern uint32 Height {get;}
		public override uint32 Depth => 1;
		// public override extern uint32 ArraySize {get;}
		// public override extern uint32 MipLevels {get;}

		public this(String path)
		{
			this._path = new String(path);
			LoadTexture();
		}
		
		private void LoadTexture()
		{
			Debug.Profiler.ProfileResourceFunction!();

			Stream data = Application.Get().ContentManager.GetStream(_path);
			defer delete data;

			LoadTexturePlatform(data);
		}

		protected extern void LoadTexturePlatform(Stream stream);

		public override TextureViewBinding GetViewBinding()
		{
			return PlatformGetViewBinding();
		}

		protected extern TextureViewBinding PlatformGetViewBinding();

		protected internal override void SneakySwappyTexture(Texture otherTexture)
		{
			Runtime.NotImplemented();
		}
	}
}
