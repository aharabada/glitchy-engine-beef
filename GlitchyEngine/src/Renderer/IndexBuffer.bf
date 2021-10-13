namespace GlitchyEngine.Renderer
{
	public enum IndexFormat
	{
		case Index16Bit;
		case Index32Bit;

		/**
		 * Returns the size in bytes of an index of the IndexFormat.
		 */
		public int IndexSize => this == Index16Bit ? 2 : 4
	}

	public class IndexBuffer : Buffer
	{
		private uint32 _indexCount;
		private IndexFormat _format;

		public uint32 IndexCount => _indexCount;
		public IndexFormat Format => _format;

		public this(uint32 indexCount, Usage usage = .Default, CPUAccessFlags cpuAccess = .None, IndexFormat indexFormat = .Index16Bit)
		{
			_indexCount = indexCount;
			_format = indexFormat;

			_description = .()
				{
					Size = (_format == .Index32Bit ? 4 : 2) * _indexCount,
					Usage = usage,
					CPUAccess = cpuAccess,
					BindFlags = .Index,
					MiscFlags = .None
				};
		}
	}
}
