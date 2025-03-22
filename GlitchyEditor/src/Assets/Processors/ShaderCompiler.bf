using System;
using DirectX.Common;
using GlitchyEngine;
using System.IO;
using DirectX.D3DCompiler;
using GlitchyEngine.Renderer;
using DirectX.D3D11Shader;
using System.Collections;
using GlitchyEngine.Content;

namespace GlitchyEditor.Assets.Processors;

using internal GlitchyEditor.Assets.Processors;

class ShaderDefineValue
{
	private String _name ~ delete _;
	private String _definition ~ delete _;

	public StringView Name
	{
		get => _name;
		set => String.NewOrSet!(_name, value);
	}
	
	public StringView Definition
	{
		get => _definition;
		set => String.NewOrSet!(_definition, value);
	}
}

class CompiledShader
{
	private Dictionary<StringView, ReflectedConstantBuffer> _buffers = new .() ~ DeleteDictionaryAndValues!(_);
	private Dictionary<StringView, ReflectedTexture> _textures = new .() ~ DeleteDictionaryAndValues!(_);

	public Dictionary<StringView, ReflectedConstantBuffer> ConstantBuffers => _buffers;
	public Dictionary<StringView, ReflectedTexture> Textures => _textures;

	public extern Span<uint8> Blob {get;}

	public void AddConstantBuffer(ReflectedConstantBuffer buffer)
	{
		_buffers.Add(buffer.Name, buffer);
	}

	public void AddTexture(ReflectedTexture texture)
	{
		_textures.Add(texture.Name, texture);
	}
}

class ReflectedConstantBuffer
{
	private String _name ~ delete _;
	private String _engineBufferName ~ delete _;

	public int Size;

	public int BindPoint;

	public StringView Name
	{
		get => _name;
		set => String.NewOrSet!(_name, value);
	}

	public StringView EngineBufferName
	{
		get => _engineBufferName;
		set => String.NewOrSet!(_engineBufferName, value);
	}
	
	private Dictionary<StringView, ReflectedConstantBufferVariable> _variables = new .() ~ DeleteDictionaryAndValues!(_);

	public Dictionary<StringView, ReflectedConstantBufferVariable> Variables => _variables;

	public void AddVariable(ReflectedConstantBufferVariable vaiable)
	{
		_variables.Add(vaiable.Name, vaiable);
	}

	public uint8[] RawData ~ delete _;
}

class ReflectedTexture
{
	private String _name ~ delete _;

	public uint32 BindPoint;

	public TextureDimension TextureDimension;

	public StringView Name
	{
		get => _name;
		set => String.NewOrSet!(_name, value);
	}

	public this(StringView name, uint32 bindPoint, TextureDimension textureDimension)
	{
		Name = name;
		BindPoint = bindPoint;
		TextureDimension = textureDimension;
	}
}

class ReflectedConstantBufferVariable
{
	private String _name ~ delete _;
	private String _previewName ~ delete _;
	private String _editorType ~ delete _;

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

	public int Offset;
	public int SizeInBytes;
	public bool IsUsed;

	public GlitchyEngine.Renderer.ShaderVariableType ElementType;
	public int Rows;
	public int Columns;
	
	public int ArraySize;
	
	public Variant MinValue;
	public Variant MaxValue;
}

// TODO: Dx11
extension CompiledShader
{
	internal ID3DBlob* _shaderBlob;

	public override Span<uint8> Blob => Span<uint8>((uint8*)_shaderBlob.GetBufferPointer(), (int)_shaderBlob.GetBufferSize());
}

class ShaderCompiler
{
	public static Result<CompiledShader> CompileAndReflectShader(StringView code, AssetIdentifier assetIdentifier, StringView entryPoint, StringView compileTarget, Span<ShaderDefineValue> defines)
	{
		defer {
			if (@return case .Err)
				delete shader;
		}

		CompiledShader shader = new CompiledShader();

		ShaderCompilationContext context = scope .();

		Try!(PlatformCompileShaderFromSource(code, assetIdentifier, entryPoint, compileTarget, defines, shader, context));

		Try!(PlatformReflectShader(shader, context));

		return shader;
	}

	protected static extern Result<void> PlatformCompileShaderFromSource(StringView code, AssetIdentifier fileName, StringView entryPoint, StringView compileTarget, Span<ShaderDefineValue> defines, CompiledShader outShader, ShaderCompilationContext context);

	protected static extern Result<void> PlatformReflectShader(CompiledShader shader, ShaderCompilationContext context);
}

class ShaderCompilationContext
{
	public append String VsName = String();
	public append String PsName = String();

	public append Dictionary<StringView, ShaderVariable> Variables = .() ~ ClearDictionaryAndDeleteValues!(_);
	public append List<String> BufferNames = .() ~ ClearAndDeleteItems!(_);
	// Name in Shader -> Name in Engine
	public append Dictionary<StringView, StringView> EngineBuffers = .();
}

// TODO: Dx11
extension ShaderCompiler
{
	// TODO: This should be a setting per shader, really!
	protected const ShaderCompileFlags DefaultCompileFlags = .EnableStrictness |
#if DEBUG
	.Debug;
#else
	.OptimizationLevel3;
#endif

	protected static override Result<void> PlatformCompileShaderFromSource(StringView code, AssetIdentifier fileName, StringView entryPoint, StringView compileTarget, Span<ShaderDefineValue> defines, CompiledShader outShader, ShaderCompilationContext context)
	{
		Debug.Profiler.ProfileResourceFunction!();
		
		Log.EngineLogger.AssertDebug(outShader._shaderBlob == null);

		ShaderMacro* nativeMacros = defines.Length == 0 ? null : new:ScopedAlloc! ShaderMacro[defines.Length]*; 
		
		for(int i < defines.Length)
		{
			nativeMacros[i].Name = defines[i].Name.ToScopedNativeWChar!::();
			nativeMacros[i].Definition = defines[i].Definition.ToScopedNativeWChar!::();
		}
		
		// Todo: sourceName, includes,
		// Todo: variable shader target?
		
		ID3DBlob* errorBlob = null;
		
		String directory = scope .();

		Path.GetDirectoryPath(fileName, directory);

		String shaderCode = new:ScopedAlloc! String(code);
		
		Try!(ShaderCodePreprocessor.ProcessFileContent(shaderCode, context.VsName, context.PsName, context.Variables, context.BufferNames, context.EngineBuffers));

		using (let includer = PreprocessingIncluder(directory, context))
		{
			var result = D3DCompiler.D3DCompile(code.Ptr, (.)code.Length, fileName.FullIdentifier.ToScopeCStr!(), nativeMacros, &includer, entryPoint.ToScopeCStr!(),
				compileTarget.ToScopeCStr!(), DefaultCompileFlags /* Pass down compile flags? */, .None, &outShader._shaderBlob, &errorBlob);

			if(result.Failed)
			{
				StringView str = StringView((char8*)errorBlob.GetBufferPointer(), (int)errorBlob.GetBufferSize());
				Log.EngineLogger.Error($"Failed to compile Shader: Error Code({(int)result}): {result} | Error Message: {str}");
				return .Err;
			}
		}

		Log.EngineLogger.Assert(outShader._shaderBlob != null, "Shader compilation failed.");

		return .Ok;
	}

	protected override static Result<void> PlatformReflectShader(CompiledShader shader, ShaderCompilationContext context)
	{
		Debug.Profiler.ProfileResourceFunction!();

		ID3D11ShaderReflection* reflection = null;
		defer { reflection?.Release(); }

		var reflectionResult = D3DCompiler.D3DReflect(shader._shaderBlob.GetBufferPointer(), shader._shaderBlob.GetBufferSize(), &reflection);
		if (reflectionResult.Failed)
		{
			Log.EngineLogger.Error($"Failed to reflect shader: ({(int)reflectionResult}) {reflectionResult}");
			return .Err;
		}

		var getDescResult = reflection.GetDescription(let desc);
		if (getDescResult.Failed)
		{
			Log.EngineLogger.Error($"GetDescription failed: ({(int)getDescResult}) {getDescResult}");
			return .Err;
		}

		uint32 resourceCount = desc.BoundResources;
		for (uint32 i < resourceCount)
		{
			var res = reflection.GetResourceBindingDescription(i, let bindDesc);

			if (res.Failed)
			{
				Log.EngineLogger.Error($"Error({(int)res}) {res}: Failed to get resource binding desc for resource {i}");
				return .Err;
			}

			switch(bindDesc.Type)
			{
			case .ConstantBuffer:
				//var bufferReflection = reflection.GetConstantBufferByName(bindDesc.Name);
				var bufferReflection = reflection.GetConstantBufferByName(bindDesc.Name);

				bufferReflection.GetDescription(let bufferDesc);

				// ConstantBuffer
				if(bufferDesc.Type == .D3D11_CT_CBUFFER)
				{
					ReflectedConstantBuffer cbuffer = Try!(ReflectConstantBuffer(bindDesc, bufferReflection, context));
					shader.AddConstantBuffer(cbuffer);
				}
			case .Texture:
				TextureDimension textureDimension;
				
				switch (bindDesc.Dimension)
				{
				case .Texture1D:
					textureDimension = .Texture1D;
				case .Texture1DArray:
					textureDimension = .Texture1DArray;
				case .Texture2D:
					textureDimension = .Texture2D;
				case .Texture2DArray:
					textureDimension = .Texture2DArray;
				case .Texture3D:
					textureDimension = .Texture3D;
				case .TextureCube:
					textureDimension = .TextureCube;
				case .TextureCubeArray:
					textureDimension = .TextureCubeArray;
				default:
					textureDimension = .Unknown;
				}

				shader.AddTexture(new ReflectedTexture(StringView(bindDesc.Name), bindDesc.BindPoint, textureDimension));
			case .Sampler:
				// There is nothing to do for samplers
			default:
				Log.EngineLogger.Warning($"Unhandled shader resource type: \"{bindDesc.Type}\"");
			}
		}

		return .Ok;
	}

	private static Result<ReflectedConstantBuffer> ReflectConstantBuffer(ShaderInputBindDescription bindDesc, ID3D11ShaderReflectionConstantBuffer* bufferReflection, ShaderCompilationContext context)
	{
		Debug.Profiler.ProfileResourceFunction!();

		var buffer = new ReflectedConstantBuffer();

		HResult result = bufferReflection.GetDescription(let bufferDescription);
		Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to get buffer description. Error({(int)result}): {result}");

		Log.EngineLogger.AssertDebug(bufferDescription.Type == .D3D_CT_CBUFFER, "The buffer is not of type \"D3D_CT_CBUFFER\"");

		buffer.Name = StringView(bufferDescription.Name);
		buffer.Size = bufferDescription.Size;
		buffer.BindPoint = bindDesc.BindPoint;
		buffer.RawData = new uint8[buffer.Size];

		for(uint32 v = 0; v < bufferDescription.Variables; v++)
		{
			ID3D11ShaderReflectionVariable* variableReflection = bufferReflection.GetVariableByIndex(v);

			if (ReflectConstantBufferVariable(buffer, variableReflection, context) case .Err)
			{
				delete buffer;
				return .Err;
			}
		}

		if (context.EngineBuffers.TryGetValue(buffer.Name, let engineBufferName))
		{
			buffer.EngineBufferName = engineBufferName;
		}

		return buffer;
	}

	private static Result<void> ReflectConstantBufferVariable(ReflectedConstantBuffer buffer, ID3D11ShaderReflectionVariable* variableReflection, ShaderCompilationContext context)
	{
		Debug.Profiler.ProfileResourceFunction!();

		HResult getDescResult = variableReflection.GetDescription(let variableDescription);
		if (getDescResult.Failed)
		{
			Log.EngineLogger.Error($"Failed to get variable description. Error({(int)getDescResult}): {getDescResult}");
			return .Err;
		}

		let variableType = variableReflection.GetVariableType();
		let getTypeDescResult = variableType.GetDescription(let shaderTypeDescription);
		if (getTypeDescResult.Failed)
		{
			Log.EngineLogger.Error($"Failed to get variable description. Error({(int)getDescResult}): {getDescResult}");
			return .Ok;
		}
		
		ReflectedConstantBufferVariable variable = new ReflectedConstantBufferVariable();
		variable.Name = StringView(variableDescription.Name);

		variable.Offset = variableDescription.StartOffset;
		variable.SizeInBytes = variableDescription.Size;
		variable.IsUsed = variableDescription.uFlags.HasFlag(.Used);
		
		variable.Columns = shaderTypeDescription.Columns;
		variable.Rows = shaderTypeDescription.Rows;
		variable.ArraySize = shaderTypeDescription.Elements;

		switch(shaderTypeDescription.Type)
		{
		case .Bool:
			variable.ElementType = .Bool;
		case .Float:
			variable.ElementType = .Float;
		case .Int:
			variable.ElementType = .Int;
		case .UInt:
			variable.ElementType = .UInt;
		default:
			Log.EngineLogger.Error($"Unhandled shader variable type: {shaderTypeDescription.Type}.");
			delete variable;
			return .Err;
		}

		if (variableDescription.DefaultValue == null)
		{
			Internal.MemSet(&buffer.RawData[variable.Offset], 0, variable.SizeInBytes);
		}
		else
		{
			Internal.MemCpy(&buffer.RawData[variable.Offset], variableDescription.DefaultValue, variable.SizeInBytes);
		}

		if (context.Variables.TryGetValue(variable.Name, let variableAnnotation))
		{
			variable.PreviewName = variableAnnotation.PreviewName;
			variable.EditorType = variableAnnotation.EditorType;
			
			// TODO: We need to somehow validate against our variable type
			variable.MinValue = variableAnnotation.MinValue;
			variable.MaxValue = variableAnnotation.MaxValue;
		}

		buffer.AddVariable(variable);

		return .Ok;
	}
}

struct PreprocessingIncluder : ID3DInclude, IDisposable
{
	private VTable _vTable;

	private Dictionary<StringView, (String FileName, String FileContent)> _loadedFiles;

	private String _parentFileDirectory;

	private ShaderCompilationContext _context;

	public this(String parentFileDirectory, ShaderCompilationContext context)
	{
		_parentFileDirectory = parentFileDirectory;
		_loadedFiles = new Dictionary<StringView, (String FileName, String FileContent)>();

		_vTable.Open = => Open;
		_vTable.Close = => Close;

		_vt = &_vTable;

		_context = context;
	}

	public void Dispose()
	{
		for (let (key, value) in _loadedFiles)
		{
			delete value.FileName;
			delete value.FileContent;
		}

		delete _loadedFiles;
	}

	public static HResult Open(ID3DInclude* self, IncludeType includeType, char8* fileNamePtr, void* parentData, void** data, uint32* bytes)
	{
		PreprocessingIncluder* includer = (.)self;

		StringView fileName = StringView(fileNamePtr);

		if (includer._loadedFiles.TryGetValue(fileName, let value))
		{
			*data = (void*)value.FileContent.Ptr;
			*bytes = (uint32)value.FileContent.Length;

			return .S_OK;
		}
		
		String fullPath = scope .();

		Path.Combine(fullPath, includer._parentFileDirectory, fileName);

		if (!File.Exists(fullPath))
		{
			let treeResult = Editor.Instance.ContentManager.AssetHierarchy.GetNodeFromIdentifier(scope AssetIdentifier(fileName));

			if (var assetNode = treeResult)
			{
				fullPath.Set(assetNode->Path);
			}
			else
			{
				Log.EngineLogger.Error($"Failed to include shader file \"{fileName}\"");
				return .E_FILENOTFOUND;
			}
		}

		Stream fileStream = Application.Instance.ContentManager.GetStream(fullPath);

		if (fileStream == null)
		{
			fileStream = Application.Instance.ContentManager.GetStream(StringView(fileName));
		}

		if (fileStream == null)
		{
			return .E_FILENOTFOUND;
		}
		
		String fileContent = new String();

		{
			StreamReader reader = scope .(fileStream);

			reader.ReadToEnd(fileContent);

			String fileNameStr = new String(fileName);

			includer._loadedFiles.Add(fileNameStr, (fileNameStr, fileContent));
		}

		delete fileStream;

		String trashbin = scope String();

		if (ShaderCodePreprocessor.ProcessFileContent(fileContent, trashbin, trashbin, includer._context.Variables, includer._context.BufferNames, includer._context.EngineBuffers) case .Err)
		{
			return .E_FAIL;
		}

		*data = (void*)fileContent.Ptr;
		*bytes = (uint32)fileContent.Length;
		
		return .S_OK;
	}

	public static HResult Close(ID3DInclude* self, void** data)
	{
		PreprocessingIncluder* includer = (.)self;

		for (var v in includer._loadedFiles)
		{
			if (v.value.FileContent.Ptr == data)
			{
				includer._loadedFiles.Remove(v.key);
				delete v.value.FileContent;
				delete v.value.FileName;
				break;
			}
		}

		return .S_OK;
	}
}
