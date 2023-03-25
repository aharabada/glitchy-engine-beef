using System;
namespace GlitchyEngine.World
{
	struct NameComponent : IDisposableComponent
	{
		private String _name;

		public StringView Name
		{
			get => _name;
			set mut
			{
				if (_name == null)
					_name = new String(value);
				else
					_name.Set(value);
			}
		}

		public void Dispose() mut
		{
			DeleteAndNullify!(_name);
		}
	}
}
