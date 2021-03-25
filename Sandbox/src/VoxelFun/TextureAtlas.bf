using System;
using System.Collections;
using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;

namespace Sandbox.VoxelFun
{
	class TextureAtlas : Texture2D
	{
		public this(GraphicsContext context, List<BlockTexture> textures) : base(context)
		{
			// Todo: rewrite this garbage algorithm

			List<(Color* data, uint32 width, uint32 height, BlockTexture blockTex)> textureDatas = new .(textures.Count);
			defer
			{
				for(let item in textureDatas)
				{
					LodePng.LodePng.Free(item.data);
				}

				delete textureDatas;
			}

			uint32 maxWidth = 0;
			uint32 maxHeight = 0;

			for(let texture in textures)
			{
				(Color* data, uint32 width, uint32 height, BlockTexture blockTex) tex;
				tex.blockTex = texture;

				let error = LodePng.LodePng.Decode32File(out tex.data, out tex.width, out tex.height, texture.FileName);

				if(error != 0)
					Log.ClientLogger.Error($"Failed to load texture \"{texture.FileName}\". ({error}) \"{StringView(LodePng.LodePng.ErrorText(error))}\"");

				if(tex.width > maxWidth)
					maxWidth = tex.width;

				if(tex.height > maxHeight)
					maxHeight = tex.height;

				textureDatas.Add(tex);
			}

			uint32 texturesX = (.)System.Math.Ceiling(System.Math.Sqrt(textureDatas.Count));
			uint32 texturesY = (.)System.Math.Ceiling((float)textureDatas.Count / (float)texturesX);

			uint32 textureWidth = texturesX * maxWidth;
			uint32 textureHeight = texturesY * maxHeight;

			Color[] atlasColors = new DirectX.Color[textureWidth * textureHeight];
			defer delete atlasColors;

			uint32 currentX = 0;
			uint32 currentY = 0;

			for(let texture in textureDatas)
			{
				texture.blockTex.[Friend]_atlasStart = .((float)currentX / (float)textureWidth, (float)currentY / (float)textureHeight);
				texture.blockTex.[Friend]_atlasSize = .((float)texture.width / (float)textureWidth, (float)texture.height / (float)textureHeight);

				for(uint32 penY = currentY, uint32 y = 0; y < texture.height; penY++, y++)
				for(uint32 penX = currentX, uint32 x = 0; x < texture.width; penX++, x++)
				{
					atlasColors[penX + penY * textureWidth] = texture.data[x + y * texture.width];
				}

				currentX += maxWidth;
				if(currentX >= textureWidth)
				{
					currentX = 0;
					currentY += maxHeight;
				}
			}

			Texture2DDesc desc;
			desc.Width = textureWidth;
			desc.Height = textureHeight;
			desc.ArraySize = 1;
			desc.MipLevels = 1;
			desc.Format = .R8G8B8A8_UNorm;

			CreateTexturePlatform(desc, atlasColors.CArray(), textureWidth * sizeof(Color));
		}
	}
}
