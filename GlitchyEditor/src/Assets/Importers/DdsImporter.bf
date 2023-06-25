using System.IO;
using System;
using GlitchyEngine;
using System.Collections;

namespace GlitchyEditor.Assets.Importers;

// Based on https://github.com/Diron-P/DDSReader/blob/main/dds_loader.h

public struct LoadedSurface
{
	public Span<uint8> Data;
	public uint32 Pitch;
	public uint32 SlicePitch;

	public int ArrayIndex;
	public int CubeFace;
	public int MipLevel;
}

public struct LoadedTextureInfo
{
	public enum Dimension
	{
		Unknown,
		Texture1D,
		Texture2D,
		Texture3D
	}

	public uint8[] PixelData = null;
	public DirectX.DXGI.Format PixelFormat = .Unknown;
	public int MipMapCount = 0;
	public int ArraySize = 0;
	public Dimension Dimension = .Unknown;
	public bool IsCubeMap;

	public int Width;
	public int Height;
	public int Depth;
}

static class DdsImporter
{
	private const uint32 MagicWord = 0x20534444; // 'DDS 

	public enum LoadError
	{
		Unknown,
		WrongMagicWord,
		StreamReadFailed
	}

	private enum HeaderFlags : uint32
	{
		/// Required in every .dds file.
		DDSD_CAPS = 0x1,
		/// Required in every .dds file.
		DDSD_HEIGHT = 0x2,
		/// Required in every .dds file.
		DDSD_WIDTH = 0x4,
		/// Required in every .dds file.
		DDSD_PITCH = 0x8,
		/// Required in every .dds file.
		DDSD_PIXELFORMAT = 0x1000,
		/// Required in a mipmapped texture.
		DDSD_MIPMAPCOUNT = 0x20000,
		/// Required when pitch is provided for a compressed texture.
		DDSD_LINEARSIZE = 0x80000,
		///  	Required in a depth texture.
		DDSD_DEPTH = 0x800000
	}

	private enum Caps1 : uint32
	{
		/// Should be set, when the file contains multiple surfaces (e.g. Cubemaps or Mipmaps).
		Complex = 0x8,
		/// Should be set, if the file contains mipmaps.
		MipMap = 0x400000,
		/// Should always be set.
		Texture = 0x1000
	}

	[AllowDuplicates]
	private enum Caps2 : uint32
	{
		Cubemap = 0x200,
		Cubemap_PositiveX = 0x400,
		Cubemap_NegativeX = 0x800,
		Cubemap_X = Cubemap_PositiveX | Cubemap_NegativeX,
		Cubemap_PositiveY = 0x1000,
		Cubemap_NegativeY = 0x2000,
		Cubemap_Y = Cubemap_PositiveY | Cubemap_NegativeY,
		Cubemap_PositiveZ = 0x4000,
		Cubemap_NegativeZ = 0x8000,
		Cubemap_Z = Cubemap_PositiveZ | Cubemap_NegativeZ,
		/// This is the flag that should be set for Cubemaps in DX10+
		Cubemap_AllFaces = Cubemap | Cubemap_X | Cubemap_Y | Cubemap_Z,

		Volume = 0x200000,
	}

	[CRepr]
	private struct DdsHeader
	{
		/// Size of this structure. This member must be set to 124.
		private uint32 Size;
		/// Flags to indicate which members contain valid data.
		public HeaderFlags Flags;
		/// Surface height (in pixels).
		public uint32 Height;
		/// Surface width (in pixels).
		public uint32 Width;
		public uint32 PitchOrLinearSize;
		/// Depth of a volume texture (in pixels), otherwise unused.
		public uint32 Depth;
		/// Number of mipmap levels, otherwise unused.
		public uint32 MipMapCount;
		/// Unused.
		private uint32[11] Reserved1;
		/// The pixel format.
		public DdsPixelFormat PixelFormat;
		public Caps1 Caps;
		public Caps2 Caps2;
		/// Unused.
		private uint32 dwCaps3;
		/// Unused.
		private uint32 dwCaps4;
		/// Unused.
		private uint32 dwReserved2;
	}

	private enum SurfaceType : uint32
	{
		/// Texture contains alpha data; dwRGBAlphaBitMask contains valid data.
		AlphaPixels = 0x1,
		/// Used in some older DDS files for alpha channel only uncompressed data (dwRGBBitCount contains the alpha channel bitcount; dwABitMask contains valid data)
		Alpha = 0x2,

		/// Texture contains compressed RGB data; dwFourCC contains valid data.
		FourCC = 0x4,
		/// Texture contains uncompressed RGB data; dwRGBBitCount and the RGB masks (dwRBitMask, dwGBitMask, dwBBitMask) contain valid data.
		RGB = 0x40,

		RGBA = RGB | AlphaPixels,

		/// Used in some older DDS files for YUV uncompressed data (dwRGBBitCount contains the YUV bit count;
		/// dwRBitMask contains the Y mask, dwGBitMask contains the U mask, dwBBitMask contains the V mask)
		YUV = 0x200,

		/// Used in some older DDS files for single channel color uncompressed data (dwRGBBitCount contains the luminance channel bit count;
		/// dwRBitMask contains the channel mask). Can be combined with DDPF_ALPHAPIXELS for a two channel DDS file.
		Luminance = 0x20000
	}

	private static uint32 MakeFourCC(char8 c0, char8 c1, char8 c2, char8 c3)
	{
		return ((uint32)c3 << 24 | (uint32) c2 << 16 | (uint32) c1 << 8 | (uint32) c0);
	}

	/*private enum FourCC : uint32
	{
		DXT1 = MakeFourCC('D', 'X', 'T', '1'),
		DXT2 = MakeFourCC('D', 'X', 'T', '2'),
		DXT3 = MakeFourCC('D', 'X', 'T', '3'),
		DXT4 = MakeFourCC('D', 'X', 'T', '4'),
		DXT5 = MakeFourCC('D', 'X', 'T', '5'),
		/// indicates the prescense of the DDS_HEADER_DXT10 extended header
		DX10 = MakeFourCC('D', 'X', '1', '0'),
	}*/

	[CRepr]
	private struct DdsPixelFormat
	{
		/// Structure size; set to 32 (bytes).
		private uint32 Size;
		/// Values which indicate what type of data is in the surface.
		public SurfaceType SurfaceType;
		public uint32 FourCC;
		/// Number of bits in an RGB (possibly including alpha) format. Valid when dwFlags includes DDPF_RGB, DDPF_LUMINANCE, or DDPF_YUV.
		public uint32 RGBBitCount;
		/// Red (or luminance or Y) mask for reading color data. For instance, given the A8R8G8B8 format, the red mask would be 0x00ff0000.
		public uint32 RBitMask;
		/// Green (or U) mask for reading color data. For instance, given the A8R8G8B8 format, the green mask would be 0x0000ff00.
		public uint32 GBitMask;
		/// Blue (or V) mask for reading color data. For instance, given the A8R8G8B8 format, the blue mask would be 0x000000ff.
		public uint32 BBitMask;
		/// Alpha mask for reading alpha data. dwFlags must include DDPF_ALPHAPIXELS or DDPF_ALPHA. For instance, given the A8R8G8B8 format, the alpha mask would be 0xff000000.
		public uint32 ABitMask;
	}

	public enum ResourceDimensions : uint32
	{
		Texture1D = 2,
		Texture2D = 3,
		Texture3D = 4
	}

	public enum MiscFlags : uint32
	{
		TextureCube = 0x4,
	}

	public enum AlphaMode : uint32
	{
		Unknown = 0x0,
		Straight = 0x1,
		Premultiplied = 0x2,
		Opaque = 0x3,
		/// Any alpha channel content is being used as a 4th channel and is not intended to represent transparency (straight or premultiplied).
		Custom = 0x4
	}

	/// DDS header extension to handle resource arrays, DXGI pixel formats that don't map to the legacy Microsoft DirectDraw pixel format structures, and additional metadata.
	[CRepr]
	private struct DdsDxt10Header
	{
		public DirectX.DXGI.Format PixelFormat;
		public ResourceDimensions ResourceDimension;
		public MiscFlags MiscFlags;
		/// Number of elements in the array. For a 2D cubemap this is the number of cubes, so the file contains ArraySize * 6 2D textures.
		/// For a 3D Texture this must be 1.
		public uint32 ArraySize;

		public AlphaMode AlphaMode;
	}

	private static Result<void, LoadError> DecodeHeader(Stream data, out DdsHeader header, out DdsDxt10Header? extendedHeader)
	{
		header = ?;
		extendedHeader = null;

		// Check the magic word
		Result<uint32> magicWord = data.Read<uint32>();

		if (magicWord case .Err)
			return .Err(.StreamReadFailed);

		if (magicWord != MagicWord)
			return .Err(.WrongMagicWord);

		// Load the header
		Result<DdsHeader> headerResult = data.Read<DdsHeader>();

		if (headerResult case .Err)
			return .Err(.StreamReadFailed);

		header = headerResult;

		// If available, load the extended header
		if (header.PixelFormat.SurfaceType.HasFlag(.FourCC) && header.PixelFormat.FourCC == MakeFourCC('D', 'X', '1', '0'))
		{
			Result<DdsDxt10Header> extendedHeaderResult = data.Read<DdsDxt10Header>();
			
			if (headerResult case .Err)
				return .Err(.StreamReadFailed);

			extendedHeader = extendedHeaderResult;
		}

		return .Ok;
	}

	private static bool IsBitMask(DdsPixelFormat ddspf, uint32 rBitMask, uint32 gBitMask, uint32 bBitMask, uint32 aBitMask)
	{
	  return ddspf.RBitMask == rBitMask && ddspf.GBitMask == gBitMask && ddspf.BBitMask == bBitMask && ddspf.ABitMask == aBitMask;
	}

	private static DirectX.DXGI.Format GetFormat(in DdsHeader header, in DdsDxt10Header? extendedheader, bool isSrgb)
	{
		if (extendedheader != null)
			return extendedheader.Value.PixelFormat;

		DdsPixelFormat pixelFormat = header.PixelFormat;

		// Currently supports only basic dxgi formats.
		if (pixelFormat.SurfaceType.HasFlag(.RGBA))
		{
			switch (pixelFormat.RGBBitCount)
			{
			case 32:
				if (IsBitMask(pixelFormat, 0xFF, 0xFF00, 0xFF0000, 0xFF000000))
					return isSrgb ? .R8G8B8A8_UNorm_SRGB : .R8G8B8A8_UNorm;

				if (IsBitMask(pixelFormat, 0xffff, 0xffff0000, 0x0, 0x0))
					return .R16G16_UNorm;

				if (IsBitMask(pixelFormat, 0x3ff, 0xffc00, 0x3ff00000, 0x0))
					return .R10G10B10A2_UNorm;
			case 16:
				if (IsBitMask(pixelFormat, 0x7c00, 0x3e0, 0x1f, 0x8000))
					return .B5G5R5A1_UNorm;
			default:
				return .Unknown;
			}
		}

		if (pixelFormat.SurfaceType.HasFlag(.RGB))
		{
			switch (pixelFormat.RGBBitCount)
			{
			case 32:
				if (IsBitMask(pixelFormat, 0xffff, 0xffff0000, 0x0, 0x0))
					return .R16G16_UNorm;
				break;
			case 16:
				if (IsBitMask(pixelFormat, 0xf800, 0x7e0, 0x1f, 0x0))
					return .B5G6R5_UNorm;
				break;
			default:
				return .Unknown;
			}
		}

		if (pixelFormat.SurfaceType.HasFlag(.FourCC))
		{
			switch (pixelFormat.FourCC)
			{
			case MakeFourCC('D', 'X', 'T', '1'):
				return isSrgb ? .BC1_UNorm_SRGB : .BC1_UNorm;
			case MakeFourCC('D', 'X', 'T', '3'):
				return isSrgb ? .BC2_UNorm_SRGB : .BC2_UNorm;
			case MakeFourCC('D', 'X', 'T', '5'):
				return isSrgb ? .BC3_UNorm_SRGB : .BC3_UNorm;
			  // Legacy compression formats.
			case MakeFourCC('B', 'C', '4', 'U'), MakeFourCC('A', 'T', 'I', '1'):
				return .BC4_UNorm;
			case MakeFourCC('A', 'T', 'I', '2'):
				return .BC5_UNorm;
			case MakeFourCC('R', 'G', 'B', 'G'):
				return .R8G8_B8G8_UNorm;
			case MakeFourCC('G', 'R', 'G', 'B'):
				return .G8R8_G8B8_UNorm;
			case 36:
				return .R16G16B16A16_UNorm;
			case 111:
				return .R16_Float;
			case 112:
				return .R16G16_Float;
			case 113:
				return .R16G16B16A16_Float;
			case 114:
				return .R32_Float;
			case 115:
				return .R32G32_Float;
			case 116:
				return .R32G32B32A32_Float;
			default:
				return .Unknown;
			}
		}

		return .Unknown;
	}

	public static Result<void, LoadError> LoadDds(Stream data, bool isSrgb, List<LoadedSurface> surfaces, out LoadedTextureInfo textureInfo)
	{
		textureInfo = .();

		var headerResult = DecodeHeader(data, let header, let extendedHeader);

		if (headerResult case .Err)
			return headerResult;

		int surfaceCount = 1;

		if (header.Flags.HasFlag(.DDSD_MIPMAPCOUNT) || header.MipMapCount != 0)
		{
			if (header.MipMapCount == 0)
				Log.EngineLogger.Warning("Mipmap count is zero, even though the flags say it shouldn't.");
			
			if (!header.Flags.HasFlag(.DDSD_MIPMAPCOUNT))
				Log.EngineLogger.Warning("Mipmap count is not zero, even though the mipmap count flag isn't set.");

			textureInfo.MipMapCount = header.MipMapCount;
			surfaceCount *= textureInfo.MipMapCount;
		}
		else
		{
			textureInfo.MipMapCount = 1;
		}

		if (extendedHeader != null)
		{
			textureInfo.ArraySize = extendedHeader.Value.ArraySize;
			surfaceCount *= textureInfo.ArraySize;
		}
		else
		{
			textureInfo.ArraySize = 1;
		}

		if (header.Caps2.HasFlag(.Cubemap))
		{
			if (!header.Caps2.HasFlag(.Cubemap_AllFaces))
				Log.EngineLogger.Warning("Texture might only contains partial cubemap, this is not allowed. (Defined Cubemap-Flag, but not all cubemap faces)");

			surfaceCount *= 6;
			textureInfo.IsCubeMap = true;
		}
		
		textureInfo.PixelFormat = GetFormat(header, extendedHeader, isSrgb);

		textureInfo.Width = header.Width;
		textureInfo.Height = header.Height;
		textureInfo.Depth = header.Depth;

		switch (extendedHeader?.ResourceDimension)
		{
		case .Texture1D:
			textureInfo.Dimension = .Texture1D;
		case .Texture2D:
			textureInfo.Dimension = .Texture2D;
		case .Texture3D:
			textureInfo.Dimension = .Texture3D;
		case null:
			if (header.Flags.HasFlag(.DDSD_DEPTH))
				textureInfo.Dimension = .Texture3D;
			else
				textureInfo.Dimension = .Texture2D;
		}

		// Make sure we have enough space in the list (avoid allocations later)
		surfaces.Reserve(surfaceCount);

		uint32 scanLineSize = 0;
		uint32 slicePitch = 0;
		uint32 numBytes = 0;
		uint32 blockSize = 0; // Block size in bytes.

		switch (textureInfo.PixelFormat)
		{
		case .BC1_UNorm, .BC1_UNorm_SRGB, .BC4_UNorm:
			blockSize = 8;
		case .BC2_UNorm, .BC2_UNorm_SRGB, .BC3_UNorm, .BC3_UNorm_SRGB, .BC5_UNorm:
			blockSize = 16;
		default:
		}

		uint32 width = 0;
		uint32 height = 0;
		uint32 depth = 0;

		uint32 index = 0;

		uint offset = 0;

		for (uint32 arrayIndex = 0; arrayIndex < textureInfo.ArraySize; arrayIndex++)
		{
			for (uint32 cubeFace = 0; cubeFace < (textureInfo.IsCubeMap ? 6 : 1); cubeFace++)
			{
				width = header.Width;
				height = header.Height;
				depth = header.Depth;

				for (uint32 mipLevel = 0; mipLevel < textureInfo.MipMapCount; ++mipLevel)
				{
					// This will recalculate te pitch of the main image as well.
					if (header.Flags.HasFlag(.DDSD_LINEARSIZE))
					{
						// compressed textures
						scanLineSize = Math.Max(1, ((width + 3u) / 4u)) * blockSize;
						uint32 numScanLines = Math.Max(1, ((height + 3u) / 4u));
						numBytes = scanLineSize * numScanLines;
					}
					else if (header.Flags.HasFlag(.DDSD_PITCH))
					{
						// uncompressed data
						scanLineSize = (width * header.PixelFormat.RGBBitCount + 7u) / 8u;
						numBytes = scanLineSize * height;
					}

					LoadedSurface surface = .();
					// We don't know how large data-array is, so we don't have one yet.
					// Only save the offset, we will adjust the pointer later.
					surface.Data = Span<uint8>((uint8*)(void*)offset, numBytes);
					surface.Pitch = scanLineSize;
					surface.SlicePitch = slicePitch;
					
					surface.ArrayIndex = arrayIndex;
					surface.CubeFace = cubeFace;
					surface.MipLevel = mipLevel;

					surfaces.Add(surface);

					++index;

					width >>= 1;
					height >>= 1;
					depth >>= 1;

					if (width == 0)
					{
						width = 1;
					}

					if (height == 0)
					{
						height = 1;
					}

					offset += numBytes;
				}
			}
		}

		textureInfo.PixelData = new uint8[offset];

		Result<int> pixelDataResult = data.TryRead(textureInfo.PixelData);

		if (pixelDataResult case .Err)
		{
			delete textureInfo.PixelData;
			return .Err(.StreamReadFailed);
		}
		
		for (ref LoadedSurface surface in ref surfaces)
		{
			// Data pointer so far only has the offset inside the array.
			// Move the pointer, so that it is inside the array.
			surface.Data.Ptr += (uint)(void*)textureInfo.PixelData.Ptr;
		}

		return .Ok;
	}
}
