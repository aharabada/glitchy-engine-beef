using System;
using GlitchyEngine.Math;
namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	public enum VariableFlags
	{
		None = 0x00,
		/// The variable is dirty and needs to be sent do the GPU.
		Dirty = 0x01,
		/// The variable is locked, its value cannot be overwritten in child buffers.
		Locked = 0x02,
		/// The variable is used in the shader. Conversely, this means that the variable is unused.
		Used = 0x04,
		/// (For inherited variables only) The variable doesn't override the value set in the parent buffer.
		Unset = 0x08,
		/// The variables value cannot be changed. (i.e. it is locked in the parent buffer)
		Readonly = 0x10
	}

	public class BufferVariable
	{
		private ConstantBuffer _constantBuffer;

		private String _name ~ delete _;
		protected String _previewName ~ delete _;
		protected String _editorTypeName ~ delete _;

		private ShaderVariableType _elementType;

		internal uint32 _columns;
		internal uint32 _rows;
		private uint32 _offset;
		internal uint32 _sizeInBytes;
		// Number of elements in the array
		internal uint32 _arrayElements;

		private VariableFlags _flags;

		public ConstantBuffer ConstantBuffer => _constantBuffer;

		public ShaderVariableType ElementType => _elementType;

		public String Name => _name;
		public StringView PreviewName => _previewName;
		public StringView EditorTypeName => _editorTypeName;

		public bool IsUsed => _flags.HasFlag(.Used);

		public uint32 Columns => _columns;
		public uint32 Rows => _rows;
		public uint32 ArrayElements => _arrayElements;

		public uint32 Offset => _offset;

		public bool IsDirty => _flags.HasFlag(.Dirty);
		public bool IsLocked => _flags.HasFlag(.Locked);

		/// Only applies to variables of child buffers. If true, the variable is unset and
		/// it's value will come from the parent buffer.
		/// Note: Setting IsUnset to true will only have a guaranteed effect on the value stored in this BufferVariable once Apply has been called on the constant buffer.
		public bool IsUnset
		{
			get => _flags.HasFlag(.Unset);
			set => Enum.SetFlagConditionally(ref _flags, .Unset, value);
		}

		public VariableFlags Flags => _flags;

		/**
		 * Gets a pointer to the start of the variable in the constant buffers backing data.
		 */
		[Inline]
		internal uint8* firstByte => _constantBuffer.rawData.CArray() + _offset;

		public this(StringView name, ConstantBuffer constantBuffer, ShaderVariableType type, uint32 columns, uint32 rows, uint32 offset, uint32 sizeInBytes, uint32 arrayElements, bool isUsed, StringView previewName, StringView editorTypeName)
		{
			_name = new String(name);
			_previewName = new String(previewName);
			_editorTypeName = new String(editorTypeName);
			_constantBuffer = constantBuffer; // Only hold a weak reference. This variable has to die with the buffer
			_elementType = type;
			_columns = columns;
			_rows = rows;
			_offset = offset;
			_sizeInBytes = sizeInBytes;
			_arrayElements = arrayElements;

			_flags = .None;

			Enum.SetFlagConditionally(ref _flags, .Used, isUsed);
			Enum.SetFlag(ref _flags, .Dirty);
			//Enum.SetFlag(ref _flags, .Locked);
		}

		public void EnsureTypeMatch(int rows, int cols, ShaderVariableType type)
		{
			Debug.Profiler.ProfileRendererFunction!();

#if GE_SHADER_MATRIX_MISMATCH_IS_ERROR
			if (rows != _rows || cols != _columns)
				Log.EngineLogger.Assert(false, scope $"The matrix-dimensions do not match: Expected {_rows} rows and {_rows} columns but Received {rows} rows and {cols} columns instead. Variable: \"{_name}\" of buffer: \"{_constantBuffer.Name}\"");
#elif GE_SHADER_MATRIX_MISMATCH_IS_WARNING
			if (rows != _rows || cols != _columns)
	   			Log.EngineLogger.Warning($"The matrix-dimensions do not match: Expected {_rows} rows and {_rows} columns but Received {rows} rows and {cols} columns instead. Variable: \"{_name}\" of buffer: \"{_constantBuffer.Name}\"");
#endif

#if GE_SHADER_VAR_TYPE_MISMATCH_IS_ERROR
			if (type != _elementType)
				Log.EngineLogger.Assert(false, scope $"The types do not match: Expected \"{_elementType}\" but Received \"{type}\" instead. Variable: \"{_name}\" of buffer: \"{_constantBuffer.Name}\"");
#elif GE_SHADER_VAR_TYPE_MISMATCH_IS_WARNING
			if (type != _type)
	   			Log.EngineLogger.Warning($"The types do not match: Expected \"{_type}\" but Received \"{type}\" instead. Variable: \"{_name}\" of buffer: \"{_constantBuffer.Name}\"");
#endif
		}

		public enum TypematchResult
		{
			Ok,
			MatrixDimensionMismatch,
			ElementTypeMismatch,
		}

		public TypematchResult CheckTypematch(int rows, int cols, ShaderVariableType type)
		{
			Debug.Profiler.ProfileRendererFunction!();

			if (rows != _rows || cols != _columns)
				return .MatrixDimensionMismatch;

			if (type != _elementType)
				return .ElementTypeMismatch;

			return .Ok;
		}

		public void EnsureTypeMatch<T>()
		{
			switch(typeof(T))
			{
			case typeof(bool):
				EnsureTypeMatch(1, 1, .Bool);
			case typeof(bool2):
				EnsureTypeMatch(1, 2, .Bool);
			case typeof(bool3):
				EnsureTypeMatch(1, 3, .Bool);
			case typeof(bool4):
				EnsureTypeMatch(1, 4, .Bool);
				
			case typeof(int32):
				EnsureTypeMatch(1, 1, .Int);
			case typeof(int2):
				EnsureTypeMatch(1, 2, .Int);
			case typeof(int3):
				EnsureTypeMatch(1, 3, .Int);
			case typeof(int4):
				EnsureTypeMatch(1, 4, .Int);

			case typeof(uint32):
				EnsureTypeMatch(1, 1, .UInt);
			case typeof(uint2):
				EnsureTypeMatch(1, 2, .UInt);
			case typeof(uint3):
				EnsureTypeMatch(1, 3, .UInt);
			case typeof(uint4):
				EnsureTypeMatch(1, 4, .UInt);
			
			case typeof(float):
				EnsureTypeMatch(1, 1, .Float);
			case typeof(float2):
				EnsureTypeMatch(1, 2, .Float);
			case typeof(float3):
				EnsureTypeMatch(1, 3, .Float);
			case typeof(float4):
				EnsureTypeMatch(1, 4, .Float);
				
			case typeof(Matrix4x3):
				EnsureTypeMatch(4, 3, .Float);
			case typeof(Matrix3x3):
				EnsureTypeMatch(3, 3, .Float);
			case typeof(Matrix):
				EnsureTypeMatch(4, 4, .Float);

			case typeof(ColorRGB):
				EnsureTypeMatch(1, 3, .Float);
			case typeof(ColorRGBA):
				EnsureTypeMatch(1, 4, .Float);
			case typeof(Color):
				EnsureTypeMatch(1, 4, .Float);
			}
		}
		
		enum SetDataError
		{
			VariableNotFound,
			TypeMismatch
		}

		[Inline]
		private void SetData<T>(T value)
		{
			EnsureTypeMatch<T>();

			_flags |= .Dirty;
			Enum.ClearFlag(ref _flags, .Unset);

			*(T*)firstByte = value;
		}
		
		[Inline]
		private T GetData<T>()
		{
			return *(T*)firstByte;
		}

		public void SetData(bool value) => SetData<bool>(value);
		public void SetData(bool2 value) => SetData<bool2>(value);
		public void SetData(bool3 value) => SetData<bool3>(value);
		public void SetData(bool4 value) => SetData<bool4>(value);
		
		public void SetData(int32 value) => SetData<int32>(value);
		public void SetData(int2 value) => SetData<int2>(value);
		public void SetData(int3 value) => SetData<int3>(value);
		public void SetData(int4 value) => SetData<int4>(value);

		public void SetData(uint32 value) => SetData<uint32>(value);
		public void SetData(uint2 value) => SetData<uint2>(value);
		public void SetData(uint3 value) => SetData<uint3>(value);
		public void SetData(uint4 value) => SetData<uint4>(value);

		public void SetData(float value) => SetData<float>(value);
		public void SetData(float2 value) => SetData<float2>(value);
		public void SetData(float3 value) => SetData<float3>(value);
		public void SetData(float4 value) => SetData<float4>(value);

		public void SetData(ColorRGB value) => SetData<ColorRGB>(value);
		public void SetData(ColorRGBA value) => SetData<ColorRGBA>(value);
		public void SetData(Color value) => SetData<ColorRGBA>((ColorRGBA)value);

		public void SetData(Matrix4x3 value) => SetData<Matrix4x3>(value);

		public void SetData(Matrix4x3[] value)
		{
			EnsureTypeMatch<Matrix4x3>();

			_flags |= .Dirty;
			Enum.ClearFlag(ref _flags, .Unset);

			// TODO: assert length

			Internal.MemCpy(firstByte, value.Ptr, sizeof(Matrix4x3) * Math.Min(value.Count, _arrayElements));
		}

		public void SetData(Matrix3x3 value)
		{
			EnsureTypeMatch<Matrix3x3>();	
   			
			_flags |= .Dirty;
			Enum.ClearFlag(ref _flags, .Unset);

			// TODO: D3D uses 16 Byte rows, smaller rows are padded.
			// OpenGL and Vulkan do this by default, too. However they support compact buffers,
			// if we want to support that we need to handle it here somehow (simple size check?).
			*(Matrix4x3*)firstByte = Matrix4x3(value);
		}

		public void SetData(Matrix3x3[] value)
		{
			EnsureTypeMatch<Matrix3x3>();	 
   
			_flags |= .Dirty;
			Enum.ClearFlag(ref _flags, .Unset);

			// TODO: assert length

			for(int i < Math.Min(value.Count, _arrayElements))
			{
				((Matrix4x3*)firstByte)[i] = Matrix4x3(value[i]);
			}
		}
		
		public void SetData(Matrix value) => SetData<Matrix>(value);

		public void SetData(Matrix[] value)
		{
			EnsureTypeMatch<Matrix>();	   
   
			_flags |= .Dirty;
			Enum.ClearFlag(ref _flags, .Unset);

			// TODO: assert length

			Internal.MemCpy(firstByte, value.Ptr, sizeof(Matrix) * Math.Min(value.Count, _arrayElements));
		}

		// Todo: add all the other SetData-Methods

		/**
		 * Sets the raw data of the variable.
		 * @param rawData The pointer to the raw data. If rawData is null the raw data will be set to zero.
		 */
		internal void SetRawData(void* rawData)
		{
#if GE_SHADER_UNUSED_VARIABLE_IS_ERROR
			Log.EngineLogger.Assert(_isUsed, scope $"Setting data for unused Variable \"{_name}\" of constant buffer \"{_constantBuffer.Name}\".");
#elif GE_SHADER_UNUSED_VARIABLE_IS_WARNING
			if(!_flags.HasFlag(.Used))
			{
				Log.EngineLogger.Warning($"Setting data for unused Variable \"{_name}\" of constant buffer \"{_constantBuffer.Name}\".");
			}
#endif			  
   
			_flags |= .Dirty;
			Enum.ClearFlag(ref _flags, .Unset);

			if(rawData != null)
				Internal.MemCpy(firstByte, rawData, _sizeInBytes);
			else
				Internal.MemSet(firstByte, 0, _sizeInBytes);
		}
	}
}
