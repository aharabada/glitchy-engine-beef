#if GE_GRAPHICS_DX11

using System;
using GlitchyEngine.Renderer;
using DirectX.Common;
using DirectX.D3D11;
using DirectX.D3DCompiler;
using DirectX.D3D11Shader;
using System.IO;
using GlitchyEngine.Content;
using System.Collections;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	struct ContentManagerInclude : ID3DInclude, IDisposable
	{
		private VTable _vTable;

		private IContentManager _contentManager;

		private Dictionary<char8*, (String FileContent, void* Data, uint32 Length)> _loadedFiles;

		private String _parentFileDirectory;

		public this(IContentManager contentManager, String parentFileDirectory)
		{
			_contentManager = contentManager;
			_parentFileDirectory = parentFileDirectory;
			_loadedFiles = new Dictionary<char8*, (String FileContent, void* Data, uint32 Length)>();

			_vTable.Open = => Open;
			_vTable.Close = => Close;

			_vt = &_vTable;
		}

		public void Dispose()
		{
			delete _loadedFiles;
		}

		public static HResult Open(ID3DInclude* self, IncludeType includeType, char8* fileName, void* parentData, void** data, uint32* bytes)
		{
			ContentManagerInclude* includer = (.)self;

			if (includer._loadedFiles.TryGetValue(fileName, let value))
			{
				*data = value.Data;
				*bytes = value.Length;

				return .S_OK;
			}

			String pathNextToParent = scope .();

			Path.Combine(pathNextToParent, includer._parentFileDirectory, StringView(fileName));

			Stream fileStream = Application.Get().ContentManager.GetStream(pathNextToParent);

			if (fileStream == null)
			{
				fileStream = Application.Get().ContentManager.GetStream(StringView(fileName));
			}

			if (fileStream == null)
			{
				Log.EngineLogger.Error($"Failed to include file \"{fileName}\"");
				return .E_FILENOTFOUND;
			}
			
			String fileContent = new String();

			{
				StreamReader reader = scope .(fileStream);

				reader.ReadToEnd(fileContent);

				includer._loadedFiles.Add(fileName, (fileContent, fileContent.Ptr, (uint32)fileContent.Length));
			}

			delete fileStream;

			*data = (void*)fileContent.Ptr;
			*bytes = (uint32)fileContent.Length;

			return .S_OK;
		}

		public static HResult Close(ID3DInclude* self, void** data)
		{
			ContentManagerInclude* includer = (.)self;

			for (var v in includer._loadedFiles)
			{
				if (v.value.Data == data)
				{
					delete v.value.FileContent;

					includer._loadedFiles.Remove(v.key);
				}
			}

			return .S_OK;
		}
	}

	extension Shader
	{
		internal ID3D11DeviceChild* nativeShader ~ _?.Release();

		/**
		 * Internal compiled code of the shader.
		 */
		internal ID3DBlob* nativeCode ~ _?.Release();
		
		protected const ShaderCompileFlags DefaultCompileFlags = .EnableStrictness | 
#if DEBUG
			.Debug;
#else
			.OptimizationLevel3;
#endif

		internal static void PlattformCompileShaderFromSource(StringView code, StringView? fileName, ShaderDefine[] macros, String entryPoint, String target, ShaderCompileFlags compileFlags, IContentManager contentManager, out ID3DBlob* shaderBlob)
		{
			Debug.Profiler.ProfileResourceFunction!();

			ShaderMacro* nativeMacros = macros == null ? null : new:ScopedAlloc! ShaderMacro[macros.Count]*; 

			for(int i < macros?.Count ?? 0)
			{
				nativeMacros[i].Name = macros[i].Name.ToScopedNativeWChar!();
				nativeMacros[i].Definition = macros[i].Definition.ToScopedNativeWChar!();
			}

			// Todo: sourceName, includes,
			// Todo: variable shader target?

			ID3DBlob* errorBlob = null;

			String directory = scope .();

			Path.GetDirectoryPath(fileName.Value, directory);

			using (ContentManagerInclude includer = .(contentManager, directory))
			{
				//ID3DInclude.StandardInclude

				shaderBlob = null;
				var result = D3DCompiler.D3DCompile(code.Ptr, (.)code.Length, fileName?.ToScopeCStr!(), nativeMacros, &includer, entryPoint, target, compileFlags, .None, &shaderBlob, &errorBlob);

				if(result.Failed)
				{
					StringView str = StringView((char8*)errorBlob.GetBufferPointer(), (int)errorBlob.GetBufferSize());
					Log.EngineLogger.Error($"Failed to compile Shader: Error Code({(int)result}): {result} | Error Message: {str}");
				}
			}
			
			Log.EngineLogger.Assert(shaderBlob != null, "Shader compilation failed.");
		}

		protected internal void Reflect(ID3DBlob* shaderCode)
		{
			Debug.Profiler.ProfileResourceFunction!();

			ID3D11ShaderReflection* reflection = null;
			{
				Debug.Profiler.ProfileResourceScope!("D3DReflect");

				var result = D3DCompiler.D3DReflect(shaderCode.GetBufferPointer(), shaderCode.GetBufferSize(), &reflection);
				if(result.Failed)
				{
					Log.EngineLogger.Error($"Failed to reflect shader: Message ({(int)result}): {result}");
				}
			}

			reflection.GetDescription(let desc);

			uint32 resourceCount = desc.BoundResources;
			for (uint32 i < resourceCount)
			{
				var res = reflection.GetResourceBindingDescription(i, let bindDesc);

				if (res.Failed)
				{
					Log.EngineLogger.Error($"Error({(int)res}) {res}: Failed to get resource binding desc for resource {i}");
					continue;
				}

				switch(bindDesc.Type)
				{
				case .ConstantBuffer:
					var bufferReflection = reflection.GetConstantBufferByName(bindDesc.Name);

					bufferReflection.GetDescription(let bufferDesc);

					// ConstantBuffer
					if(bufferDesc.Type == .D3D11_CT_CBUFFER)
					{
						let buffer = new ConstantBuffer(bufferReflection);

						_buffers.Add(bindDesc.BindPoint, buffer.Name, buffer);

						buffer.ReleaseRef();
					}
				case .Texture:

					TextureDimension texDim;
					
					switch (bindDesc.Dimension)
					{
					case .Texture1D:
						texDim = .Texture1D;
					case .Texture1DArray:
						texDim = .Texture1DArray;
					case .Texture2D:
						texDim = .Texture2D;
					case .Texture2DArray:
						texDim = .Texture2DArray;
					case .Texture3D:
						texDim = .Texture3D;
					case .TextureCube:
						texDim = .TextureCube;
					case .TextureCubeArray:
						texDim = .TextureCubeArray;
					default:
						texDim = .Unknown;
					}

					_textures.Add(scope String(bindDesc.Name), bindDesc.BindPoint, TextureViewBinding(null, null), texDim);
				case .Sampler:
					// TODO: do we have to do something for samplers?
				default:
					Log.EngineLogger.Warning($"Unhandled shader resource type: \"{bindDesc.Type}\"");
				}
			}
			
			reflection.Release();
		}
	}
}

#endif
