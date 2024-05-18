using System;
using System.Collections;
using Bon;
using System.IO;
using GlitchyEngine;
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using DirectXTK;
using ImGui;
using GlitchyEditor.Assets.Importers;
using System.Diagnostics;

namespace GlitchyEditor.Assets;

class TextureAssetPropertiesEditor : AssetPropertiesEditor
{
	EditorTextureAssetLoaderConfig _textureConfig;

	public this(AssetFile asset) : base(asset)
	{
		_textureConfig = asset.AssetConfig.Config as EditorTextureAssetLoaderConfig;
	}

	static char8*[3] _filterFuncNames = char8*[]("Point", "Linear", "Anisotropic");

	public override void ShowEditor()
	{
		if (_textureConfig == null)
			return;

		bool generateMips = _textureConfig.GenerateMipMaps;
		if (ImGui.Checkbox("Generate Mip Maps", &generateMips))
			_textureConfig.GenerateMipMaps = generateMips;

		bool isSrgb = _textureConfig.IsSRGB;
		if (ImGui.Checkbox("Is sRGB", &isSrgb))
			_textureConfig.IsSRGB = isSrgb;

		SamplerStateDescription samplerStateDescription = _textureConfig.SamplerStateDescription;

		void ShowFilterCombo(String label, ref FilterFunction filterFunction)
		{
			int32 selectedFilter = filterFunction.Underlying;
			if (ImGui.Combo(label, &selectedFilter, &_filterFuncNames, 3))
				filterFunction = (.)selectedFilter;
		}

		ImGui.Separator();
		ImGui.TextUnformatted("Texture Filtering:");
		ImGui.Separator();
		
		ImGui.EnumCombo("Min Filter", ref samplerStateDescription.MinFilter);
		ImGui.AttachTooltip("""
			Sampling method used for minification.
			If set to "Anisotropic" all Filters are set to "Anisotropic" internally.
			""");
		ImGui.EnumCombo("Mag Filter", ref samplerStateDescription.MagFilter);
		ImGui.AttachTooltip("""
			Sampling method used for magnification.
			If set to "Anisotropic" all Filters are set to "Anisotropic" internally.
			""");
		ImGui.EnumCombo("Mip Map Filter", ref samplerStateDescription.MipFilter);
		ImGui.AttachTooltip("""
			Method used for mip-level sampling.
			If set to "Anisotropic" all Filters are set to "Anisotropic" internally.
			""");

		if (samplerStateDescription.MagFilter == .Anisotropic ||
			samplerStateDescription.MinFilter == .Anisotropic ||
			samplerStateDescription.MipFilter == .Anisotropic)
		{
			ImGui.SliderScalar("Anisotropy Level", ref samplerStateDescription.MaxAnisotropy, 1, 16);
		}

		ImGui.NewLine();

		ImGui.EnumCombo("Filter Mode", ref samplerStateDescription.FilterMode);
		ImGui.AttachTooltip("Filtering method to use when sampling a texture.");

		if (samplerStateDescription.FilterMode == .Comparison)
		{
			ImGui.EnumCombo("Comparison Function", ref samplerStateDescription.ComparisonFunction);
			ImGui.AttachTooltip("""
				The function that is used to compare the sampled data against the existing sampled data.
				Only applies if Filter Mode is set to FilterMode.Comparison.
				""");
		}

		ImGui.Separator();
		ImGui.TextUnformatted("Wrapping");
		ImGui.Separator();
		
		ImGui.EnumCombo("Wrap Mode U", ref samplerStateDescription.AddressModeU);
		ImGui.AttachTooltip("Method to use for resolving a u texture coordinate that is outside the 0 to 1 range.");

		ImGui.EnumCombo("Wrap Mode V", ref samplerStateDescription.AddressModeV);
		ImGui.AttachTooltip("Method to use for resolving a v texture coordinate that is outside the 0 to 1 range.");

		ImGui.EnumCombo("Wrap Mode W", ref samplerStateDescription.AddressModeW);
		ImGui.AttachTooltip("Method to use for resolving a w texture coordinate that is outside the 0 to 1 range.");

		if (samplerStateDescription.AddressModeU == .Border ||
			samplerStateDescription.AddressModeV == .Border ||
			samplerStateDescription.AddressModeW == .Border)
		{
			ImGui.ColorEdit4("Border Color", ref samplerStateDescription.BorderColor);
		}
		
		ImGui.Separator();
		ImGui.TextUnformatted("Mip Maps");
		ImGui.Separator();
		
		ImGui.DragFloat("Mip LOD Bias", &samplerStateDescription.MipLODBias, 0.1f);
		ImGui.AttachTooltip("""
			Offset from the calculated mipmap level.
			For example, if the GPU calculates that a texture should be sampled at mipmap level 3 and "Mip LOD Bias" is 2, then the texture will be sampled at mipmap level 5.
			""");
		
		ImGui.DragFloat("Min Mip LOD", &samplerStateDescription.MipMinLOD);
		ImGui.AttachTooltip("Lower end of the mipmap range to clamp access to, where 0 is the largest and most detailed mipmap level and any level higher than that is less detailed.");
		
		ImGui.DragFloat("Max LOD Bias", &samplerStateDescription.MipMaxLOD);
		ImGui.AttachTooltip("""
			Upper end of the mipmap range to clamp access to, where 0 is the largest and most detailed mipmap level and any level higher than that is less detailed.
			This value must be greater than or equal to "Min Mip LOD". To have no upper limit on LOD set this to a large value.
			""");

		_textureConfig.SamplerStateDescription = samplerStateDescription;
	}

	public static AssetPropertiesEditor Factory(AssetFile assetFile)
	{
		return new TextureAssetPropertiesEditor(assetFile);
	}
}

[BonTarget, BonPolyRegister]
class EditorTextureAssetLoaderConfig : AssetLoaderConfig
{
	[BonInclude]
	private bool _generateMipMaps;
	
	[BonInclude]
	private bool _isSrgb;

	[BonInclude]
	private SamplerStateDescription _samplerStateDescription = .();

	public bool GenerateMipMaps
	{
		get => _generateMipMaps;
		set => SetIfChanged(ref _generateMipMaps, value);
	}
	
	public bool IsSRGB
	{
		get => _isSrgb;
		set => SetIfChanged(ref _isSrgb, value);
	}

	public SamplerStateDescription SamplerStateDescription
	{
		get => _samplerStateDescription;
		set => SetIfChanged(ref _samplerStateDescription, value);
	}
}

using internal GlitchyEngine.Renderer;
using internal GlitchyEngine.Platform.DX11;

class EditorTextureAssetLoader : IAssetLoader//, IReloadingAssetLoader
{
	private static readonly List<StringView> _fileExtensions = new .(){".png", ".dds"} ~ delete _; // ".jpg", ".bmp"

	public static List<StringView> FileExtensions => _fileExtensions;

	public AssetLoaderConfig GetDefaultConfig()
	{
		return new EditorTextureAssetLoaderConfig();
	}

	public Asset LoadAsset(Stream data, AssetLoaderConfig config, StringView assetIdentifier, StringView? subAsset, IContentManager contentManager)
	{
		var config;

		if (config == null)
		{
			config = GetDefaultConfig();
			defer:: delete config;
		}

		Log.EngineLogger.AssertDebug(config is EditorTextureAssetLoaderConfig, "config has wrong type.");

		return LoadTexture(data, (EditorTextureAssetLoaderConfig)config);
	}
	
	const String PngMagicWord = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A";
	const String DdsMagicWord = "DDS ";

	enum TextureType
	{
		Unknown,
		DDS,
		PNG
	}

	private static TextureType GetTextureType(Stream data)
	{
		int64 position = data.Position;
		
		var readResult = data.Read<char8[8]>();

		data.Position = position;
		
		char8[8] magicWord;
		if (readResult case .Ok(out magicWord))
		{
			StringView strView = .(&magicWord, magicWord.Count);

			if (strView.StartsWith(PngMagicWord))
			{
				return .PNG;
			}
			else if (strView.StartsWith(DdsMagicWord))
			{
				return .DDS;
			}
			else
			{
				Runtime.FatalError("Unknown image format.");
			}
		}

		return .Unknown;
	}

	/** \brief Loads the texture from the specified path.
	 * @param path The path of the texture to load.
	 * @param texture The reference to the pointer that will hold the texture.
	 * @returns true if the texture was loaded successfully; false otherwise.
	 */
	protected static bool LoadDdsResourcePlatform(Stream stream)
	{
		Debug.Profiler.ProfileResourceFunction!();

		uint8[] ddsData = new:ScopedAlloc! uint8[stream.Length];

		var result = stream.TryRead(ddsData);

		if (result case .Err(let err))
		{
			Log.EngineLogger.Error($"Failed to read texture data from stream. Error: {err}");
		}
		
		DirectX.D3D11.ID3D11Texture2D* texture = null;
		DirectX.D3D11.ID3D11ShaderResourceView* view = null;

		DirectX.Common.HResult loadResult = DDSTextureLoader.CreateDDSTextureFromMemory(GlitchyEngine.Platform.DX11.NativeDevice,
			ddsData.Ptr, (uint)ddsData.Count, (.)&texture, &view);

		view.Release();

		return true;
	}

	private static Texture LoadTexture(Stream data, EditorTextureAssetLoaderConfig config)
	{
		Debug.Profiler.ProfileResourceFunction!();

		List<LoadedSurface> surfaces = scope .();
		LoadedTextureInfo textureInfo;
		
		// Make sure we clean up the pixel data
		defer { delete textureInfo.PixelData; }


		switch(GetTextureType(data))
		{
		case .DDS:

			var v = data.Position;

			//LoadDdsResourcePlatform(data);

			data.Position = v;

			Result<void> result = LoadDds(data, config, surfaces, out textureInfo);

			if (result case .Err)
				return null;

		case .PNG:
			Result<void> result = LoadPng(data, config, surfaces, out textureInfo);
			
			if (result case .Err)
				return null;

		case .Unknown:
			Log.EngineLogger.Error("Unknown texture format.");
			return null;
		}

		// Make the format SRGB or non-SRGB
		if (config.IsSRGB)
			textureInfo.PixelFormat = textureInfo.PixelFormat.GetSRGB();
		else
			textureInfo.PixelFormat = textureInfo.PixelFormat.GetNonSRGB();

		Texture texture = CreateTexture(surfaces, textureInfo);

		if (texture != null)
		{
			SetSampler(texture, config);
			texture.[Friend]Complete = true;
		}

		return texture;
	}

	private static Texture CreateTexture(List<LoadedSurface> surfaces, LoadedTextureInfo textureInfo)
	{
		TextureSliceData[] slices = scope TextureSliceData[surfaces.Count];
		
		for (int i < slices.Count)
		{
			slices[i] = .(surfaces[i].Data.Ptr, surfaces[i].Pitch, surfaces[i].SlicePitch);
		}

		//slices[0].SlicePitch = (.)(surfaces[0].Pitch * textureInfo.Height);

		switch (textureInfo.Dimension)
		{
		//case .Texture1D:
		case .Texture2D:
			if (textureInfo.IsCubeMap)
			{
				Texture2DDesc staging = .();
				
				staging.Width = (.)textureInfo.Width;
				staging.Height = (.)textureInfo.Height;

				staging.MipLevels = (.)textureInfo.MipMapCount;
				staging.ArraySize = (.)textureInfo.ArraySize;

				staging.Format = (.)textureInfo.PixelFormat;

				// TODO: allow enabling read/write
				staging.CpuAccess = .None;
				staging.Usage = .Default;

				TextureCube cubeTexture = new TextureCube(staging);

				//cubeTexture.SetData();

				for (let surface in surfaces)
				{
					cubeTexture.SetData(surface.Data.Ptr, surface.Pitch / staging.Width, (TextureCubeFace)surface.CubeFace, (.)surface.ArrayIndex, (.)surface.MipLevel);
				}
				
				return cubeTexture;
			}
			else
			{
				Texture2DDesc staging = .();
				
				staging.Width = (.)textureInfo.Width;
				staging.Height = (.)textureInfo.Height;

				staging.MipLevels = (.)textureInfo.MipMapCount;
				staging.ArraySize = (.)textureInfo.ArraySize;

				staging.Format = (.)textureInfo.PixelFormat;

				// TODO: allow enabling read/write
				staging.CpuAccess = .None;
				staging.Usage = .Immutable;

				Texture2D stagingTexture = new Texture2D(staging);

				stagingTexture.SetData(slices);
				
				/*for (let surface in surfaces)
				{
					stagingTexture.[Friend]PlatformSetData(surface.Data.Ptr, surface.Pitch / staging.Width, 0, 0, staging.Width, staging.Height, (.)surface.ArrayIndex, (.)surface.MipLevel, .Write);
				}*/
				
				return stagingTexture;
			}
		default:
			Runtime.NotImplemented();
		}

		return null;
	}

	private static Result<void> LoadPng(Stream data, EditorTextureAssetLoaderConfig config, List<LoadedSurface> surfaces, out LoadedTextureInfo textureInfo)
	{
		Debug.Profiler.ProfileResourceFunction!();
		
		textureInfo = .();

		uint8[] pngData = new:ScopedAlloc! uint8[data.Length];

		var result = data.TryRead(pngData);

		if (result case .Err(let err))
		{
			Log.EngineLogger.Error($"Failed to read data from stream. Texture: Error: {err}");
			return .Err;
		}

		uint8* rawData = null;
		defer
		{
			if (rawData != null)
				LodePng.LodePng.Free(rawData);
		}

		uint32 width = 0, height = 0;

		{
			Debug.Profiler.ProfileResourceScope!("LodePng.LodePng.Decode32");
			uint32 errorCode = LodePng.LodePng.Decode32(&rawData, &width, &height, pngData.Ptr, (.)pngData.Count);
			if (errorCode != 0)
			{
				Log.EngineLogger.Error($"Failed to decode PNG file {errorCode}.");
				return .Err;
			}
		}

		uint8[] pixelData = new uint8[4 * width * height];
		Internal.MemCpy(pixelData.Ptr, rawData, pixelData.Count);

		LoadedSurface surface = .();
		surface.Data = Span<uint8>(pixelData);
		surface.Pitch = 4 * width;
		surface.SlicePitch = 0;
		surface.ArrayIndex = 0;
		surface.MipLevel = 0;

		surfaces.Add(surface);

		//Texture2DDesc desc = .(width, height, config.IsSRGB ? .R8G8B8A8_UNorm_SRGB : .R8G8B8A8_UNorm, 1, 1, .Immutable);
		//Texture2D texture = new Texture2D(desc);
		//texture.SetData<Color>((.)rawData);

		// TODO: Generate mip maps

		textureInfo.PixelData = pixelData;
		textureInfo.Width = width;
		textureInfo.Height = height;
		textureInfo.Depth = 1;

		textureInfo.ArraySize = 1;
		textureInfo.MipMapCount = 1;

		textureInfo.Dimension = .Texture2D;

		textureInfo.IsCubeMap = false;

		textureInfo.PixelFormat = config.IsSRGB ? .R8G8B8A8_UNorm_SRGB : .R8G8B8A8_UNorm;

		return .Ok;

		//return texture;
	}

	private static Result<void> LoadDds(Stream data, EditorTextureAssetLoaderConfig config, List<LoadedSurface> surfaces, out LoadedTextureInfo textureInfo)
	{
		var result = DdsImporter.LoadDds(data, config.IsSRGB, surfaces, out textureInfo);

		if (result case .Err)
			return .Err;

		return .Ok;
	}
	
	private static void SetSampler(Texture texture, EditorTextureAssetLoaderConfig config)
	{
		using (SamplerState samplerState = SamplerStateManager.GetSampler(config.SamplerStateDescription))
		{
			texture.SamplerState = samplerState;
		}
	}

	private static Texture2D _placeholder2D;
	private static TextureCube _placeholderCube;

	private static Texture2D _error2D;
	private static TextureCube _errorCube;

	public Asset GetPlaceholderAsset(Type assetType)
	{
		switch (assetType)
		{
		case typeof(TextureCube):
			if (_placeholderCube == null)
			{
				// TODO: immutable
				Texture2DDesc desc = .(1, 1, .R8G8B8A8_UNorm, 1, 1, .Default, .None);

				_placeholderCube = new TextureCube(desc);
				_placeholderCube.SamplerState = SamplerStateManager.PointWrap;
				Color color = Color.Cyan;
				_placeholderCube.SetData<Color>(&color, .PositiveX);
				_placeholderCube.SetData<Color>(&color, .NegativeX);
				_placeholderCube.SetData<Color>(&color, .PositiveY);
				_placeholderCube.SetData<Color>(&color, .NegativeY);
				_placeholderCube.SetData<Color>(&color, .PositiveZ);
				_placeholderCube.SetData<Color>(&color, .NegativeZ);

				Content.ManageAsset(_placeholderCube);
				_placeholderCube.ReleaseRef();

				_placeholderCube.[Friend]Complete = false;
			}

			return _placeholderCube;
		case typeof(Texture2D):
			fallthrough;
		default:
			if (_placeholder2D == null)
			{
				Texture2DDesc desc = .(1, 1, .R8G8B8A8_UNorm, 1, 1, .Immutable, .None);

				_placeholder2D = new Texture2D(desc);
				_placeholder2D.SamplerState = SamplerStateManager.PointWrap;
				Color color = Color.Cyan;
				_placeholder2D.SetData<Color>(&color);

				Content.ManageAsset(_placeholder2D);
				_placeholder2D.ReleaseRef();

				_placeholder2D.[Friend]Complete = false;
			}

			return _placeholder2D;
		}
	}

	public Asset GetErrorAsset(Type assetType)
	{
		switch (assetType)
		{
		case typeof(TextureCube):
			if (_placeholderCube == null)
			{
				// TODO: immutable
				Texture2DDesc desc = .(2, 2, .R8G8B8A8_UNorm, 1, 1, .Default, .None);

				_errorCube = new TextureCube(desc);
				_errorCube.SamplerState = SamplerStateManager.PointWrap;
				
				Color[4] color = .(Color.HotPink, Color.Black, Color.Black, Color.HotPink);

				_errorCube.SetData<Color>(&color, .PositiveX);
				_errorCube.SetData<Color>(&color, .NegativeX);
				_errorCube.SetData<Color>(&color, .PositiveY);
				_errorCube.SetData<Color>(&color, .NegativeY);
				_errorCube.SetData<Color>(&color, .PositiveZ);
				_errorCube.SetData<Color>(&color, .NegativeZ);

				Content.ManageAsset(_errorCube);
				_errorCube.ReleaseRef();

				_errorCube.[Friend]Complete = false;
			}

			return _placeholderCube;
		case typeof(Texture2D):
			fallthrough;
		default:
			if (_error2D == null)
			{
				Texture2DDesc desc = .(2, 2, .R8G8B8A8_UNorm, 1, 1, .Immutable, .None);

				_error2D = new Texture2D(desc);
				_error2D.SamplerState = SamplerStateManager.PointWrap;
				
				Color[4] color = .(Color.HotPink, Color.Black, Color.Black, Color.HotPink);

				_error2D.SetData<Color>(&color);

				Content.ManageAsset(_error2D);
				_error2D.ReleaseRef();

				_placeholder2D.[Friend]Complete = true;
			}

			return _error2D;
		}
	}
}
