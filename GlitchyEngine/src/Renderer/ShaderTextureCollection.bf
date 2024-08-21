using System;
using System.Collections;

namespace GlitchyEngine.Renderer
{
	public class ShaderTextureCollection : IEnumerable<(String Name, uint32 Index, TextureViewBinding BoundTexture, TextureDimension Dimension)>
	{
		public typealias ResourceEntry = (String Name, uint32 Index, TextureViewBinding BoundTexture, TextureDimension Dimension);

		List<ResourceEntry> _textures ~ DeleteTextureEntries!(_);
		
		Dictionary<String, ResourceEntry*> _strToBuf ~ delete _;
		Dictionary<int, ResourceEntry*> _idxToBuf ~ delete _;

		public this()
		{
			let textures = new List<ResourceEntry>();
			let strToBuf = new Dictionary<String, ResourceEntry*>();
			let idxToBuf = new Dictionary<int, ResourceEntry*>();

			_textures = textures;
			_strToBuf = strToBuf;
			_idxToBuf = idxToBuf;
		}

		mixin DeleteTextureEntries(List<ResourceEntry> entries)
		{
			if(entries == null)
				return;

			for(let entry in entries)
			{
				delete entry.Name;
				entry.BoundTexture.Release();
			}

			delete entries;
		}

		// TODO: finish implementation (like BufferCollection)
		public ResourceEntry* this[int idx] => _idxToBuf[idx];
		public ResourceEntry* this[String name] => _strToBuf[name];

		public void Add(String name, uint32 index, TextureViewBinding texture, TextureDimension dimension)
		{
			Add((name, index, texture, dimension));
		}

		public void Add(ResourceEntry entry)
		{
			ResourceEntry copy = (new String(entry.Name), entry.Index, entry.BoundTexture, entry.Dimension);
			entry.BoundTexture.AddRef();

			_textures.Add(copy);

			ResourceEntry* copyRef = &_textures.Back;

			_strToBuf.Add(copy.Name, copyRef);
			_idxToBuf.Add(copy.Index, copyRef);
		}

		public List<ResourceEntry>.Enumerator GetEnumerator()
		{
			return _textures.GetEnumerator();
		}
	}
}
