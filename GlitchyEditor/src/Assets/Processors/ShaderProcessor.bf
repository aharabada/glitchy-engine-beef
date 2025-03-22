using GlitchyEditor.Assets.Importers;
using System;
using GlitchyEngine.Content;
using System.Collections;
using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;

namespace GlitchyEditor.Assets.Processors;

class ProcessedShader : ProcessedResource
{
	public struct TextureEntry
	{
		public StringView Name;
		public TextureDimension TextureDimension;
		public int32 VertexShaderBindPoint;
		public int32 PixelShaderBindPoint;

		public static readonly TextureEntry Default = .() {
			Name = null,
			TextureDimension = .Unknown,
			VertexShaderBindPoint = -1,
			PixelShaderBindPoint = -1
		};
	}

	public struct ConstantBufferEntry
	{
		public ReflectedConstantBuffer ConstantBuffer;
		public int32 VertexShaderBindPoint;
		public int32 PixelShaderBindPoint;

		public static readonly Self Default = .() {
			ConstantBuffer = null,
			VertexShaderBindPoint = -1,
			PixelShaderBindPoint = -1,
		};
	}

	public override AssetType AssetType => .Shader;

	public CompiledShader VertexShader ~ delete _;
	public CompiledShader PixelShader ~ delete _;

	Dictionary<StringView, ConstantBufferEntry> _constantBuffers = new .() ~ delete _; // Only delete container, Buffers come from shaders
	
	Dictionary<StringView, TextureEntry> _textures = new .() ~ delete _;

	public Dictionary<StringView, ConstantBufferEntry> ConstantBuffers => _constantBuffers;
	public Dictionary<StringView, TextureEntry> Textures => _textures;

	public this(AssetIdentifier ownAssetIdentifier, AssetHandle assetHandle) : base(ownAssetIdentifier, assetHandle)
	{

	}

	public void AddConstantBuffer(ConstantBufferEntry buffer)
	{
		_constantBuffers.Add(buffer.ConstantBuffer.Name, buffer);
	}

	public void AddTextureEntry(TextureEntry textureEntry)
	{
		_textures.Add(textureEntry.Name, textureEntry);
	}
}

class ShaderVariable
{
	private String _name ~ delete _;
	private String _previewName ~ delete _;
	private String _editorType ~ delete _;

	private Dictionary<String, Variant> _parameters = new .() ~ {
		for (var (entryKey, entry) in _)
		{
			delete entryKey;
			entry.Dispose();
		}
		delete _;
	};

	public StringView Name
	{
		get => _name;
		set => String.NewOrSet!(_name, value);
	}
	
	public StringView PreviewName
	{
		get => _previewName;
		set => String.NewOrSet!(_previewName, value);
	}
	
	public StringView EditorType
	{
		get => _editorType;
		set => String.NewOrSet!(_editorType, value);
	}

	public Variant MinValue ~ _.Dispose();
	public Variant MaxValue ~ _.Dispose();

	public Dictionary<String, Variant> Parameters => _parameters;

	public void AddParameter(StringView name, Variant value)
	{
		_parameters.Add(new String(name), value);
	}
}

class ShaderProcessor : IAssetProcessor
{
	public AssetProcessorConfig CreateDefaultConfig()
	{
		return new AssetProcessorConfig();
	}

	public static Type ProcessedAssetType => typeof(ImportedShader);

	public Result<void> Process(ImportedResource importedResource, AssetConfig config, List<ProcessedResource> outProcessedResources)
	{
		Log.EngineLogger.AssertDebug(importedResource is ImportedShader);

		Try!(ProcessShader(importedResource as ImportedShader, config, outProcessedResources));

		return default;
	}

	private static Result<void> ProcessShader(ImportedShader importedShader, AssetConfig config, List<ProcessedResource> outProcessedResources)
	{
		String vsName = scope String();
		String psName = scope String();

		Dictionary<StringView, ShaderVariable> variables = scope .();
		List<String> bufferNames = scope .();
		// Name in Shader -> Name in Engine
		Dictionary<StringView, StringView> engineBuffers = scope .();

		ProcessedShader processedShader = null;

		defer
		{
			ClearDictionaryAndDeleteValues!(variables);
			ClearAndDeleteItems!(bufferNames);

			if (@return case .Err)
			{
				delete processedShader;
			}
		}

		String tmpCode = new String(importedShader.HlslCode);

		// TODO: This is terrible. Currently we process too often... (here + each shader stage)
		Try!(ShaderCodePreprocessor.ProcessFileContent(tmpCode , vsName, psName, variables, bufferNames, engineBuffers));

		delete tmpCode;

		if (String.IsNullOrWhiteSpace(vsName) && String.IsNullOrWhiteSpace(psName))
		{
			// this is not an effect -> we don't need to compile it
			return .Ok;
		}

		processedShader = new ProcessedShader(new AssetIdentifier(importedShader.AssetIdentifier), config.AssetHandle);

		Try!(CompileAndReflect(vsName, psName, importedShader, importedShader.HlslCode, processedShader));

		Try!(MergeResources(processedShader));

		outProcessedResources.Add(processedShader);

		return .Ok;
	}

	private static Result<void> MergeResources(ProcessedShader processedShader)
	{
		Try!(MergeConstantBuffers(processedShader));
		Try!(MergeTextures(processedShader));

		return .Ok;
	}

	private static Result<void> MergeConstantBuffers(ProcessedShader processedShader)
	{
		HashSet<StringView> bufferNames = scope .();

		void AddBufferNames(CompiledShader shader)
		{
			for (StringView name in shader.ConstantBuffers.Keys)
			{
				bufferNames.Add(name);
			}
		}

		AddBufferNames(processedShader.VertexShader);
		AddBufferNames(processedShader.PixelShader);

		for (StringView bufferName in bufferNames)
		{
			Result<ReflectedConstantBuffer> vsBufferResult = processedShader.VertexShader.ConstantBuffers.GetValue(bufferName);
			Result<ReflectedConstantBuffer> psBufferResult = processedShader.PixelShader.ConstantBuffers.GetValue(bufferName);
			
			ProcessedShader.ConstantBufferEntry constantBufferEntry = .Default;

			if (vsBufferResult case .Ok(let vsBuffer) && psBufferResult case .Ok(let psBuffer))
			{
				// Choose larger buffer
				constantBufferEntry.ConstantBuffer = (vsBuffer.Size >= psBuffer.Size) ? vsBuffer : psBuffer;
				constantBufferEntry.VertexShaderBindPoint = (.)vsBuffer.BindPoint;
				constantBufferEntry.PixelShaderBindPoint = (.)psBuffer.BindPoint;
			}
			else if (vsBufferResult case .Ok(let vsBuffer))
			{
				constantBufferEntry.ConstantBuffer = vsBuffer;
				constantBufferEntry.VertexShaderBindPoint = (.)vsBuffer.BindPoint;
			}
			else if (psBufferResult case .Ok(let psBuffer))
			{
				constantBufferEntry.ConstantBuffer = psBuffer;
				constantBufferEntry.PixelShaderBindPoint = (.)psBuffer.BindPoint;
			}

			Log.EngineLogger.Assert(constantBufferEntry.ConstantBuffer != null);
			Log.EngineLogger.Assert(constantBufferEntry.VertexShaderBindPoint > -1 || constantBufferEntry.PixelShaderBindPoint > -1);

			processedShader.AddConstantBuffer(constantBufferEntry);
		}

		return .Ok;
	}
	
	static ref ProcessedShader.TextureEntry AddOrGetTextureEntry(ProcessedShader processedShader, ReflectedTexture reflectedTexture)
	{
		if (!processedShader.Textures.ContainsKey(reflectedTexture.Name))
		{
			ProcessedShader.TextureEntry textureEntry = .Default;
			textureEntry.Name = reflectedTexture.Name;
			textureEntry.TextureDimension = reflectedTexture.TextureDimension;

			processedShader.Textures.Add(textureEntry.Name, textureEntry);
		}

		ref ProcessedShader.TextureEntry entry = ref processedShader.Textures[reflectedTexture.Name];

		return ref entry;
	}

	private static Result<void> MergeTextures(ProcessedShader processedShader)
	{
		for (let (textureName, reflectedTexture) in processedShader.VertexShader.Textures)
		{
			ref ProcessedShader.TextureEntry textureEntry = ref AddOrGetTextureEntry(processedShader, reflectedTexture);
			textureEntry.VertexShaderBindPoint = (int32)reflectedTexture.BindPoint;
		}

		for (let (textureName, reflectedTexture) in processedShader.PixelShader.Textures)
		{
			ref ProcessedShader.TextureEntry textureEntry = ref AddOrGetTextureEntry(processedShader, reflectedTexture);
			textureEntry.PixelShaderBindPoint = (int32)reflectedTexture.BindPoint;
		}

		return .Ok;
	}

	private static Result<void> CompileAndReflect(StringView vsName, StringView psName, ImportedShader shader, StringView code, ProcessedShader processedShader)
	{
		if (!vsName.IsWhiteSpace)
		{
			processedShader.VertexShader = Try!(CompileAndReflectVertexShader(vsName, shader, code));
		}

		if (!psName.IsWhiteSpace)
		{
			processedShader.PixelShader = Try!(CompileAndReflectPixelShader(psName, shader, code));
		}

		return .Ok;
	}

	private static Result<CompiledShader> CompileAndReflectVertexShader(StringView vsName, ImportedShader importedShader, StringView code)
	{
		Debug.Profiler.ProfileResourceFunction!();

		return ShaderCompiler.CompileAndReflectShader(code, importedShader.AssetIdentifier, vsName, "vs_5_0", .());
	}

	private static Result<CompiledShader> CompileAndReflectPixelShader(StringView vsName, ImportedShader importedShader, StringView code)
	{
		Debug.Profiler.ProfileResourceFunction!();

		return ShaderCompiler.CompileAndReflectShader(code, importedShader.AssetIdentifier, vsName, "ps_5_0", .());
	}
}
