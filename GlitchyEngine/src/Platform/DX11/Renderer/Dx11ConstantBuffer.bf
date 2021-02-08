using DirectX.Common;
using DirectX.D3D11Shader;
using System;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	extension BufferVariable
	{
		internal this(ConstantBuffer constantBuffer, ID3D11ShaderReflectionVariable* variableReflection)
		{
			_constantBuffer = constantBuffer;

			HResult result = variableReflection.GetDescription(let variableDescription);
			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to get variable description. Error({(int)result}): {result}");

			_name = new String(variableDescription.Name);

			_offset = variableDescription.StartOffset;
			_sizeInBytes = variableDescription.Size;
			_isUsed = variableDescription.uFlags.HasFlag(.Used);

			let variableType = variableReflection.GetVariableType();
			result = variableType.GetDescription(let shaderTypeDescription);
			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to get variable type description. Error({(int)result}): {result}");

			switch(shaderTypeDescription.Type)
			{
			case .Float:
				_type = .Float;
			default:
				Log.EngineLogger.Assert(false, scope $"Unhandled shader variable type: {shaderTypeDescription.Type}");
			}

			_columns = shaderTypeDescription.Columns;
			_rows = shaderTypeDescription.Rows;

			SetRawData(variableDescription.DefaultValue);
		}
	}

	extension ConstantBuffer
	{
		internal this(GraphicsContext context, ID3D11ShaderReflectionConstantBuffer* bufferReflection) : base(context)
		{
			Reflect(bufferReflection);

			ConstructBuffer();
			
			Update();
		}

		private void Reflect(ID3D11ShaderReflectionConstantBuffer* bufferReflection)
		{
			HResult result = bufferReflection.GetDescription(let bufferDescription);
			Log.EngineLogger.Assert(result.Succeeded, scope $"Failed to get buffer description. Error({(int)result}): {result}");

			Log.EngineLogger.AssertDebug(bufferDescription.Type == .D3D_CT_CBUFFER, "The buffer is not of type \"D3D_CT_CBUFFER\"");

			_name = new String(bufferDescription.Name);

			rawData = new uint8[bufferDescription.Size];

			// Flags seem to be irrelevant for us here
			
			for(uint32 v = 0; v < bufferDescription.Variables; v++)
			{
				ID3D11ShaderReflectionVariable* variableReflection = bufferReflection.GetVariableByIndex(v);

				BufferVariable variable = new BufferVariable(this, variableReflection);

				AddVariable(variable);
			}
		}
	}
}
