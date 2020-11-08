using System;
using GlitchyEngine.Events;

namespace GlitchyEngine
{
	public abstract class Layer
	{
		protected String _debugName;

		[Inline]
		public StringView Name => _debugName;

		[AllowAppend]
		public this(StringView name = "Layer")
		{
			String debugName = append String(name);
			_debugName = debugName;
		}

		public virtual void OnAttach() {  }
		public virtual void OnDetach() {  }
		public virtual void Update() {  }
		public virtual void OnEvent(Event event) {  }
	}
}
