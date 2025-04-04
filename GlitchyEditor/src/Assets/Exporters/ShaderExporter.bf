using GlitchyEngine;
using GlitchyEditor.Assets.Importers;
using GlitchyEditor.Assets.Processors;
using GlitchyEngine.Content;
using System;
using System.IO;

namespace GlitchyEditor.Assets.Exporters;

class ShaderExporter : IAssetExporter
{
	public static AssetType ExportedAssetType => .Shader;

	public AssetExporterConfig CreateDefaultConfig() => new AssetExporterConfig();

	public Result<void> Export(Stream stream, ProcessedResource processedResource, AssetConfig config)
	{
		Log.EngineLogger.AssertDebug(processedResource is ProcessedShader);

		ProcessedShader shader = (.)processedResource;

		/*

		File Format:
		Vertex Shader Blob Length (uint64 / 8 bytes) (0 if null)
		Pixel Shader Blob Length (uint64 / 8 bytes) (0 if null)
		Vertex Shader Data...
		Pixel Shader Data...
		Texture Count (uint16)
		Textures
		{
			Texture Dimension (1 byte)
			Vertex Shader Bind Point (int32, 4 bytes) # TODO: ASSUME same bind point for all shader stages?
			Pixel Shader Bind Point (int32, 4 bytes)  # TODO: ASSUME same bind point for all shader stages?
			Texture Name Length (uint16)
			Texture Name Data...
		}
		Buffer Count (uint16)
		Buffers
		{
			Buffer Size (int64)
			Vertex Shader Bind Point (int32, 4 bytes) # TODO: ASSUME same bind point for all shader stages?
			Pixel Shader Bind Point (int32, 4 bytes)  # TODO: ASSUME same bind point for all shader stages?
			Buffer Name Length (uint16)
			Buffer Name Data...
			Engine Buffer Name Length (uint16)
			Engine Buffer Name Data...
			Variable Count (uint16)
			Variables
			{
				Offset (uint64)
				Size In Bytes (uint64)
				IsUsed (bool, 1 byte)
				ShaderVariableType (1 Byte)
				Rows (uint8)
				Columns (uint8)
				ArraySize (uint64)
				Name Length (uint16)
				Name Data...
				Preview Name Length (uint16)
				Preview Name Data...
				Type Editor Name Length (uint16)
				Type Editor Name Data...
				# TODO: Min and Max
			}
			RawData...
		}

		*/

		Span<uint8> vsData = shader.VertexShader?.Blob ?? Span<uint8>();
		Span<uint8> psData = shader.PixelShader?.Blob ?? Span<uint8>();

		Try!(stream.Write((uint64)vsData.Length));
		Try!(stream.Write((uint64)psData.Length));

		if (vsData.Ptr != null)
			Try!(stream.Write(vsData));

		if (psData.Ptr != null)
			Try!(stream.Write(psData));

		Try!(WriteTextures(stream, shader));
		Try!(WriteConstantBuffers(stream, shader));

		return .Ok;
	}

	private Result<void> WriteTextures(Stream stream, ProcessedShader shader)
	{
		Log.EngineLogger.Assert(shader.Textures.Count < int16.MaxValue);

		Try!(stream.Write((uint16)shader.Textures.Count));

		for (let (textureName, textureEntry) in shader.Textures)
		{
			Try!(stream.Write((uint8)textureEntry.TextureDimension));
			Try!(stream.Write((int32)textureEntry.VertexShaderBindPoint));
			Try!(stream.Write((int32)textureEntry.PixelShaderBindPoint));
			WriteSizedString<uint16>(stream, textureName);
		}

		return .Ok;
	}

	private Result<void> WriteConstantBuffers(Stream stream, ProcessedShader shader)
	{
		Log.EngineLogger.Assert(shader.ConstantBuffers.Count < int16.MaxValue);

		Try!(stream.Write((uint16)shader.ConstantBuffers.Count));

		for (let (bufferName, bufferEntry) in shader.ConstantBuffers)
		{
			ReflectedConstantBuffer buffer = bufferEntry.ConstantBuffer;

			Try!(stream.Write((uint64)buffer.Size));

			Try!(stream.Write((int32)bufferEntry.VertexShaderBindPoint));
			Try!(stream.Write((int32)bufferEntry.PixelShaderBindPoint));
			
			WriteSizedString<uint16>(stream, bufferName);

			WriteSizedString<uint16>(stream, bufferEntry.ConstantBuffer.EngineBufferName);

			Log.EngineLogger.Assert(buffer.Variables.Count < int16.MaxValue);

			Try!(stream.Write((uint16)buffer.Variables.Count));

			for (let (variableName, variable) in buffer.Variables)
			{
				Try!(stream.Write((uint64)variable.Offset));
				Try!(stream.Write((uint64)variable.SizeInBytes));
				Try!(stream.Write((uint8)(variable.IsUsed ? 1 : 0)));
				Try!(stream.Write((uint8)(variable.ElementType)));
				
				Log.EngineLogger.Assert(variable.Rows < int8.MaxValue);
				Log.EngineLogger.Assert(variable.Columns < int8.MaxValue);

				Try!(stream.Write((uint8)variable.Rows));
				Try!(stream.Write((uint8)variable.Columns));
				Try!(stream.Write((uint64)variable.ArraySize));
				
				WriteSizedString<uint16>(stream, variableName);
				WriteSizedString<uint16>(stream, variable.PreviewName);
				WriteSizedString<uint16>(stream, variable.EditorType);
			}

			Try!(stream.Write(Span<uint8>(buffer.RawData, 0, buffer.Size)));
		}

		return .Ok;
	}

	private static Result<void> WriteSizedString<Tint>(Stream stream, StringView string)
		where Tint : IInteger
		where int : operator explicit Tint
		where Tint : operator explicit int
		where Tint : struct
	{
		Log.EngineLogger.Assert(string.Length < (int)typeof(Tint).MaxValue);

		Try!(stream.Write((Tint)string.Length));
		
		if (string.Length > 0)
			Try!(stream.WriteStrUnsized(string));

		return .Ok;
	}
}
