using GlitchyEngine.Core;

namespace GlitchyEngine.Renderer
{
	/// The stencil operations that can be performed during depth-stencil testing.
	public enum StencilOperation : uint32
	{
		/// Keep the existing stencil data.
		Keep = 1,
		/// Set the stencil data to 0.
		Zero= 2,
		/// Set the stencil data to the reference value set by calling ID3D11DeviceContext::OMSetDepthStencilState.
		Replace = 3,
		/// Increment the stencil value by 1, and clamp the result. 
		IncrementAndClamp = 4,
		/// Decrement the stencil value by 1, and clamp the result.
		DecrementAndClamp = 5,
		/// Invert the stencil data.
		Invert = 6,
		/// Increment the stencil value by 1, and wrap the result if necessary. 
		Increment = 7,
		/// Decrement the stencil value by 1, and wrap the result if necessary.
		Decrement = 8
	}

	public struct DepthStencilOperationDescription
	{
		/// The stencil operation to perform when stencil testing fails.
		public StencilOperation StencilFailOperation = .Keep;
		
		/// The stencil operation to perform when stencil testing passes and depth testing fails.
		public StencilOperation StencilDepthFailOperation = .Keep;

		/// The stencil operation to perform when stencil testing and depth testing both pass.
		public StencilOperation StencilPassOperation = .Keep;

		/// A function that compares stencil data against existing stencil data.
		public ComparisonFunction StencilFunction = .Always;

		public this(StencilOperation stencilFailOperation = .Keep, StencilOperation stencilDepthFailOperation = .Keep,
			StencilOperation stencilPassOperation = .Keep, ComparisonFunction stencilFunction = .Always)
		{
			StencilFunction = stencilFunction;
		}

		public const Self Default = Self();
	}

	public struct DepthStencilStateDescription
	{
		/// True if depth testing is enabled.
		public bool DepthEnabled = true;

		/// If true writing to the depth-stencil buffer is enabled.
		public bool WriteDepth = true;

		/// The function that is used to compare depth data against the existing depth data.
		public ComparisonFunction DepthFunction = .Less;

		/// True if stencil testing is enabled.
		public bool StencilEnabled = false;

		public uint8 StencilReadMask = 255;
		public uint8 StencilWriteMask = 255;

		public DepthStencilOperationDescription FrontFace = .();
		public DepthStencilOperationDescription BackFace = .();

		public this(bool depthEnabled = true, bool writeDepth = true, ComparisonFunction depthFunction = .Less,
			bool stencilEnabled = false, uint8 stencilReadMask = 255, uint8 stencilWriteMask = 255,
			DepthStencilOperationDescription frontFace = .(),
			DepthStencilOperationDescription backFace = .())
		{
			DepthEnabled = depthEnabled;
			WriteDepth = writeDepth;
			DepthFunction = depthFunction;
			StencilEnabled = stencilEnabled;
			StencilReadMask = stencilReadMask;
			StencilWriteMask = stencilWriteMask;
			FrontFace = frontFace;
			BackFace = backFace;
		}

		public const DepthStencilStateDescription Default = Self();
	}

	class DepthStencilState : RefCounter
	{
		public DepthStencilStateDescription _description;

		public extern this(DepthStencilStateDescription description);
	}
}