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

	private Dictionary<StringView, BufferVariable> _variables = new .() ~ delete _;

	private TextureCollection _textureCollection ~ delete _;

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
		InitBuffers();
		InitTextures();
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

	private void InitTextures()
	{
		delete _textureCollection;
		_textureCollection = new TextureCollection(_parent?._textureCollection);

		if (_parent == null)
		{
			for(let (name, effectTexture) in _effect.Textures)
			{
				// TODO: We need to be able to define default textures in the shader.
				// At least things like "Black", "White", "Normal"
				// At best whole paths. Shouldn't be that hard to do...
				AssetHandle<Texture> textureHandle = .Invalid;
				int32? groupTarget = null;
	
				if (textureHandle.IsValid)
				{
					if (textureHandle.Dimension != effectTexture.TextureDimension)
						textureHandle = .Invalid;
				}

				int32 textureSlot = -1;

				// TODO: This is a hack, because PsSlot and VsSlot actually break because they are references to dictionary items which sometimes get reallocated...
				// But it is enough for now to detect if the slot exists.
				if (effectTexture.PsSlot != null)
				{
					textureSlot = (.)_effect.PixelShader.Textures[name].Index;
				}
				else if (effectTexture.VsSlot != null)
				{
					textureSlot = (.)_effect.VertexShader.Textures[name].Index;
				}

				Log.EngineLogger.AssertDebug(textureSlot != -1);

				_textureCollection.AddTexture(name, effectTexture.TextureDimension, textureSlot, textureHandle, groupTarget);
			}
		}
		else
		{
			for(let (name, entry) in _parent._textureCollection.[Friend]_entries)
			{
				TextureCollection.TextureFlags flags = .Unset;

				if (entry.Flags.HasFlag(.Locked))
				{
					flags |= .Locked | .Readonly;
				}

				_textureCollection.AddTexture(name, entry.Dimension, entry.TextureSlot, .Invalid, null, flags);
			}
		}
	}

	/**
	 * Binds the materials Shaders and Parameters to the given context.
	 */
	public void Bind()
	{
		Debug.Profiler.ProfileRendererFunction!();
		
		for (let (bufferName, buffer) in _bufferCollection)
		{
			if (let cbuffer = buffer as ConstantBuffer)
			{
				TrySilent!(cbuffer.Apply());
			}
		}

		_effect.Bind();

		RenderCommand.BindConstantBuffers(_bufferCollection);

		_textureCollection.Bind();

	}

	/** @brief Sets a texture of the material.
	 * @param name The name of the texture to set.
	 * @param texture The texture to bind to the effect.
	 */
	public Result<void, TextureCollection.SetTextureError> SetTexture(StringView name, AssetHandle<Texture> texture, int32? groupTargetIndex = null)
	{
		return _textureCollection.SetTexture(name, texture, groupTargetIndex);
	}

	public Result<AssetHandle<Texture>, TextureCollection.SetTextureError> GetTexture(StringView name, out int32? groupTargetIndex)
	{
		return _textureCollection.GetTexture(name, out groupTargetIndex);
	}

	public Result<void, TextureCollection.SetTextureError> ResetTexture(StringView name)
	{
		return _textureCollection.ResetTexture(name);
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

public class TextureCollection
{
	public enum TextureFlags
	{
		None = 0x0,
		/// The texture slot is dirty and needs to be sent do the GPU.
		Dirty = 0x1,
		/// The texture slot is locked, its value cannot be overwritten in child materials.
		Locked = 0x2,
		/// (For inherited textures only) The texture slot doesn't override the value set in the parent material.
		Unset = 0x4,
		/// The texture slots value cannot be changed. (i.e. it is locked in the parent material)
		Readonly = 0x8
	}

	private struct TextureEntry
	{
		public AssetHandle<Texture> TextureHandle;
		public int32? groupTarget;
		public TextureDimension Dimension;
		public TextureFlags Flags;
		public int32 TextureSlot;
	}
	
	protected int _generation = 0;
	protected int _parentGeneration = 0;
	private TextureCollection _parent;

	private Dictionary<String, TextureEntry> _entries = new .() ~ DeleteDictionaryAndKeys!(_);
	
	public enum SetTextureError
	{
		TextureNotFound,
		DimensionMismatch,
		TextureSlotReadonly
	}

	public this(TextureCollection parent = null)
	{
		_parent = parent;
	}

	internal void AddTexture(StringView name, TextureDimension dimension, int32 slot, AssetHandle<Texture> texture, int32? groupTargetIndex = null, TextureFlags flags = .None)
	{
		_entries.Add(new String(name),
			TextureEntry() {
				TextureHandle = texture,
				groupTarget = groupTargetIndex,
				Dimension = dimension,
				TextureSlot = slot,
				Flags = flags
			});
	}

	public Result<void, SetTextureError> SetTexture(StringView name, AssetHandle<Texture> texture, int32? groupTargetIndex = null)
	{
		if (_entries.TryGetRefAlt(name, ?, let entry))
		{
			if (entry.Flags.HasFlag(.Readonly))
			{
				return .Err(.TextureSlotReadonly);
			}

			Texture textureAsset = texture.Get();

			if (textureAsset != null && textureAsset.Dimension != entry.Dimension)
			{
				return .Err(.DimensionMismatch);
			}

			entry.TextureHandle = texture;

			// TODO: Assert group target index
			// We have to figure out how to properly use/pass them anyway

			entry.groupTarget = groupTargetIndex;

			Enum.ClearFlag(ref entry.Flags, .Unset);
			Enum.SetFlag(ref entry.Flags, .Dirty);

			return .Ok;
		}

		return .Err(.TextureNotFound);
	}

	public Result<AssetHandle<Texture>, SetTextureError> GetTexture(StringView name, out int32? groupTargetIndex)
	{
		if (_entries.TryGetRefAlt(name, ?, let entry))
		{
			if (entry.Flags.HasFlag(.Unset) && _parent != null)
			{
				return _parent.GetTexture(name, out groupTargetIndex);
			}

			groupTargetIndex = entry.groupTarget;

			return entry.TextureHandle;
		}

		groupTargetIndex = -1;

		return .Err(.TextureNotFound);
	}

	public Result<void, SetTextureError> ResetTexture(StringView name)
	{
		if (_entries.TryGetRefAlt(name, ?, let entry))
		{
			if (entry.Flags.HasFlag(.Readonly))
			{
				return .Err(.TextureSlotReadonly);
			}

			entry.TextureHandle = .Invalid;
			entry.groupTarget = null;

			Enum.SetFlag(ref entry.Flags, .Unset | .Dirty);

			return .Ok;
		}

		return .Err(.TextureNotFound);
	}

	public void Bind()
	{
		for (var (name, entry) in _entries)
		{
			AssetHandle<Texture> handle = entry.TextureHandle;
			TextureCollection parentCollection = _parent;
			TextureFlags flags = entry.Flags;

			// If necessary, look for a texture in the parent collection
			while (flags.HasFlag(.Unset) && parentCollection != null)
			{
				TextureEntry parentEntry = parentCollection._entries[name];
				handle = parentEntry.TextureHandle;
				parentCollection = parentCollection._parent;
				flags = parentEntry.Flags;
			}

			Texture texture = handle.Get();

			using (let viewBinding = texture?.GetViewBinding())
			{
				RenderCommand.BindTexture(viewBinding, entry.TextureSlot, .All);
			}
		}
	}

	protected extern Result<void> SetTexturePlatform();
}