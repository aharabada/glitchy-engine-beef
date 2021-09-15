using System.Collections;

namespace GlitchyEngine.Collections
{
	public class TreeNode<T>
	{
		public T Value;

		public List<Self> Children = new .() ~ DeleteContainerAndItems!(_);

		public this() {}

		public this(T value)
		{
			Value = value;
		}

		public Self AddChild(T value)
		{
			for (var child in Children)
			{
				if(child.Value == value)
					return child;
			}

			Self newChild = new .(value);

			Children.Add(newChild);

			return newChild;
		}

		public Self FindNode(T value)
		{
			if (Value == value)
				return this;

			for (var child in Children)
			{
				var childResult = child.FindNode(value);
				if (childResult != null)
					return childResult;
			}

			return null;
		}
	}
}
