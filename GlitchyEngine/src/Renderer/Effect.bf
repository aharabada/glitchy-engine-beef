using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer;

public class Effect : Asset
{
	internal VertexShader _vs ~ _?.ReleaseRef();
	internal PixelShader _ps ~ _?.ReleaseRef();

	BufferCollection _bufferCollection ~ _.ReleaseRef();

	BufferVariableCollection _variables ~ delete _;

	public struct TextureEntry
	{
		public TextureViewBinding BoundTexture;
		public TextureDimension TextureDimension;
		public ShaderTextureCollection.ResourceEntry* VsSlot;
		public ShaderTextureCollection.ResourceEntry* PsSlot;

		public this(TextureViewBinding boundTexture, TextureDimension textureDimension, ShaderTextureCollection.ResourceEntry* vsSlot, ShaderTextureCollection.ResourceEntry* psSlot)
		{
			BoundTexture = boundTexture;
			VsSlot = vsSlot;
			PsSlot = psSlot;
			TextureDimension = textureDimension;
		}
	}

	Dictionary<String, TextureEntry> _textures ~ DeleteDictionaryAndKeys!(_);

	public Dictionary<String, TextureEntry> Textures => _textures;

	public VertexShader VertexShader
	{
		get => _vs;
		private set => SetReference!(_vs, value);
	}
	
	public PixelShader PixelShader
	{
		get => _ps;
		private set => SetReference!(_ps, value);
	}

	public BufferCollection Buffers => _bufferCollection;
	public BufferVariableCollection Variables => _variables;

	public this()
	{
		_bufferCollection = new BufferCollection();
		_variables = new BufferVariableCollection(false);
		_textures = new Dictionary<String, TextureEntry>();
	}

	public ~this()
	{
		Debug.Profiler.ProfileResourceFunction!();

		for(let entry in _textures)
		{
			entry.value.BoundTexture.ReleaseRef();
		}
	}

	public void SetTexture(String name, Texture texture)
	{
		Debug.Profiler.ProfileRendererFunction!();

		if (texture == null)
			return;

		[Inline]InternalSetTexture(name, texture.GetViewBinding());
	}
	
	public void SetTexture(String name, RenderTargetGroup renderTargetGroup, int32 firstTarget, uint32 targetCount = 1)
	{
		Debug.Profiler.ProfileRendererFunction!();

		if (targetCount != 1)
			Runtime.NotImplemented("Binding multiple rendertargets to a slot is not yet implemented.");

		// We have to release the viewBinding because GetViewBinding internally increases the counter
		[Inline]InternalSetTexture(name, renderTargetGroup.GetViewBinding(firstTarget));
	}

	public void SetTexture(String name, TextureViewBinding textureViewBinding)
	{
		Debug.Profiler.ProfileRendererFunction!();

		[Inline]InternalSetTexture(name, textureViewBinding);
	}

	private void InternalSetTexture(String name, TextureViewBinding textureViewBinding)
	{
		Debug.Profiler.ProfileRendererFunction!();

		ref TextureEntry entry = ref _textures[name];

		// TODO: Thats weird, we increment this reference somewhere... but WHERE?!
		entry.BoundTexture.ReleaseRef();
		entry.BoundTexture = textureViewBinding;

		if (entry.VsSlot != null)
			SetReference!(VertexShader.Textures[name].BoundTexture, entry.BoundTexture);

		if (entry.PsSlot != null)
			SetReference!(PixelShader.Textures[name].BoundTexture, entry.BoundTexture);
	}

	public void ApplyChanges()
	{
		Debug.Profiler.ProfileRendererFunction!();
		
		//ApplyTextures();

		for(let buffer in _bufferCollection)
		{
			if(let cbuffer = buffer.Buffer as ConstantBuffer)
			{
				cbuffer.Update();
			}
		}
	}

	public void Bind()
	{
		Debug.Profiler.ProfileRendererFunction!();

		//ApplyTextures();
		//ApplyChanges();

		RenderCommand.BindVertexShader(_vs);
		RenderCommand.BindPixelShader(_ps);
	}

	// Stuff I'm not sure about

	typealias VariableDesc = Dictionary<String, Dictionary<String, Variant>>;

	protected VariableDesc _variableDescriptions = new .() ~ {
		for (var (key, value) in _)
		{
			delete key;

			for (var (entryKey, entry) in value)
			{
				delete entryKey;
				entry.Dispose();
			}

			delete value;
		}

		delete _;
	};
}
