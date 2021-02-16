using System;
using GlitchyEngine.Math;
namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	public class BufferVariable
	{
		private ConstantBuffer _constantBuffer;

		private String _name ~ delete _;

		private ShaderVariableType _type;

		private uint32 _columns;
		private uint32 _rows;
		private uint32 _offset;
		private uint32 _sizeInBytes;

		private bool _isUsed;

		public ConstantBuffer ConstantBuffer => _constantBuffer;

		public ShaderVariableType Type => _type;

		public String Name => _name;

		/**
		 * Gets a pointer to the start of the variable in the constant buffers backing data.
		 */
		[Inline]
		internal uint8* firstByte => _constantBuffer.rawData.CArray() + _offset;

		public this(ConstantBuffer constantBuffer, ShaderVariableType type, uint32 columns, uint32 rows, uint32 offset, uint32 sizeInBytes, bool isUsed)
		{
			_constantBuffer = constantBuffer..AddRef();
			_type = type;
			_columns = columns;
			_rows = rows;
			_offset = offset;
			_sizeInBytes = sizeInBytes;
			_isUsed = isUsed;
		}

		public void EnsureTypeMatch(int rows, int cols, ShaderVariableType type)
		{
#if GE_ERROR_SHADER_MATRIX_MISMATCH
	   		Log.EngineLogger.Assert(rows == _rows || cols == _columns, scope $"The matrix-dimensions do not match: Expected {_rows} rows and {_rows} columns but Received {rows} rows and {cols} columns instead. Variable: \"{_name}\" of buffer: \"{_constantBuffer.Name}\"");
#elif GE_WARN_SHADER_MATRIX_MISMATCH
			if (rows != _rows || cols != _columns)
	   			Log.EngineLogger.Warning($"The matrix-dimensions do not match: Expected {_rows} rows and {_rows} columns but Received {rows} rows and {cols} columns instead. Variable: \"{_name}\" of buffer: \"{_constantBuffer.Name}\"");
#endif

#if GE_ERROR_SHADER_VAR_TYPE_MISMATCH
	   		Log.EngineLogger.Assert(type == _type, scope $"The types do not match: Expected \"{_type}\" but Received \"{type}\" instead. Variable: \"{_name}\" of buffer: \"{_constantBuffer.Name}\"");
#elif GE_WARN_SHADER_VAR_TYPE_MISMATCH
			if (type != _type)
	   			Log.EngineLogger.Warning($"The types do not match: Expected \"{_type}\" but Received \"{type}\" instead. Variable: \"{_name}\" of buffer: \"{_constantBuffer.Name}\"");
#endif
		}

		public void SetData(float value)
		{
			EnsureTypeMatch(1, 1, .Float);

			*(float*)firstByte = value;
		}

		public void SetData(Vector2 value)
		{
			EnsureTypeMatch(1, 2, .Float);
			
			*(Vector2*)firstByte = value;
		}

		public void SetData(Vector3 value)
		{
			EnsureTypeMatch(1, 3, .Float);
			
			*(Vector3*)firstByte = value;
		}

		public void SetData(Vector4 value)
		{
			EnsureTypeMatch(1, 4, .Float);
			
			*(Vector4*)firstByte = value;
		}

		public void SetData(Matrix4x3 value)
		{
			// I think this is right
			EnsureTypeMatch(4, 3, .Float);

			*(Matrix4x3*)firstByte = value;
		}

		public void SetData(Matrix3x3 value)
		{
			EnsureTypeMatch(3, 3, .Float);

			*(Matrix4x3*)firstByte = Matrix4x3(value);
			
			// Todo: maybe manual copy
		}
		
		public void SetData(Matrix value)
		{
			EnsureTypeMatch(4, 4, .Float);

			*(Matrix*)firstByte = value;
		}
		
		public void SetData(ColorRGB value)
		{
			EnsureTypeMatch(1, 3, .Float);

			*(ColorRGB*)firstByte = value;
		}

		public void SetData(ColorRGBA value)
		{
			EnsureTypeMatch(1, 4, .Float);

			*(ColorRGBA*)firstByte = value;
		}

		public void SetData(Color value)
		{
			EnsureTypeMatch(1, 4, .Float);

			*(ColorRGBA*)firstByte = (ColorRGBA)value;
		}

		// Todo: add all the other SetData-Methods

		/**
		 * Sets the raw data of the variable.
		 * @param rawData The pointer to the raw data. If rawData is null the raw data will be set to zero.
		 */
		internal void SetRawData(void* rawData)
		{
#if DEBUG && !GE_IGNORE_UNUSED_VARIABLE
			if(!_isUsed)
			{
				Log.EngineLogger.Warning($"Setting data for unused Variable \"{_name}\" of constant buffer \"{_constantBuffer.Name}\".");
			}
#endif

			if(rawData != null)
				Internal.MemCpy(firstByte, rawData, _sizeInBytes);
			else
				Internal.MemSet(firstByte, 0, _sizeInBytes);
		}
	}
}
