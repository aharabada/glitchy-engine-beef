using System;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using System.IO;
using System.Diagnostics;

namespace GlitchyEngine.Renderer
{
	public abstract class Texture : RefCounter
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
		protected String _path ~ delete _;

		//public override extern uint32 Width {get;}
		//public override extern uint32 Height {get;}
		public override uint32 Depth => 1;
		//public override extern uint32 ArraySize {get;}
		//public override extern uint32 MipLevels {get;}
		
		public this(StringView path, bool pngSrgb = false)
		{
			_path = new String(path);
			LoadTexture(pngSrgb);
		}
		
		const String PngMagicWord = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A";
		const String DdsMagicWord = "DDS ";

		private void LoadTexture(bool pngSrgb)
		{
			Debug.Profiler.ProfileResourceFunction!();

			Stream data = Application.Get().ContentManager.GetFile(_path);
			defer delete data;

			var readResult = data.Read<char8[8]>();

			data.Position = 0;

			char8[8] magicWord;

			if (readResult case .Ok(out magicWord))
			{
				StringView strView = .(&magicWord, magicWord.Count);

				if (strView.StartsWith(PngMagicWord))
				{
					LoadPng(data, pngSrgb);
				}
				else if (strView.StartsWith(DdsMagicWord))
				{
					LoadDds(data);
				}
				else
				{
					Runtime.FatalError("Unknown image format.");
				}
			}
		}

		protected void LoadPng(Stream stream, bool srgb)
		{
			Debug.Profiler.ProfileResourceFunction!();
			
			uint8[] pngData = new:ScopedAlloc! uint8[stream.Length];

			var result = stream.TryRead(pngData);

			if (result case .Err(let err))
			{
				Log.EngineLogger.Error($"Failed to read data from stream. Texture: \"{_path}\", Error: {err}");
			}

			uint8* rawData = ?;
			uint32 width = 0, height = 0;

			uint32 errorCode = LodePng.LodePng.Decode32(&rawData, &width, &height, pngData.Ptr, (.)pngData.Count);

			Debug.Assert(errorCode == 0, "Failed to load png File");

			// TODO: load as SRGB because PNGs are usually not stored as linear
			//Texture2DDesc desc = .(width, height, .R8G8B8A8_UNorm_SRGB, 1, 1, .Immutable);
			Texture2DDesc desc = .(width, height, srgb? .R8G8B8A8_UNorm_SRGB : .R8G8B8A8_UNorm, 1, 1, .Immutable);
			
			PrepareTexturePlatform(desc, false);

			SetData<Color>((.)rawData);

			LodePng.LodePng.Free(rawData);
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

			Stream data = Application.Get().ContentManager.GetFile(_path);
			defer delete data;

			LoadTexturePlatform(data);
		}

		protected extern void LoadTexturePlatform(Stream stream);

		public override TextureViewBinding GetViewBinding()
		{
			return PlatformGetViewBinding();
		}

		protected extern TextureViewBinding PlatformGetViewBinding();
	}
}
