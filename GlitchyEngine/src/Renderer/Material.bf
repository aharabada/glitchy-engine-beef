using GlitchyEngine.Content;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using System;
using System.Collections;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer;

public class Material : Asset
{
	/**
	 * If true, this material is a runtime instance and can be changed by scripts.
	 * If false, it is the actual material from the harddrive and should not be modified by scripts.
	 * If a script tries to modify it, a runtime instance will be created.
	 */
	private bool _isRuntimeInstance = false;

	private Material _parent ~ _?.ReleaseRef();

	private Effect _effect ~ _?.ReleaseRef();

	private Dictionary<String, (AssetHandle<Texture> Handle, TextureDimension Dimension, int32? groupTarget)> _textures = new .() ~ DeleteDictionaryAndKeys!(_);

	private Dictionary<StringView, BufferVariable> _variables = new .() ~ delete _;

	private BufferCollection _bufferCollection ~ _?.ReleaseRef();

	public Effect Effect
	{
		get => _effect;
		set
		{
			SetReference!(_effect, value);

			if (_effect == null)
				return;

			Init();
		}
	}

	// TODO: allow changing
	public Material Parent => _parent;

	public bool IsRuntimeInstance => _isRuntimeInstance;

	public this()
	{

	}

	public this(Effect effect)
	{
		Effect = effect;
	}

	public this(Material parentMaterial, bool isRuntimeInstance)
	{
		_parent = parentMaterial..AddRef();
		Effect = _parent.Effect;
		_isRuntimeInstance = isRuntimeInstance;
	}

	private void Init()
	{	 	 
		decltype(_textures) newTextures = new .();

		// Get texture slots from effect
		for(let (name, effectTexture) in _effect.Textures)
		{
			// TODO: We need to be able to define default textures in the shader.
			// At least things like "Black", "White", "Normal"
			// At best whole paths. Shouldn't be that hard to do...

			AssetHandle<Texture> textureHandle = .Invalid;
			int32? groupTarget = null;

			if (_textures.TryGetValue(name, let oldMaterialTexture))
			{
				textureHandle = oldMaterialTexture.Handle;
				groupTarget = oldMaterialTexture.groupTarget;
			}

			if (textureHandle.IsValid)
			{
				if (textureHandle.Dimension != effectTexture.TextureDimension)
					textureHandle = .Invalid;
			}
			
			newTextures[new String(name)] = (textureHandle, effectTexture.TextureDimension, groupTarget);
		}

		DeleteDictionaryAndKeys!(_textures);
		_textures = newTextures;

		//InitRawData();
		InitBuffers();
	}

	private void InitBuffers()
	{
		_variables.Clear();
		_bufferCollection?.ReleaseRef();
		_bufferCollection = new BufferCollection();

		void InitVariables(ConstantBuffer buffer)
		{
			for (BufferVariable variable in buffer.Variables)
			{
				if (_variables.ContainsKey(variable.Name))
				{
					// TODO: Handle overlapping variable names?
					Log.EngineLogger.Error("Variable with same name already added to Material, skipping...");
					continue;
				}

				_variables.Add(variable.Name, variable);
			}
		}

		BufferCollection parentBuffers = _parent?._bufferCollection ?? _effect.Buffers;

		for (let (bufferName, buffer) in parentBuffers)
		{
			if (buffer == null)
				continue;

			if (ConstantBuffer parentConstBuffer = buffer as ConstantBuffer)
			{
				using (OverridingConstantBuffer childConstBuffer = new OverridingConstantBuffer(parentConstBuffer))
				{
					_bufferCollection.Add(@bufferName.Index, childConstBuffer.Name, childConstBuffer);
					InitVariables(childConstBuffer);
				}
			}
			else
			{
				Log.EngineLogger.Error("Found buffer in constant buffer collection that is not a constant buffer.");
			}
		}
	}

	/**
	 * Binds the materials Shaders and Parameters to the given context.
	 */
	public void Bind()
	{
		Debug.Profiler.ProfileRendererFunction!();
		
		// TODO: Bind textures, don't go through effect for that
		for(let (name, texture) in _textures)
		{
			switch (texture.Dimension)
			{
			//case .Texture1D, .Texture1DArray:
			case .Texture2D, .Texture2DArray:
				AssetHandle<Texture2D> handle2D = .(texture.Handle);
				_effect.SetTexture(name, handle2D);
			case .TextureCube, .TextureCubeArray:
				AssetHandle<TextureCube> cubeHandle = .(texture.Handle);
				_effect.SetTexture(name, cubeHandle);
			//case .Texture3D:
			default:
				Log.EngineLogger.Error("Tryied to bind undefined texture dimension!");
			}
		}

		for (let (bufferName, buffer) in _bufferCollection)
		{
			if (let cbuffer = buffer as ConstantBuffer)
			{
				TrySilent!(cbuffer.Apply());
			}
		}

		/*for(let (name, variable) in _variables)
		{
			variable.Variable.SetRawData(RawPointer!<uint8>(variable.Offset));
		}*/

		//_effect.ApplyChanges();
		_effect.Bind();

		RenderCommand.BindConstantBuffers(_bufferCollection);
	}

	/** @brief Sets a texture of the material.
	 * @param name The name of the texture to set.
	 * @param texture The texture to bind to the effect.
	 */
	public void SetTexture(String name, AssetHandle<Texture> texture, int32? groupTargetIndex = null)
	{
		if(_textures.TryGetValue(name, var entry))
		{
			_textures[name].Handle = texture;
			_textures[name].groupTarget = groupTargetIndex;
		}
		else
		{
			Log.EngineLogger.Error($"Material doesn't have the texture slot \"{name}\"");
		}
	}

	private mixin SetVariable(StringView name, var value)
	{
		if(_variables.TryGetValue(name, let entry))
		{
			entry.SetData(value);
		}
	}

	public enum SetVariableError
	{
		VariableNotFound,
		ElementTypeMismatch,
		MatrixDimensionMismatch,
		ProvidedBufferTooShort,
	}
	
	internal Result<void, SetVariableError> SetVariableRaw(StringView name, ShaderVariableType elementType, int32 rows, int32 columns, int32 arrayLength, Span<uint8> rawData)
	{
		if(!_variables.TryGetValue(name, let variable))
		{
			return .Err(.VariableNotFound);
		}

		let matchResult = variable.CheckTypematch(rows, columns, elementType);

		switch (matchResult)
		{
		case .Ok:
			// Nothing went wrong.
		case .ElementTypeMismatch:
			return .Err(.ElementTypeMismatch);
		case .MatrixDimensionMismatch:
			return .Err(.MatrixDimensionMismatch);
		}

		if (rawData.Length < variable._sizeInBytes)
			return .Err(.ProvidedBufferTooShort);

		// TODO: This method is very stupid atm.
		// We could e.g. allow array length mismatches by simply copying the smaller amount of elements.
		variable.SetRawData(rawData.Ptr);

		return .Ok;
	}

	public Result<void, SetVariableError> ResetVariable(StringView name)
	{
		if(!_variables.TryGetValue(name, let variable))
		{
			return .Err(.VariableNotFound);
		}

		variable.IsUnset = true;

		return .Ok;
	}

	public void SetVariable(StringView name, bool value) => SetVariable!(name, value);
	public void SetVariable(StringView name, bool2 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, bool3 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, bool4 value) => SetVariable!(name, value);

	public void SetVariable(StringView name, int32 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, int2 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, int3 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, int4 value) => SetVariable!(name, value);

	public void SetVariable(StringView name, uint32 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, uint2 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, uint3 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, uint4 value) => SetVariable!(name, value);

	public void SetVariable(StringView name, float value) => SetVariable!(name, value);
	public void SetVariable(StringView name, float2 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, float3 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, float4 value) => SetVariable!(name, value);

	public void SetVariable(StringView name, Color value) => SetVariable!(name, value);
	public void SetVariable(StringView name, ColorRGB value) => SetVariable!(name, value);
	public void SetVariable(StringView name, ColorRGBA value) => SetVariable!(name, value);

	public void SetVariable(StringView name, Matrix3x3 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, Matrix4x3 value) => SetVariable!(name, value);
	public void SetVariable(StringView name, Matrix value) => SetVariable!(name, value);

	public void GetVariable<T>(StringView name, out T value) where T : struct
	{
		Debug.Profiler.ProfileRendererFunction!();

		if(_variables.TryGetValue(name, let entry))
		{
			entry.EnsureTypeMatch<T>();

			// TODO: This obviously breaks for all cases where a custom SetData was necessary.
			value = *(T*)entry.firstByte;
		}
		else
		{
			value = ?;
			Log.EngineLogger.Assert(false, scope $"The effect doesn't contain a variable named \"{name}\"");
		}
	}
}
