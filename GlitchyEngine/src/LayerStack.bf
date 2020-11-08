using System.Collections;

namespace GlitchyEngine
{
	public class LayerStack
	{
		private List<Layer> _layers = new List<Layer>() ~ DeleteContainerAndItems!(_);

		/*
		 * Marks the index of the last layer.
		 * Used to insert new layers before overlays.
		 */
		private int _insertIndex = 0;

		/**
		 * Pushes the provided layer onto the layer stack.
		 * @param ownLayer The layer that will be pushed onto the layerstack.
		 * @remarks The layerstack takes ownership of ownLayer.
		 */
		public void PushLayer(Layer ownLayer)
		{
			_layers.Insert(_insertIndex++, ownLayer);
		}
		
		/**
		 * Pushes the provided overlay onto the layer stack.
		 * @param ownLayer The overlay that will be pushed onto the layerstack.
		 * @remarks The layerstack takes ownership of ownOverlay.
		 */
		public void PushOverlay(Layer ownOverlay)
		{
			_layers.Add(ownOverlay);
		}
		
		/**
		 * Removes the given overlay from the layer stack.
		 * @param layer The layer to pop from the LayerStack.
		 */
		public void PopLayer(Layer layer)
		{
			if(_layers.Remove(layer))
			{
				_insertIndex--;
			}
		}
		
		/**
		 * Removes the given overlay from the layer stack.
		 * @param overlay The overlay to pop from the LayerStack.
		 */
		public void PopOverlay(Layer overlay)
		{
			_layers.Remove(overlay);
		}

		/**
		 * Returns an enumerator for enumerating the layers.
		 */
		public List<Layer>.Enumerator GetEnumerator() => _layers.GetEnumerator();
	}
}
