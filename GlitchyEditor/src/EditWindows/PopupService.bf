using System;
using ImGui;
using System.Collections;
using GlitchyEngine;
namespace GlitchyEditor.EditWindows;

class Popup
{
	public String Title ~ delete _;
	public ImGui.WindowFlags WindowFlags;

	public delegate void(out bool) Render ~ delete _;

	public this(StringView title, delegate void(out bool) render, ImGui.WindowFlags flags)
	{
		Title = new String(title);
		Render = render;
		WindowFlags = flags;
	}
}

class PopupService
{
	private static PopupService _service = new PopupService() ~ delete _;

	public static PopupService Instance => _service;

	private append List<Popup> _popups = .() ~ ClearAndDeleteItems(_);

	public void OpenPopup(StringView popupTitle, delegate void(out bool) render, ImGui.WindowFlags flags = .AlwaysAutoResize | .NoSavedSettings | .NoResize)
	{
		Popup popup = new Popup(popupTitle, render, flags);
		_popups.Add(popup);

		Log.EngineLogger.Info($"Opened {popupTitle}");
	}

	public void ShowMessageBox(StringView title, StringView message)
	{
		String messageCopy = new String(message);
		
		OpenPopup(title, new (close) =>
			{
				close = false;

				ImGui.NewLine();

				ImGui.TextUnformatted(messageCopy);
				
				ImGui.NewLine();

				if (ImGui.Button("Ok"))
				{
					delete messageCopy;
					close = true;
				}
			}
		);
	}

	public void ImGuiDraw()
	{
		for (Popup popup in _popups)
		{
			ImGui.OpenPopup(popup.Title);
			
			let center = ImGui.GetWindowViewport().GetCenter();
			ImGui.SetNextWindowPos(center, .Appearing, .(0.5f, 0.5f));
			if (ImGui.BeginPopupModal(popup.Title, null, popup.WindowFlags))
			{
				popup.Render(let close);
				if (close)
				{
					ImGui.CloseCurrentPopup();
					@popup.Remove();
					delete popup;
				}
	
				ImGui.EndPopup();
			}
		}
	}
}