using System;
using System.Collections;
using System.IO;
using GlitchyEngine.Renderer;

namespace GlitchyEngine.Content.Loaders;

class ShaderLoader : IProcessedAssetLoader
{
	public Result<Asset> Load(Stream stream)
	{
		uint64 vsDataSize = Try!(stream.Read<uint64>());
		uint64 psDataSize = Try!(stream.Read<uint64>());
		
		VertexShader vertexShader = null;
		PixelShader pixelShader = null;

		Effect effect = new Effect();

		// Properly clean up in case of an error
		defer
		{
			vertexShader?.ReleaseRef();
			pixelShader?.ReleaseRef();
			if (@return case .Err)
			{
				effect.ReleaseLastRef();
			}
		}

		if (vsDataSize > 0)
		{
			uint8[] vsData = new:ScopedAlloc! uint8[vsDataSize];
			Try!(stream.TryRead(vsData));

			vertexShader = (VertexShader)Try!(Shader.CreateFromBlob(vsData, .Vertex));
			effect.[Friend]VertexShader = vertexShader;
		}

		if (psDataSize > 0)
		{
			uint8[] psData = new:ScopedAlloc! uint8[psDataSize];
			Try!(stream.TryRead(psData));

			pixelShader = (PixelShader)Try!(Shader.CreateFromBlob(psData, .Pixel));
			effect.[Friend]PixelShader = pixelShader;
		}

		uint16 textureCount = Try!(stream.Read<uint16>());

		for (int i < textureCount)
		{
			TextureDimension dimension = Try!(stream.Read<TextureDimension>());
			int32 vertexShaderBindPoint = Try!(stream.Read<int32>());
			int32 pixelShaderBindPoint = Try!(stream.Read<int32>());

			int16 textureNameLength = Try!(stream.Read<int16>());
			String textureName = new String(textureNameLength);
			stream.ReadStrSized32(textureNameLength, textureName);

			Effect.TextureEntry entry = .(TextureViewBinding.CreateDefault(), dimension, null, null);

			if (vertexShaderBindPoint != -1 && vertexShader != null)
			{
				vertexShader.Textures.Add(textureName, (.)vertexShaderBindPoint, entry.BoundTexture, dimension);
				entry.VsSlot = &vertexShader.Textures[textureName];
			}

			// TODO: Why is nullcheck different for vertex and pixel shader?
			if (pixelShaderBindPoint != -1)
			{
				pixelShader?.Textures.Add(textureName, (.)pixelShaderBindPoint, entry.BoundTexture, dimension);
				entry.PsSlot = &pixelShader.Textures[textureName];
			}

			effect.Textures[textureName] = entry;
		}

		uint16 bufferCount = Try!(stream.Read<uint16>());

		for (int i < bufferCount)
		{
			Try!(LoadBuffer(stream, effect));
		}

		return effect;
	}

	private static mixin ReadScopedSizedString<Tint>(Stream stream)
		where Tint : IInteger
		where int : operator explicit Tint
		where Tint : operator explicit int
		where Tint : struct
	{
		int bufferNameLength = (int)Try!(stream.Read<Tint>());

		String string = scope:mixin String(bufferNameLength);

		if (bufferNameLength > 0)
			stream.ReadStrSized32(bufferNameLength, string);

		string
	}

	private static Result<void> LoadBuffer(Stream stream, Effect effect)
	{
		int64 bufferSize = Try!(stream.Read<int64>());

		int32 vertexShaderBindPoint = Try!(stream.Read<int32>());
		int32 pixelShaderBindPoint = Try!(stream.Read<int32>());

		String bufferName = ReadScopedSizedString!<uint16>(stream);
		String engineBufferName = ReadScopedSizedString!<uint16>(stream);

		using (ConstantBuffer buffer = new ConstantBuffer(bufferName, bufferSize, engineBufferName))
		{
			uint16 variableCount = Try!(stream.Read<uint16>());

			for (int v < variableCount)
			{
				uint64 variableOffset = Try!(stream.Read<uint64>());
				uint64 sizeInBytes = Try!(stream.Read<uint64>());
				bool isUsed = Try!(stream.Read<uint8>()) > 0;
				ShaderVariableType type = Try!(stream.Read<ShaderVariableType>());
				uint8 rows = Try!(stream.Read<uint8>());
				uint8 columns = Try!(stream.Read<uint8>());
				uint64 arraySize = Try!(stream.Read<uint64>());

				String variableName = ReadScopedSizedString!<uint16>(stream);
				String previewName = ReadScopedSizedString!<uint16>(stream);
				String editorTypeName = ReadScopedSizedString!<uint16>(stream);

				buffer.AddVariable(variableName, previewName, editorTypeName, variableOffset, sizeInBytes, isUsed, type, rows, columns, arraySize);
			}

			Try!(stream.TryRead(buffer.RawData));
			Try!(buffer.Apply());

			if (vertexShaderBindPoint != -1)
				effect.VertexShader.Buffers.Add(vertexShaderBindPoint, buffer.Name, engineBufferName, buffer);

			if (pixelShaderBindPoint != -1)
				effect.PixelShader.Buffers.Add(pixelShaderBindPoint, buffer.Name, engineBufferName, buffer);

			// TODO: Allow binding buffers to different indices? Does this theoretically work with textures?
			let tempBindPoint = (vertexShaderBindPoint != -1) ? vertexShaderBindPoint : pixelShaderBindPoint;
			effect.Buffers.Add(tempBindPoint, buffer.Name, engineBufferName, buffer);

			for (var variable in buffer.Variables)
			{
				effect.Variables.Add(variable);
			}
		}

		return .Ok;
	}
}
