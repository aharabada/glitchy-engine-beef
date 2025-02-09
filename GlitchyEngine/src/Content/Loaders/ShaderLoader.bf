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

	private static Result<void> LoadBuffer(Stream stream, Effect effect)
	{
		int64 bufferSize = Try!(stream.Read<int64>());

		int32 vertexShaderBindPoint = Try!(stream.Read<int32>());
		int32 pixelShaderBindPoint = Try!(stream.Read<int32>());

		int16 bufferNameLength = Try!(stream.Read<int16>());
		String bufferName = scope String(bufferNameLength);
		stream.ReadStrSized32(bufferNameLength, bufferName);

		int16 engineBufferNameLength = Try!(stream.Read<int16>());
		String engineBufferName = null;

		if (engineBufferNameLength > 0)
		{
			scope String(engineBufferNameLength);
			stream.ReadStrSized32(engineBufferNameLength, engineBufferName);

			// TODO: Engine buffers currently do nothing. The bind points for each engine buffer are hardcoded.
			// It only marks the buffer as engine buffer, preventing the variables from becomming accessible.
			//effect.[Friend]_engineBuffers.Add()
		}

		using (ConstantBuffer buffer = new ConstantBuffer(bufferName, bufferSize))
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

				int16 variableNameLength = Try!(stream.Read<int16>());
				String variableName = scope String(variableNameLength);
				stream.ReadStrSized32(variableNameLength, variableName);

				if (engineBufferName == null)
					buffer.AddVariable(variableName, variableOffset, sizeInBytes, isUsed, type, rows, columns, arraySize);
			}

			Try!(stream.TryRead(buffer.RawData));
			Try!(buffer.Apply());

			if (vertexShaderBindPoint != -1)
				effect.VertexShader.Buffers.Add(vertexShaderBindPoint, buffer.Name, buffer);

			if (pixelShaderBindPoint != -1)
				effect.PixelShader.Buffers.Add(pixelShaderBindPoint, buffer.Name, buffer);

			// TODO: Allow binding buffers to different indices? Does this theoretically work with textures?
			let tempBindPoint = (vertexShaderBindPoint != -1) ? vertexShaderBindPoint : pixelShaderBindPoint;
			effect.Buffers.Add(tempBindPoint, buffer.Name, buffer);

			for (var variable in buffer.Variables)
			{
				effect.Variables.Add(variable);
			}
		}

		return .Ok;
	}
}
