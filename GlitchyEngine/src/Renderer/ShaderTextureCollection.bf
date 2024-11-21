using System;
using System.Collections;

namespace GlitchyEngine.Renderer
{
	public class ShaderTextureCollection : IEnumerable<(String Name, uint32 Index, TextureViewBinding BoundTexture, TextureDimension Dimension)>
	{
		public typealias ResourceEntry = (String Name, uint32 Index, TextureViewBinding BoundTexture, TextureDimension Dimension);

		List<ResourceEntry> _textures ~ DeleteTextureEntries!(_);
		
		/*Dictionary<String, ResourceEntry*> _strToBuf ~ delete _;
		Dictionary<int, ResourceEntry*> _idxToBuf ~ delete _;*/
		Dictionary<String, uint32> _strToBuf ~ delete _;
		Dictionary<int, uint32> _idxToBuf ~ delete _;

		public this()
		{
			let textures = new List<ResourceEntry>();
			let strToBuf = new Dictionary<String, uint32>();
			let idxToBuf = new Dictionary<int, uint32>();

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
				entry.BoundTexture.ReleaseRef();
			}

			delete entries;
		}

		// TODO: finish implementation (like BufferCollection)
		public ref ResourceEntry this[int idx] => ref _textures[_idxToBuf[idx]];
		public ref ResourceEntry this[String name] => ref _textures[_strToBuf[name]];

		public void Add(String name, uint32 index, TextureViewBinding texture, TextureDimension dimension)
		{
			Add((name, index, texture, dimension));
		}

		public void Add(ResourceEntry entry)
		{
			ResourceEntry copy = (new String(entry.Name), entry.Index, entry.BoundTexture, entry.Dimension);
			entry.BoundTexture.AddRef();

			_textures.Add(copy);

			_strToBuf.Add(copy.Name, (uint32)(_textures.Count - 1));
			_idxToBuf.Add(copy.Index, (uint32)(_textures.Count - 1));
		}

		public List<ResourceEntry>.Enumerator GetEnumerator()
		{
			return _textures.GetEnumerator();
		}
	}
}
