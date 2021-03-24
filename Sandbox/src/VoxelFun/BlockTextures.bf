using System.Collections;
using GlitchyEngine.Renderer;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
using DirectX.D3D11;
using System;
namespace Sandbox.VoxelFun
{
	class BlockTextures
	{
		static List<BlockTexture> _textures = new List<BlockTexture>() ~ DeleteContainerAndItems!(_);

		static TextureAtlas _atlas ~ _?.ReleaseRef();
			
		public static BlockTexture Stone;
		public static BlockTexture Dirt;
		public static BlockTexture GrassTop;
		public static BlockTexture GrassSide;

		public static TextureAtlas Atlas => _atlas;

		public static void Init(GraphicsContext context)
		{
			Stone = RegisterTexture(.. new BlockTexture("Content\\Textures\\Stone.png"));
			Dirt = RegisterTexture(.. new BlockTexture("Content\\Textures\\Dirt.png"));
			GrassTop = RegisterTexture(.. new BlockTexture("Content\\Textures\\GrassTop.png"));
			GrassSide = RegisterTexture(.. new BlockTexture("Content\\Textures\\GrassSide.png"));

			GenerateAtlas(context);
		}

		private static void RegisterTexture(BlockTexture texture)
		{
			_textures.Add(texture);
		}

		static void GenerateAtlas(GraphicsContext context)
		{
			_atlas = new TextureAtlas(context, _textures);

			GlitchyEngine.Renderer.SamplerStateDescription desc = .();
			desc.MagFilter = .Point;
			desc.MinFilter = .Point;
			desc.MipFilter = .Point;
			desc.MipMaxLOD = 0;
			desc.MipMinLOD = 0;
			desc.MaxAnisotropy = 0;

			_atlas.SamplerState = new SamplerState(context, desc)..ReleaseRefNoDelete();
		}
	}

	class TextureAtlas : Texture
	{
		// TODO: native code
		private ID3D11Texture2D* nativeTexture ~ _?.Release();

		public override extern uint32 Width {get;}
		public override extern uint32 Height {get;}
		public override uint32 Depth => 1;
		public override extern uint32 ArraySize {get;}
		public override extern uint32 MipLevels {get;}
		
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

			Texture2DDescription desc;
			desc.Width = textureWidth;
			desc.Height = textureHeight;
			desc.ArraySize = 1;
			desc.MipLevels = 1;
			desc.SampleDesc = .(1, 0);
			desc.Usage = .Immutable;
			desc.MiscFlags = .None;
			desc.BindFlags = .ShaderResource;
			desc.CpuAccessFlags = .None;
			desc.Format = .R8G8B8A8_UNorm;

			//SubresourceData data = .(atlasColors.CArray(), textureWidth, textureWidth * textureHeight);
			SubresourceData data = .(atlasColors.CArray(), textureWidth * sizeof(Color), 0);

			// TODO: this is bad platform dependant code...
			var result = _context.[Friend]nativeDevice.CreateTexture2D(ref desc, &data, &nativeTexture);

			//LodePng.LodePng.Encode32File("testout.png", textureD)

			if(result.Failed)
				Log.ClientLogger.Error($"Failed to create atlas texture. Error ({result.Underlying}): {result}");

			result = _context.[Friend]nativeDevice.CreateShaderResourceView(nativeTexture, null, &nativeView);

			if(result.Failed)
				Log.ClientLogger.Error($"Failed to create atlas texture. Error ({result.Underlying}): {result}");
		}
	}
}
