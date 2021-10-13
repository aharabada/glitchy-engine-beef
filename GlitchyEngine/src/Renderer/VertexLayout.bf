using System;
using GlitchyEngine.Core;

namespace GlitchyEngine.Renderer
{
	
	/**
	 * Type of data contained in an input slot.
	*/
	public enum InputClassification
	{
		/**
		 * Input data is per-vertex data.
		*/
	    PerVertexData	= 0,
		/**
		 * Input data is per-instance data.
		*/
	    PerInstanceData	= 1
	}

	public struct VertexElement
	{
		/**
		 * The semantic associated with this element in a shader input-signature.
		*/
		public String SemanticName;
		/**
		 * If set to True, the VertexLayout will delete SemanticName once it's reference count is 0.
		 */
		public bool OwnsName;
		/**
		 * The semantic index for the element.
		 * A semantic index modifies a semantic, with an integer index number.
		 * A semantic index is only needed in a case where there is more than one element with the same semantic.
		 * For example, a 4x4 matrix would have four components each with the semantic name "matrix",
		 * however each of the four component would have different semantic indices (0, 1, 2, and 3).
		 */
		public uint32 SemanticIndex;
		/**
		 * The data type of the element data.
		*/
		public Format Format;
		/**
		 * An integer value that identifies the input-assembler (see input slot). Valid values are between 0 and 15.
		*/
		public uint32 InputSlot;
		/**
		 * Optional. Offset (in bytes) from the start of the vertex. Use AppendAligned for convenience to define the current element directly after the previous one, including any packing if necessary.
		*/
		public uint32 AlignedByteOffset;
		/**
		 * Identifies the input data class for a single input slot.
		*/
		public InputClassification InputSlotClass;
		/**
		 * The number of instances to draw using the same per-instance data before advancing in the buffer by one element.
		 * This value must be 0 for an element that contains per-vertex data (the slot class is set to PerVertexData).
		*/
		public uint32 InstanceDataStepRate;

		public this() => this = default;

		public this(Format format, String semanticName, bool ownsName = false, uint32 semanticIndex = 0, uint32 inputSlot = 0, uint32 offset = (.)-1, InputClassification slotClass = .PerVertexData, uint32 instanceStepRate = 0)
		{
			Format = format;
			SemanticName = semanticName;
			OwnsName = ownsName;
			SemanticIndex = semanticIndex;
			InputSlot = inputSlot;
			AlignedByteOffset = offset;
			InputSlotClass = slotClass;
			InstanceDataStepRate = instanceStepRate;
		}

		/**
		 * Use AppendAligned for convenience to define the current element directly after the previous one, including any packing if necessary.
		*/
		public static readonly uint32 AppendAligned = 0xffffffff;
	}

	public class VertexLayout : RefCounter
	{
		private GraphicsContext _context ~ _?.ReleaseRef();

		private VertexElement[] _elements;
		private bool _ownsElements;

		public GraphicsContext Context => _context;

		public VertexElement[] Elements => _elements;

		public this(GraphicsContext context, VertexElement[] elements, bool ownsElements, VertexShader vertexShader)
		{
			_context = context..AddRef();
			_elements = elements;
			_ownsElements = ownsElements;

			CreateNativeLayout();
		}

		public ~this()
		{
			if(_ownsElements)
			{
				for(var element in _elements)
				{
					if(element.OwnsName)
						delete element.SemanticName;
				}
	
				delete _elements;
			}
		}

		protected extern void CreateNativeLayout();
	}

	public interface IVertexData
	{
		static VertexElement[] VertexElements {get;}
	}
}
