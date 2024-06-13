using System;
using Bon;
using GlitchyEditor.Assets.Importers;
using GlitchyEngine.Renderer;
using GlitchyEngine.Content;
using GlitchyEngine;
using ImGui;
using System.Collections;
using GlitchyEngine.Math;

namespace GlitchyEditor.Assets.Processors;

[BonTarget]
enum GenerateMipMaps
{
	No,
	Box,
	Kaiser
}

enum TextureType
{
	Texture,
	Sprite
}


[BonTarget, BonPolyRegister]
class TextureProcessorConfig : AssetProcessorConfig
{
	[BonInclude]
	private GenerateMipMaps _generateMipMaps = .No;
	
	[BonInclude]
	private SamplerStateDescription _samplerStateDescription = .();
	
	[BonInclude]
	private TextureType _textureType = .Texture;

	[BonInclude]
	private List<SpriteDesc> _sprites = new .() ~ DeleteContainerAndItems!(_);

	public GenerateMipMaps GenerateMipMaps
	{
		get => _generateMipMaps;
		set => SetIfChanged(ref _generateMipMaps, value);
	}

	public SamplerStateDescription SamplerStateDescription
	{
		get => _samplerStateDescription;
		set => SetIfChanged(ref _samplerStateDescription, value);
	}
	
	public TextureType TextureType
	{
		get => _textureType;
		set => SetIfChanged(ref _textureType, value);
	}

	public List<SpriteDesc> Sprites => _sprites;

	public void AddSprite(SpriteDesc sprite)
	{
		_sprites.Add(sprite);
		_changed = true;
	}

	public override void ShowEditor(AssetFile assetFile)
	{
		if (ImGui.BeginPopupModal("Apply Changes", null, .AlwaysAutoResize))
		{
			ImGui.Text("The changes have to be applied before you can open the sprite editor.\nDo you want to apply the changes and continue?");

			if (ImGui.Button("Apply"))
			{
				assetFile.SaveAssetConfig();
				ImGui.CloseCurrentPopup();

				new SpriteEditor(Editor.Instance, assetFile.AssetConfig.AssetHandle);
			}

			ImGui.SameLine();

			if (ImGui.Button("Cancel"))
			{
				ImGui.CloseCurrentPopup();
			}
			
			ImGui.EndPopup();
		}

		ImGui.PropertyTableStartNewProperty("Texture Type");

		TextureType textureType = _textureType;
		if (ImGui.EnumCombo("##textureType", ref textureType))
		{
			TextureType = textureType;
		}

		ImGui.PropertyTableStartNewRow();

		if (textureType == .Sprite)
		{
			if (ImGui.Button("Open Sprite Editor..."))
			{
				if (_changed)
				{
					ImGui.OpenPopup("Apply Changes");
				}
				else
				{
					new SpriteEditor(Editor.Instance, assetFile.AssetConfig.AssetHandle);
				}
			}
		}

		ImGui.PropertyTableStartNewProperty("Generate Mip Maps", "Specifies the algorithm used to generate mip maps for this texture.");

		ImGui.BeginDisabled();

		GenerateMipMaps generateMipMaps = _generateMipMaps;
		if (ImGui.EnumCombo("##generateMipMaps", ref generateMipMaps))
		{
			GenerateMipMaps = generateMipMaps;
		}

		// TODO: Show some mip map generation settings (e.g. count)

		ImGui.EndDisabled();
		
		ImGui.PropertyTableStartNewRow();
		if (ImGui.TreeNodeEx("Sampling", ImGui.TreeNodeFlags.SpanAllColumns | ImGui.TreeNodeFlags.Framed))
		{
			ref SamplerStateDescription sampler = ref _samplerStateDescription;

			bool IsAnisotropic()
			{
				return sampler.MinFilter == .Anisotropic ||
					sampler.MagFilter == .Anisotropic ||
					sampler.MipFilter == .Anisotropic;
			}

			if (IsAnisotropic())
			{
				ImGui.PropertyTableStartNewProperty("Filter", "Sampling method used for minification, magnification and mip-level sampling. Note: If one filter is set to Anisotropic, all are set to Anisotropic.");

				FilterFunction filter = .Anisotropic;
				if (ImGui.EnumCombo("##minFilter", ref filter))
				{
					_changed = true;

					if (sampler.MinFilter == .Anisotropic)
						sampler.MinFilter = filter;
					
					if (sampler.MagFilter == .Anisotropic)
						sampler.MagFilter = filter;

					if (sampler.MipFilter == .Anisotropic)
						sampler.MipFilter = filter;
				}

				ImGui.PropertyTableStartNewProperty("Max Anisotropy", "Clamps the anisotropic sampling rate to the specified value.");
				int32 maxAnisotropy = sampler.MaxAnisotropy;
				if (ImGui.SliderInt("##maxAnisotropy", &maxAnisotropy, 1, 16))
				{
					sampler.MaxAnisotropy = (uint8)maxAnisotropy;
					_changed = true;
				}
			}
			else
			{
				ImGui.PropertyTableStartNewProperty("Min Filter", "Sampling method used for minification. Note: If one filter is set to Anisotropic, all are set to Anisotropic.");
				if (ImGui.EnumCombo("##minFilter", ref sampler.MinFilter))
					_changed = true;

				ImGui.PropertyTableStartNewProperty("Mag Filter", "Sampling method used for magnification. Note: If one filter is set to Anisotropic, all are set to Anisotropic.");
				if (ImGui.EnumCombo("##magFilter", ref sampler.MagFilter))
					_changed = true;

				ImGui.PropertyTableStartNewProperty("Mip Filter", "Method used for mip-level sampling. Note: If one filter is set to Anisotropic, all are set to Anisotropic.");
				if (ImGui.EnumCombo("##mipFilter", ref sampler.MipFilter))
					_changed = true;
			}
			
			ImGui.PropertyTableStartNewProperty("Mip LOD Bias", "Offset from the calculated mipmap level.");
			if (ImGui.DragFloat("##mipLodBias", &sampler.MipLODBias))
				_changed = true;
			
			ImGui.PropertyTableStartNewProperty("Mip Min LOD", "Lower end of the mipmap range to clamp access to, where 0 is the largest and most detailed mipmap level and any level higher than that is less detailed.");
			if (ImGui.DragFloat("##mipMinLod", &sampler.MipMinLOD, v_min: 0.0f, v_max: 64))
				_changed = true;

			ImGui.PropertyTableStartNewProperty("Mip Max LOD", "Upper end of the mipmap range to clamp access to, where 0 is the largest and most detailed mipmap level and any level higher than that is less detailed.");
			if (ImGui.DragFloat("##mipMaxLod", &sampler.MipMaxLOD, v_min: 0.0f, v_max: 64))
				_changed = true;

			// Make sure max lod is always at least min lod.
			sampler.MipMaxLOD = Math.Max(sampler.MipMaxLOD, sampler.MipMinLOD);
			
			ImGui.PropertyTableStartNewProperty("Filter mode", "Filtering method to use when sampling a texture.");
			if (ImGui.EnumCombo("##filterMode", ref sampler.FilterMode))
				_changed = true;

			if (sampler.FilterMode == .Comparison)
			{
				ImGui.PropertyTableStartNewProperty("Comparison function", "The function that is used to compare the sampled data against the existing sampled data.");
				if (ImGui.EnumCombo("##ComparisonFunction", ref sampler.ComparisonFunction))
					_changed = true;
			}
			
			ImGui.PropertyTableStartNewProperty("Address Mode U", "Method to use for resolving a u texture coordinate that is outside the 0 to 1 range.");
			if (ImGui.EnumCombo("##AddressModeU", ref sampler.AddressModeU))
				_changed = true;
			
			ImGui.PropertyTableStartNewProperty("Address ModeV", "Method to use for resolving a v texture coordinate that is outside the 0 to 1 range.");
			if (ImGui.EnumCombo("##AddressModeV", ref sampler.AddressModeV))
				_changed = true;
			
			ImGui.PropertyTableStartNewProperty("Address ModeW", "Method to use for resolving a w texture coordinate that is outside the 0 to 1 range.");
			if (ImGui.EnumCombo("##AddressModeW", ref sampler.AddressModeW))
				_changed = true;

			if (sampler.AddressModeU == .Border || sampler.AddressModeV == .Border || sampler.AddressModeW == .Border)
			{
				ImGui.PropertyTableStartNewProperty("Border Color", "Border color to use if any of the address modes is set to Border");
				if (ImGui.ColorEdit4("##BorderColor", ref sampler.BorderColor))
					_changed = true;
			}

			ImGui.TreePop();
		}
	}
}

[BonTarget]
enum TextureCoordinates
{
	case Pixel(int2 Min, int2 Max);
	case Relative(float2 Offset, float2 Size);
}

[BonTarget]
public class SpriteDesc
{
	public String Name ~ delete _;
	public TextureCoordinates TextureCoordinates;
	public AssetHandle AssetHandle;
}

class ProcessedTexture : ProcessedResource
{
	public Format PixelFormat = .Unknown;
	public int MipMapCount = -1;
	public int ArraySize = -1;
	public TextureDimension Dimension = .Unknown;
	public bool IsCubeMap;

	public int Width = -1;
	public int Height = -1;
	public int Depth = -1;

	public SamplerStateDescription SamplerStateDescription;

	public override AssetType AssetType => .Texture;

	public class TextureSurface
	{
		public uint8[] PixelData;
		public int Width;
		public int Height;
		public int Depth;
		public int MipLevel;
		public int ArraySlice;
		public int LinePitch;
		public int SlicePitch;

		[AllowAppend]
		public this(int width, int height, int depth, Span<uint8> data, int mipLevel, int arraySlice, int linePitch, int slicePitch)
		{
			uint8[] pixelData = append uint8[data.Length];
			data.CopyTo(pixelData);

			PixelData = pixelData;
			Width = width;
			Height = height;
			Depth = depth;
			MipLevel = mipLevel;
			ArraySlice = arraySlice;
			LinePitch = linePitch;
			SlicePitch = slicePitch;
		}

		public uint64 LoadRaw(int x, int y, int z, Format format, ComponentInfo component)
		{
			Log.EngineLogger.AssertDebug(x >= 0 && y >= 0 && z >= 0 && x < Width && y < Height && z < Depth);

			int64 pixelOffset = x + (Width * y) + (Width * Height) * z;

			int64 bitOffset = pixelOffset * format.BitsPerPixel();

			bitOffset += component.BitSize;

			int64 byteOffset = bitOffset / 8;
			int shift = bitOffset % 8;

			int bytesToRead = (component.BitSize + shift) / 8;

			Log.EngineLogger.AssertDebug(bytesToRead <= 8);

			uint64 data = 0;

			data = PixelData.Ptr[byteOffset];
			data >>= shift;
			uint64 mask = (1 << component.BitSize) - 1;
			data &= mask;

			return data;
		}
	}

	public TextureSurface[,] Surfaces;

	public this(AssetIdentifier ownAssetIdentifier, AssetHandle assetHandle) : base(ownAssetIdentifier, assetHandle)
	{

	}

	public ~this()
	{
		for (int i < Surfaces?.GetLength(0) ?? 0)
		{
			for (int j < Surfaces.GetLength(1))
			{
				delete Surfaces[i, j];
			}
		}

		delete Surfaces;
	}

	public void SetSurfaceCount(int arraySize, int mipMapCount)
	{
		ArraySize = arraySize;

		if (IsCubeMap)
			ArraySize *= 6;

		Log.EngineLogger.AssertDebug(Surfaces == null || arraySize > Surfaces.GetLength(0));
		Log.EngineLogger.AssertDebug(Surfaces == null ||mipMapCount > Surfaces.GetLength(1));

		MipMapCount = mipMapCount;

		TextureSurface[,] oldSurfaces = Surfaces;
		Surfaces = new TextureSurface[ArraySize, MipMapCount];

		if (oldSurfaces != null)
		{
			for (int i < oldSurfaces.GetLength(0))
			{
				for (int j < oldSurfaces.GetLength(1))
				{
					Surfaces[i, j] = oldSurfaces[i, j];
				}
			}
		}
	}
}

class ProcessedSprite : ProcessedResource
{
	public override AssetType AssetType => .Sprite;

	private AssetHandle Handle;

	private float4 _textureCoordinates;

	public AssetHandle TextureHandle => Handle;

	public float4 TextureCoordinates => _textureCoordinates;

	public this(AssetIdentifier ownAssetIdentifier, AssetHandle assetHandle, AssetHandle textureHandle, float4 textureCoordinates) : base(ownAssetIdentifier, assetHandle)
	{
		Handle = textureHandle;
		_textureCoordinates = textureCoordinates;
	}
}

class TextureProcessor : IAssetProcessor
{
	public static Type ProcessedAssetType => typeof(ImportedTexture);

	public AssetProcessorConfig CreateDefaultConfig()
	{
		return new TextureProcessorConfig();
	}

	public Result<void> Process(ImportedResource importedObject, AssetConfig config, List<ProcessedResource> outProcessedResources)
	{
		Log.EngineLogger.AssertDebug(importedObject is ImportedTexture);

		TextureProcessorConfig textureProcessorConfig = config.ProcessorConfig as TextureProcessorConfig;

		if (textureProcessorConfig == null)
		{
			config.ProcessorConfig = textureProcessorConfig = new TextureProcessorConfig();
		}

		return Try!(ProcessTexture(importedObject as ImportedTexture, config, textureProcessorConfig, outProcessedResources));
	}

	private Result<void> ProcessTexture(ImportedTexture importedTexture, AssetConfig assetConfig, TextureProcessorConfig textureConfig, List<ProcessedResource> outProcessedResources)
	{
		ProcessedTexture processedTexture = new ProcessedTexture(new AssetIdentifier(importedTexture.AssetIdentifier.FullIdentifier), assetConfig.AssetHandle);

		processedTexture.Dimension = importedTexture.TextureInfo.Dimension;
		processedTexture.PixelFormat = (.)importedTexture.TextureInfo.PixelFormat;
		processedTexture.IsCubeMap = importedTexture.TextureInfo.IsCubeMap;
		processedTexture.Width = importedTexture.TextureInfo.Width;
		processedTexture.Height = importedTexture.TextureInfo.Height;
		processedTexture.Depth = importedTexture.TextureInfo.Depth;
		
		processedTexture.SamplerStateDescription = textureConfig.SamplerStateDescription;

		processedTexture.SetSurfaceCount(importedTexture.TextureInfo.ArraySize, importedTexture.TextureInfo.MipMapCount);

		for (LoadedSurface loadedSurface in importedTexture.Surfaces)
		{
			ProcessedTexture.TextureSurface surface = new .(loadedSurface.Width, loadedSurface.Height, loadedSurface.Depth,
				loadedSurface.Data, loadedSurface.MipLevel, loadedSurface.ArrayIndex, loadedSurface.Pitch, loadedSurface.SlicePitch);

			processedTexture.Surfaces[loadedSurface.ArrayIndex * (processedTexture.IsCubeMap ? 6 : 1) + loadedSurface.CubeFace, loadedSurface.MipLevel] = surface;
		}

		if (!(textureConfig.GenerateMipMaps case .No))
		{
			// TODO: Unpack BC-Formats to RGBA

			GenerateMipMaps(processedTexture, textureConfig);
		}

		outProcessedResources.Add(processedTexture);

		// TODO: Pack to BC-Format or what ever was selected.
		if (textureConfig.TextureType == .Sprite)
		{
			CreateSprites(processedTexture, textureConfig, outProcessedResources);
		}

		return .Ok;
	}

	private void CreateSprites(ProcessedTexture processedTexture, TextureProcessorConfig textureConfig, List<ProcessedResource> outProcessedResources)
	{
		if (processedTexture.Dimension != .Texture2D)
		{
			Log.ClientLogger.Error("Only 2D textures can be used as sprites.");
			return;
		}

		if (textureConfig.Sprites.Count == 0)
		{
			textureConfig.AddSprite(new SpriteDesc(){
				Name = new String("Sprite"),
				// TODO: Maybe add a switch for pixel perfect or relative texture coordinates
				TextureCoordinates = .Pixel(.(0, 0), .((.)processedTexture.Width, (.)processedTexture.Height)),
				// TODO: Get handle from central authority (contentmanager?)
				AssetHandle = AssetHandle()
			});
		}

		float2 textureResolution = .(processedTexture.Width, processedTexture.Height);

		for (SpriteDesc spriteDesc in textureConfig.Sprites)
		{
			float4 textureCoordinates = .();

			if (spriteDesc.TextureCoordinates case .Pixel(let min, let max))
			{
				textureCoordinates = float4((float2)min / textureResolution, (float2)max / textureResolution);
			}
			else if (spriteDesc.TextureCoordinates case .Relative(let offset, let size))
			{
				textureCoordinates = .(offset, size);
			}
			else
			{
				Log.EngineLogger.Error($"Unknown texture coordinate type {spriteDesc.TextureCoordinates}");
				return;
			}

			ProcessedSprite sprite = new ProcessedSprite(new AssetIdentifier(processedTexture.AssetIdentifier, spriteDesc.Name), spriteDesc.AssetHandle, processedTexture.AssetHandle,
				textureCoordinates);

			outProcessedResources.Add(sprite);
		}
	}

	private int CalculateMipMapCount(int width, int height, int depth)
	{
		var width, height, depth;

		int count = 0;

		while (true)
		{
			count++;

			if (width == 1 && height == 1 && depth == 1)
				break;

			if (width > 1)
				width >>= 1;
			if (height > 1)
				height >>= 1;
			if (depth > 1)
				depth >>= 1;
		}

		return count;
	}

	public bool CanGenerateMipMaps(Format format)
	{
		// TODO!
		return true;
	}

	private Result<void> GenerateMipMaps(ProcessedTexture processedTexture, TextureProcessorConfig config)
	{
		if (!CanGenerateMipMaps(processedTexture.PixelFormat))
		{
			return .Err;
		}

		int mipMapCount = CalculateMipMapCount(processedTexture.Width, processedTexture.Height, processedTexture.Depth);

		if (processedTexture.MipMapCount != mipMapCount)
		{
			processedTexture.SetSurfaceCount(processedTexture.ArraySize, mipMapCount);
		}

		for (int arraySlice < processedTexture.ArraySize)
		{
			ProcessedTexture.TextureSurface largerSurface = processedTexture.Surfaces[arraySlice, 0];

			for (int mipMap = 1; mipMap < processedTexture.MipMapCount; mipMap++)
			{
				ref ProcessedTexture.TextureSurface surface = ref processedTexture.Surfaces[arraySlice, mipMap];

				surface = GenerateMipLevel(processedTexture.PixelFormat, largerSurface, surface);

				largerSurface = surface;
			}
		}

		return .Ok;

		// TODO: Generate Mip Maps
		/*int mipMapCount = CalculateMipMapCount(processedTexture.Width, processedTexture.Height, processedTexture.Depth);

		processedTexture.SetMipMapCount(mipMapCount);

		for (int slice < processedTexture.ArraySize)
		{
			for (int mipMap < mipMapCount)
			{
				if (processedTexture.Surfaces[slice, mipMap] == null)
				{
					processedTexture.Surfaces[slice, mipMap] = GenerateMipLevel(processedTexture.Surfaces[slice, mipMap - 1]);
				}
			}
		}
		*/
	}

	private ProcessedTexture.TextureSurface GenerateMipLevel(Format pixelFormat, ProcessedTexture.TextureSurface largerLevel, ProcessedTexture.TextureSurface smallerLevel)
	{
		var smallerLevel;

		int width = Math.Max(largerLevel.Width / 2, 1);
		int height = Math.Max(largerLevel.Height / 2, 1);
		int depth = Math.Max(largerLevel.Depth / 2, 1);

		if (smallerLevel == null)
		{
			smallerLevel = new ProcessedTexture.TextureSurface(width, height, depth,
				new uint8[width * height * depth * pixelFormat.BitsPerPixel()], largerLevel.MipLevel + 1, largerLevel.ArraySlice,
				-1, -1); // TODO!
		}

		// TODO: Kaiser mip maps?

		FormatInfo formatInfo = default; //pixelFormat.GetFormatInfo();

		// Simple box filter
		for (int x < width)
		for (int y < height)
		for (int z < depth)
		{
			for (int channel < formatInfo.ComponentCount)
			{
				ComponentInfo info = formatInfo.Components[channel];

				switch (info.DataType)
				{
				case .UNorm, .UInt:
					
				default:
				}
			}
		}

		return smallerLevel;
	}

	private void Box<DataType>() where DataType : const ComponentDataType
	{

	}
}
