using GlitchyEngine.Content;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using System;
using System.Collections;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer;

public class Material : Asset
{
	private Effect _effect ~ _?.ReleaseRef();

	private uint8[] _rawVariables ~ delete _;

	private Dictionary<String, (AssetHandle<Texture> Handle, TextureDimension Dimension)> _textures = new .() ~ delete _;

	private Dictionary<String, (uint32 Offset, BufferVariable Variable)> _variables = new .() ~ delete _;

	public Effect Effect => _effect;

	public this(Effect effect)
	{
		_effect = effect..AddRef();

		// TODO: get variables from effect

		// Get texture slots from effect
		for(let (name, entry) in _effect.Textures)
		{
			// TODO: We need to be able to define default textures in the shader.
			// At least things like "Black", "White", "Normal"
			// At best whole paths. Shouldn't be that hard to do...
			/*var texture = entry.BoundTexture;*/

			_textures.Add(name, (AssetHandle<Texture>.Invalid, entry.TextureDimension));
		}

		InitRawData();
	}


	/** @brief Initializes the raw data array for the variables.
	 */
	private void InitRawData()
	{
		uint32 bufferSize = 0;

		for(let variable in _effect.Variables)
		{
			_variables.Add(variable.Name, (bufferSize, variable));

			bufferSize += variable._sizeInBytes;
		}

		_rawVariables = new uint8[bufferSize];
	}

	/**
	 * Binds the materials Shaders and Parameters to the given context.
	 */
	public void Bind()
	{
		Debug.Profiler.ProfileRendererFunction!();

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

		for(let (name, variable) in _variables)
		{
			variable.Variable.SetRawData(RawPointer!<uint8>(variable.Offset));
		}

		_effect.ApplyChanges();
		_effect.Bind();
	}

	/** @brief Sets a texture of the material.
	 * @param name The name of the texture to set.
	 * @param texture The texture to bind to the effect.
	 */
	public void SetTexture(String name, AssetHandle<Texture> texture)
	{
		if(_textures.TryGetValue(name, var entry))
		{
			/*switch (texture.Get().GetType())
			{
			//case .Texture1D:
			//	_textures[name].Dimension = .Texture1D;
			case typeof(Texture2D):
				_textures[name].Dimension = .Texture2D;
			case typeof(TextureCube):
				_textures[name].Dimension = .TextureCube;
			//case .Texture3D:
			//	_textures[name].Dimension = .Texture3D;
			default:
				_textures[name].Dimension = .Unknown;
			}*/
			//entry?.ReleaseRef();
			_textures[name].Handle = texture;
			//texture?.AddRef();
		}
		else
		{
			Log.EngineLogger.Error($"Material doesn't have the texture slot \"{name}\"");
			//Log.EngineLogger.Assert(false);
		}
	}

	private mixin RawPointer<T>(uint32 offset)
	{
		(T*)(&_rawVariables[offset])
	}

	[Inline]
	private void SetVariable<T>(String name, T value) where T : struct
	{
		Debug.Profiler.ProfileRendererFunction!();

		if(_variables.TryGetValue(name, let entry))
		{
			entry.Variable.EnsureTypeMatch<T>();
			
			*RawPointer!<T>(entry.Offset) = value;
		}
		else
		{
			Log.EngineLogger.Assert(false, scope $"The effect doesn't contain a variable named \"{name}\"");
		}
	}

	public void SetVariable(String name, bool value) => SetVariable<bool>(name, value);
	public void SetVariable(String name, bool2 value) => SetVariable<bool2>(name, value);
	public void SetVariable(String name, bool3 value) => SetVariable<bool3>(name, value);
	public void SetVariable(String name, bool4 value) => SetVariable<bool4>(name, value);
	
	public void SetVariable(String name, int32 value) => SetVariable<int32>(name, value);
	public void SetVariable(String name, int2 value) => SetVariable<int2>(name, value);
	public void SetVariable(String name, int3 value) => SetVariable<int3>(name, value);
	public void SetVariable(String name, int4 value) => SetVariable<int4>(name, value);

	public void SetVariable(String name, uint32 value) => SetVariable<uint32>(name, value);
	public void SetVariable(String name, uint2 value) => SetVariable<uint2>(name, value);
	public void SetVariable(String name, uint3 value) => SetVariable<uint3>(name, value);
	public void SetVariable(String name, uint4 value) => SetVariable<uint4>(name, value);

	public void SetVariable(String name, float value) => SetVariable<float>(name, value);
	public void SetVariable(String name, float2 value) => SetVariable<float2>(name, value);
	public void SetVariable(String name, float3 value) => SetVariable<float3>(name, value);
	public void SetVariable(String name, float4 value) => SetVariable<float4>(name, value);

	/*public void SetVariable(String name, float value) => SetVariable<double>(name, value);
	public void SetVariable(String name, float2 value) => SetVariable<float2>(name, value);
	public void SetVariable(String name, float3 value) => SetVariable<float3>(name, value);
	public void SetVariable(String name, float4 value) => SetVariable<float4>(name, value);*/

	public void SetVariable(String name, Color value) => SetVariable<ColorRGBA>(name, (ColorRGBA)value);
	public void SetVariable(String name, ColorRGB value) => SetVariable<ColorRGB>(name, value);
	public void SetVariable(String name, ColorRGBA value) => SetVariable<ColorRGBA>(name, value);

	public void SetVariable(String name, Matrix3x3 value)
	{
		if(_variables.TryGetValue(name, let entry))
		{
			entry.Variable.EnsureTypeMatch<Matrix3x3>();
			
			// TODO: I'm not sure how to handle Matrix3x3
			// It seems to be 44 Bytes (11 Floats) large.
			Log.EngineLogger.AssertDebug(entry.Variable._sizeInBytes == 44, "Made wrong assumption about the size of float3x3 in a hlsl constant-buffer.");

#unwarn
			*RawPointer!<float[11]>(entry.Offset) = *(float[11]*)&Matrix4x3(value);
		}
		else
		{
			Log.EngineLogger.Assert(false, scope $"The effect doesn't contain a variable named \"{name}\"");
		}
	}
	
	public void SetVariable(String name, Matrix3x3[] values)
	{
		if(_variables.TryGetValue(name, let entry))
		{
			entry.Variable.EnsureTypeMatch<Matrix3x3>();

			int count = Math.Min(values.Count, entry.Variable._elements);

			for(int i < count)
			{
				(RawPointer!<Matrix4x3>(entry.Offset))[i] = Matrix4x3(values[i]);
			}
		}
		else
		{
			Log.EngineLogger.Assert(false, scope $"The effect doesn't contain a variable named \"{name}\"");
		}
	}

	public void SetVariable(String name, Matrix4x3 value) => SetVariable<Matrix4x3>(name, value);
	public void SetVariable(String name, Matrix value) => SetVariable<Matrix>(name, value);

	public void SetVariable(String name, Matrix[] values)
	{
		if(_variables.TryGetValue(name, let entry))
		{
			entry.Variable.EnsureTypeMatch<Matrix>();

			Internal.MemCpy(RawPointer!<Matrix>(entry.Offset), values.Ptr, sizeof(Matrix) * Math.Min(values.Count, entry.Variable._elements));
		}
		else
		{
			Log.EngineLogger.Assert(false, scope $"The effect doesn't contain a variable named \"{name}\"");
		}
	}

	// Supporeted types
	// Bool, Bool2, Bool3, Bool4
	// Int, int2, int3, int4
	// UInt, UInt2, UInt3, UInt4
	// Color, ColorRGB, ColorRGBA
	// Float, Float2, Float3, Float4
	// Matrix3x3, Matrix4x3, Matrix

	// TODO: Add missing variable types
	// Half, Half2, Half3, Half4
	// Byte, Byte2, Byte3, Byte4

	/**
	 * Sets the raw data of the variable.
	 * @param rawData The pointer to the raw data. If rawData is null the raw data will be set to zero.
	 */
	internal void SetRawData(uint32 offset, void* rawData, uint32 byteCount)
	{
		if(rawData != null)
			Internal.MemCpy(&_rawVariables + offset, rawData, byteCount);
		else
			Internal.MemSet(&_rawVariables + offset, 0, byteCount);
	}

	public void GetVariable<T>(String name, out T value) where T : struct
	{
		Debug.Profiler.ProfileRendererFunction!();

		if(_variables.TryGetValue(name, let entry))
		{
			entry.Variable.EnsureTypeMatch<T>();
			
			value = *RawPointer!<T>(entry.Offset);
		}
		else
		{
			value = ?;
			Log.EngineLogger.Assert(false, scope $"The effect doesn't contain a variable named \"{name}\"");
		}
	}
}
