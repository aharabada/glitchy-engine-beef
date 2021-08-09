using System;
using System.Collections;
using GlitchyEngine.Math;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	public class Material : RefCounted
	{
		private Effect _effect ~ _?.ReleaseRef();

		private uint8[] _rawVariables ~ delete _;

		private Dictionary<String, Texture> _textures = new .();

		private Dictionary<String, (uint32 Offset, BufferVariable Variable)> _variables = new .() ~ delete _;

		public Effect Effect => _effect;

		public this(Effect effect)
		{
			_effect = effect..AddRef();

			// TODO: get variables from effect

			for(let (name, entry) in _effect.Textures)
			{
				var texture = entry.Texture;
				texture?.AddRef();

				_textures.Add(name, texture);
			}

			InitRawData();
		}

		public ~this()
		{
			for(let (name, texture) in _textures)
			{
				texture?.ReleaseRef();
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
		public void Bind(GraphicsContext context)
		{
			for(let (name, texture) in _textures)
			{
				_effect.SetTexture(name, texture);
			}

			for(let (name, variable) in _variables)
			{
				variable.Variable.SetRawData(&RawPointer!<uint8>(variable.Offset));
			}

			_effect.Bind(context);
		}

		/** @brief Sets a texture of the material.
		 * @param name The name of the texture to set.
		 * @param texture The texture to bind to the effect.
		 */
		public void SetTexture(String name, Texture texture)
		{
			if(_textures.TryGetValue(name, var entry))
			{
				entry?.ReleaseRef();
				_textures[name] = texture;
				texture?.AddRef();
			}
			else
			{
				Log.EngineLogger.Assert(false);
			}
		}

		private mixin RawPointer<T>(uint32 offset)
		{
			*(T*)(&_rawVariables[offset])
		}

		public void SetVariable(String name, float value)
		{
			if(_variables.TryGetValue(name, let entry))
			{
				entry.Variable.EnsureTypeMatch(1, 1, .Float);

				RawPointer!<float>(entry.Offset) = value;
			}
			else
			{
				Log.EngineLogger.Assert(false, scope $"The effect doesn't contain a variable named \"{name}\"");
			}
		}
		
		public void SetVariable(String name, Color value)
		{
			if(_variables.TryGetValue(name, let entry))
			{
				entry.Variable.EnsureTypeMatch<Color>();

				RawPointer!<ColorRGBA>(entry.Offset) = (ColorRGBA)value;
			}
			else
			{
				Log.EngineLogger.Assert(false, scope $"The effect doesn't contain a variable named \"{name}\"");
			}
		}
		
		public void SetVariable(String name, Matrix value)
		{
			if(_variables.TryGetValue(name, let entry))
			{
				entry.Variable.EnsureTypeMatch<Matrix>();

				RawPointer!<Matrix>(entry.Offset) = value;
			}
			else
			{
				Log.EngineLogger.Assert(false, scope $"The effect doesn't contain a variable named \"{name}\"");
			}
		}

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

		// public void Set(String name, VALUE)...

		// Float, Float2, Float3, Float4
		// Color, ColorRGB, ColorRGBA
		// Matrix3x3, Matrix4x3, Matrix
		// Int, Int2, Int3, Int4
		// UInt, UInt2, UInt3, UInt4
		// Bool, Bool2, Bool3, Bool4
		// Half, Half2, Half3, Half4
		// Byte, Byte2, Byte3, Byte4
	}
}
