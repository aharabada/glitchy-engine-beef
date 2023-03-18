using System.Collections;

namespace GlitchyEngine.Collections
{
	// TODO: TreeNode is very bare minimum
	// Destructor?
	// RemoveChild?
	// Remove in enumerator?

	public class TreeNode<T>
	{
		public T Value;

		public Self Parent;
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
			newChild.Parent = this;

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

		public static ref T operator ->(TreeNode<T> node)
		{
			return ref node.Value;
		}
	}

	static
	{
		public static mixin DeleteTreeAndChildren<T>(TreeNode<T> tree) where T : class, delete
		{
			InternalDeleteTreeAndChildren(tree);
		}

		private static void InternalDeleteTreeAndChildren<T>(TreeNode<T> tree) where T : class, delete
		{
			for (var child in tree.Children)
			{
				InternalDeleteTreeAndChildren(child);
			}

			delete tree.Value;

			tree.Children.Clear();

			delete tree;
		}
	}
}
