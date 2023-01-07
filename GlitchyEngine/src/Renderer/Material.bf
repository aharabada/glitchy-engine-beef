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

	private Dictionary<String, TextureViewBinding> _textures = new .();

	private Dictionary<String, (uint32 Offset, BufferVariable Variable)> _variables = new .() ~ delete _;

	public Effect Effect => _effect;

	public this(Effect effect)
	{
		_effect = effect..AddRef();

		// TODO: get variables from effect

		for(let (name, entry) in _effect.Textures)
		{
			var texture = entry.BoundTexture;
			texture.AddRef();

			_textures.Add(name, texture);
		}

		InitRawData();
	}

	public ~this()
	{
		for(let (name, texture) in _textures)
		{
			texture.Release();
		}

		delete _textures;
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
			_effect.SetTexture(name, texture);
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
	public void SetTexture(String name, Texture texture)
	{
		if(_textures.TryGetValue(name, var entry))
		{
			entry.Release();
			_textures[name] = texture.GetViewBinding();
			//texture?.AddRef();
		}
		else
		{
			Log.EngineLogger.Assert(false);
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

	public void SetVariable(String name, float value) => SetVariable<float>(name, value);
	public void SetVariable(String name, Vector2 value) => SetVariable<Vector2>(name, value);
	public void SetVariable(String name, Vector3 value) => SetVariable<Vector3>(name, value);
	public void SetVariable(String name, Vector4 value) => SetVariable<Vector4>(name, value);
	
	public void SetVariable(String name, int32 value) => SetVariable<int32>(name, value);
	public void SetVariable(String name, Int2 value) => SetVariable<Int2>(name, value);
	public void SetVariable(String name, Int3 value) => SetVariable<Int3>(name, value);
	public void SetVariable(String name, Int4 value) => SetVariable<Int4>(name, value);

	public void SetVariable(String name, uint32 value) => SetVariable<uint32>(name, value);

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
	// Float, Float2, Float3, Float4
	// Color, ColorRGB, ColorRGBA
	// Int, Int2, Int3, Int4
	// UInt
	// Matrix3x3, Matrix4x3, Matrix

	// TODO: Add missing variable types
	// UInt2, UInt3, UInt4
	// Bool, Bool2, Bool3, Bool4
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
