using System;
using GlitchyEngine.Math;

namespace Sandbox.VoxelFun
{
	class BlockTexture
	{
		private String _fileName;

		public String FileName => _fileName;

		private Vector2 _atlasStart;
		private Vector2 _atlasSize;

		[AllowAppend]
		public this(String fileName)
		{
			String str = append String(fileName);

			_fileName = str;
		}

		public Vector2 TransformTexCoords(Vector2 texCoords)
		{
			return _atlasStart + texCoords * _atlasSize;
		}
	}
}
