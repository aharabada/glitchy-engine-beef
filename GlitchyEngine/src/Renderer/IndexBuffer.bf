namespace GlitchyEngine.Renderer
{
	public enum IndexFormat
	{
		Index16Bit,
		Index32Bit,
	}

	public class IndexBuffer : Buffer
	{
		private uint32 _indexCount;
		private IndexFormat _format;

		public uint32 IndexCount => _indexCount;
		public IndexFormat Format => _format;

		public this(GraphicsContext context, uint32 indexCount, Usage usage = .Default, CPUAccessFlags cpuAccess = .None, IndexFormat indexFormat = .Index16Bit) : base(context)
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
