using System;
namespace GlitchyEngine.World
{
	struct DebugNameComponent : IDisposableComponent
	{
		private String _debugName;

		public String DebugName
		{
			get => _debugName;
			set mut => SetName(value);
		}

		public void SetName(StringView name) mut
		{
			delete _debugName;

			_debugName = new String(name);
		}

		public void Dispose() mut
		{
			DeleteAndNullify!(_debugName);
		}
	}
}
