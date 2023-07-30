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

		public delegate void ElementFunc(TreeNode<T> currentNode);

		public enum IterationMode
		{
			BreadthFirst,
			DepthFirst
		}

		public bool IsParentOf(TreeNode<T> wantedChild)
		{
			return wantedChild.IsChildOf(this);
		}

		public bool IsChildOf(TreeNode<T> wantedParent)
		{
			TreeNode<T> currentParent = Parent;

			while (currentParent != null)
			{
				if (currentParent == wantedParent)
					return true;

				currentParent = currentParent.Parent;
			}

			return false;
		}

		public bool IsInSubtree(TreeNode<T> subtree)
		{
			if (this == subtree)
				return true;

			return IsChildOf(subtree);
		}

		public void ForEach(ElementFunc func, IterationMode iterationMode = .DepthFirst)
		{
			if (iterationMode == .BreadthFirst)
			{
				ForEach_BreadthFirst(func);
			}
			else if (iterationMode == .DepthFirst)
			{
				ForEach_DepthFirst(func);
			}
		}

		public void ForEach_BreadthFirst(ElementFunc func)
		{
			Queue<TreeNode<T>> nodes = scope .();
			nodes.Add(this);

			while (!nodes.IsEmpty)
			{
				TreeNode<T> node = nodes.PopFront();

				func(node);
				
				for (var child in node.Children)
				{
					nodes.Add(child);
				}
			}
		}

		public void ForEach_DepthFirst(ElementFunc func)
		{
			List<TreeNode<T>> nodes = scope .();
			nodes.Add(this);

			while (!nodes.IsEmpty)
			{
				TreeNode<T> node = nodes.PopBack();

				func(node);
				
				for (var child in node.Children)
				{
					nodes.Add(child);
				}
			}
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
			if (tree == null)
				return;

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
