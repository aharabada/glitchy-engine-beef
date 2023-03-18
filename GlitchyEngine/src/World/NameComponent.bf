using System;
namespace GlitchyEngine.World
{
	struct NameComponent : IDisposableComponent
	{
		private String _name;

		public StringView Name
		{
			get => _name;
			set mut => SetName(value);
		}

		public void SetName(StringView name) mut
		{
			if (_name == null)
				_name = new String(name);
			else
				_name.Set(name);
		}

		public void Dispose() mut
		{
			DeleteAndNullify!(_name);
		}
	}
}
