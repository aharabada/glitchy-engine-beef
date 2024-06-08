using ImGui;
using System;
using GlitchyEngine.Collections;
using GlitchyEngine.Content;
using System.Reflection;
using GlitchyEngine;
using GlitchyEditor.Assets;
using GlitchyEngine.Core;
using GlitchyEngine.World;

namespace GlitchyEditor.EditWindows;

class PropertiesWindow : ClosableWindow
{
	private SelectedObject _selectedObject = .None;

	public this(Editor editor, SelectedObject selectedObject) : base(editor, "Properties")
	{
		_selectedObject = selectedObject;
	}

	protected override void InternalShow()
	{
		InspectorWindow.ShowSelectedObject(_selectedObject, _editor);
	}
}
