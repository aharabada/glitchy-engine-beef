#if BF_PLATFORM_WINDOWS

using System;
using System.Collections;
using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEditor.Platform.Windows;
using DirectX.Common;

namespace GlitchyEditor.Platform;

extension DragDropManager
{
	private static DragDropEventTranslator _dragDropTarget;
	
	public override static void Init()
	{
		HResult result = OleInitialize(null);
		Log.EngineLogger.Assert(result case .S_OK);

		_dragDropTarget = new .();
		_dragDropTarget.Register();
	}

	public override static void Deinit()
	{
		_dragDropTarget.Unregister();
		ReleaseRefAndNullify!(_dragDropTarget);
	}

	private static bool _isDragging;

	public static void StartDragDrop()
	{
		if (_isDragging)
			return;

		_isDragging = true;

		IDataObject* dataObject = null;
		
		//HResult result = DoDragDrop(ref dataObject);
	}
}

/// Registers a Windows drag'n'drop target that will fire Windows drop related events using the engine's event system.
class DragDropEventTranslator : IDropTargetImplBase
{
	public override Result<DropEffect> OnDragEnter(int2 cursorPosition)
	{
		DragDropEvent event = scope DragDropEvent(.Enter, cursorPosition);
		Application.Instance.OnEvent(event);
		return event.OutDropEffect;
	}

	public override Result<DropEffect> OnDragOver(int2 cursorPosition)
	{
		DragDropEvent event = scope DragDropEvent(.Over, cursorPosition);
		Application.Instance.OnEvent(event);
		return event.OutDropEffect;
	}

	public override Result<void> OnDragLeave()
	{
		DragDropEvent event = scope DragDropEvent(.Leave, .(-1, -1));
		Application.Instance.OnEvent(event);
		return .Ok;
	}

	public override Result<DropEffect> OnDrop(int2 cursorPosition, Span<StringView> fileNames)
	{
		DragDropEvent event = scope DragDropEvent(.Drop, cursorPosition);
		event.FileNames = fileNames;
		Application.Instance.OnEvent(event);
		return event.OutDropEffect;
	}
}

#endif
