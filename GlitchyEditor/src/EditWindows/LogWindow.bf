using System;
using ImGui;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.World;
using GlitchLog;
using GlitchyEngine.Scripting;
using GlitchyEngine.Renderer;
using GlitchyEngine;
using GlitchyEditor.CodeEditors;

namespace GlitchyEditor.EditWindows;

enum MessageType
{
	case None = 0;
	case Trace = 1;
	case Info = 2;
	case Warning = 4;
	case Error = 8;

	public this(LogLevel level)
	{
		switch (level)
		{
		case .Error:
			this = Error;
		case .Warning:
			this = Warning;
		case .Info:
			this = Info;
		case .Trace:
			this = Trace;
		default:
			this = None;
		}
	}
}

class MessageSource
{
	public UUID? Entity = null;
	public MessageOrigin MessageOrigin = null ~ delete _;

	/// If true, the message is only meant for engine developers... so only me :(
	public bool IsEngineMessage = false;

	public ScriptException Exception = null ~ delete _;

	public String AdditionalData = null ~ delete _;
}

class LogMessage
{
	private String _message ~ delete _;

	public MessageType MessageType { get; private set; }

	public DateTime Timestamp { get; private set; }

	public MessageSource Source { get; private set; } ~ delete _;

	public StringView Message => _message;

	public this(DateTime timestamp, StringView message, MessageType logLevel, MessageSource ownSource)
	{
		Timestamp = timestamp;
		_message = new String(message);
		MessageType = logLevel;
		Source = ownSource;
	}
}

class LogWindow : EditorWindow
{
	public const String s_WindowTitle = "Log";

	private append List<LogMessage> _messages = .() ~ ClearAndDeleteItems!(_);

	public static SubTexture2D s_ErrorIcon;
	public static SubTexture2D s_WarningIcon;
	public static SubTexture2D s_InfoIcon;
	public static SubTexture2D s_TraceIcon;

	private bool _showGameMessages = true;
	private bool _showEngineMessages = false;
	private bool _autoScroll = true;
	private bool _collapseMessages = true;

	private MessageType _visibleMessageTypes = .Error | .Warning | .Info | .Trace;

	protected override void InternalShow()
	{
		defer { ImGui.End(); }
		if(!ImGui.Begin(s_WindowTitle, &_open, .MenuBar))
			return;

		ShowMenuBar();

		ShowMessages();
	}

	private void ShowMenuBar()
	{
		if(ImGui.BeginMenuBar())
		{
			if (ImGui.MenuItem("Clear"))
			{
				ClearLog();
			}

			if (ImGui.BeginMenu("Filter"))
			{
				ImGui.Checkbox("Show game messages", &_showGameMessages);
				ImGui.AttachTooltip("If checked, the log will show messages generated by the game (e.g. scripts).");

				ImGui.Checkbox("Show engine messages", &_showEngineMessages);
				ImGui.AttachTooltip("""
					If checked, the log will show messages generated by the engine.
					These messages are usually only necessary for engine debugging/development and don't provide practical information for game developers.
					""");

				ImGui.EndMenu();
			}

			ImGui.Checkbox("Collapse", &_collapseMessages);
			ImGui.AttachTooltip("If checked, identical messages will be collapsed into one.");

			var maxSpace = ImGui.GetFontSize();

			ImGui.Vec2 buttonSize = .(maxSpace, maxSpace);

			var col = ImGui.GetStyleColorVec4(.Button);
			ImGui.PushStyleVar(.FramePadding, ImGui.Vec2(2, 2));

			if (_visibleMessageTypes.HasFlag(.Trace))
				ImGui.PushStyleColor(.Button, *col);
			else
				ImGui.PushStyleColor(.Button, .(0, 0, 0, 0));

			if (ImGui.ImageButtonEx(1, s_TraceIcon, buttonSize, .Zero, .Ones))
				_visibleMessageTypes ^= .Trace;

			ImGui.PopStyleColor();

			if (_visibleMessageTypes.HasFlag(.Info))
				ImGui.PushStyleColor(.Button, *col);
			else
				ImGui.PushStyleColor(.Button, .(0, 0, 0, 0));

			if (ImGui.ImageButtonEx(2, s_InfoIcon, buttonSize, .Zero, .Ones))
				_visibleMessageTypes ^= .Info;

			ImGui.PopStyleColor();

			if (_visibleMessageTypes.HasFlag(.Warning))
				ImGui.PushStyleColor(.Button, *col);
			else
				ImGui.PushStyleColor(.Button, .(0, 0, 0, 0));

			if (ImGui.ImageButtonEx(3, s_WarningIcon, buttonSize, .Zero, .Ones))
				_visibleMessageTypes ^= .Warning;

			ImGui.PopStyleColor();

			if (_visibleMessageTypes.HasFlag(.Error))
				ImGui.PushStyleColor(.Button, *col);
			else
				ImGui.PushStyleColor(.Button, .(0, 0, 0, 0));


			if (ImGui.ImageButtonEx(4, s_ErrorIcon, buttonSize, .Zero, .Ones))
				_visibleMessageTypes ^= .Error;

			ImGui.PopStyleColor();

			ImGui.PopStyleVar();

			ImGui.EndMenuBar();
		}
	}

	private void ShowMessages()
	{
		if (ImGui.BeginTable("Messages", 3, .BordersInnerH | .SizingFixedFit))
		{
			ImGui.TableSetupColumn("", .WidthFixed);
			ImGui.TableSetupColumn("", .WidthStretch);
			ImGui.TableSetupColumn("", .WidthFixed);

			//LogMessage lastMessage = null;
			int count = 1;

			// Message ID for ImGui
			int imGuiMessageId = 0;

			for (let message in _messages)
			{
				if (!_visibleMessageTypes.HasFlag(message.MessageType))
					continue;

				if ((message.Source.IsEngineMessage && !_showEngineMessages) || (!message.Source.IsEngineMessage && !_showGameMessages))
					continue;
				
				/*defer
				{
					lastMessage = message;
				}*/

				do
				{
					LogMessage lastMessage = (message != _messages.Back) ? _messages[@message.Index + 1] : null;

					if (_collapseMessages && lastMessage != null)
					{
						if (message.MessageType != lastMessage.MessageType)
							break;
						
						if (message.Message != lastMessage.Message)
							break;

						if (message.Source.Entity != lastMessage.Source.Entity)
							break;

						// For exceptions the stack trace is basically the only relevant thing
						if (message.Source.Exception?.StackTrace != lastMessage.Source.Exception?.StackTrace)
							break;
						
						// We collapse this message with the previous one:
						// Increment counter and go to next message.
						count++;
						continue;
					}
				}

				// Push current index as ID
				ImGui.PushID((void*)++imGuiMessageId);

				ImGui.TableNextRow();
				ImGui.TableSetColumnIndex(0);
				
				switch (message.MessageType)
				{
				case .Error:
					ImGui.Image(s_ErrorIcon, ImGui.Vec2(32, 32));
					ImGui.AttachTooltip("Error");
				case .Warning:
					ImGui.Image(s_WarningIcon, ImGui.Vec2(32, 32));
					ImGui.AttachTooltip("Warning");
				case .Info:
					ImGui.Image(s_InfoIcon, ImGui.Vec2(32, 32));
					ImGui.AttachTooltip("Info");
				case .Trace:
					ImGui.Image(s_TraceIcon, ImGui.Vec2(32, 32));
					ImGui.AttachTooltip("Trace");
				default:
					ImGui.TextUnformatted("Unknown");
				}

				ImGui.TableNextColumn();

				ImGui.BeginGroup();

				{
					// Timestamp
					ImGui.TextWrapped($"[{message.Timestamp:HH:mm:ss.fff}]");

					if (message.Source.IsEngineMessage)
					{
						ImGui.SameLine();
						ImGui.TextUnformatted("Engine");
					}

					// Show entity
					if (message.Source?.Entity != null)
					{
						ImGui.SameLine();

						Result<Entity> entity = Editor.Instance.CurrentScene.GetEntityByID(message.Source.Entity.Value);

						if (entity case .Ok(let e))
						{
							ImGui.Text($"Entity: \"{e.Name}\" (ID: {message.Source.Entity})");

							if (ImGui.IsItemClicked())
								Editor.Instance.EntityHierarchyWindow.HighlightEntity(entity);
						}
						else
						{
							ImGui.Text($"Entity: (ID: {message.Source.Entity})");
						}
					}

					if (message.Source.Exception != null)
					{
						if (ImGui.CollapsingHeader(message.Message.Ptr))
						{
							// Show the native to managed entry point only if we show engine messages

							if (_showEngineMessages)
								ImGui.TextUnformatted(message.Source.Exception.StackTrace);
							else
								ImGui.TextUnformatted(message.Source.Exception.CleanStackTrace);

							ImGui.NewLine();
						}
					}
					else
					{
						ImGui.TextUnformatted(message.Message);
					}
				}

				ImGui.EndGroup();

				if (ImGui.IsItemHovered() && ImGui.IsMouseDoubleClicked(.Left))
				{
					if (message.Source.MessageOrigin != null)
					{
						RiderIdeAdapter.OpenScript(message.Source.MessageOrigin.FileName, message.Source.MessageOrigin.LineNumber);
					}
				}
				
				// Dont show the counter if we only have one message.
				if (count > 1)
				{
					// the message is not collapsible with the previous one.
					// Print message count for last message and reset counter.
					// This message will be printed normally.

					ImGui.TableNextColumn();
					ImGui.Text($"{count}");
				}

				count = 1;

				ImGui.PopID();
			}

			if (_autoScroll)
			{
				if (ImGui.GetIO().MouseWheel > 0)
				{
					_autoScroll = false;
				}
				else
				{
					ImGui.SetScrollY(ImGui.GetScrollMaxY());
				}
			}
			else
			{
				if (ImGui.GetScrollMaxY() == ImGui.GetScrollY())
				{
					_autoScroll = true;
				}
			}

			ImGui.EndTable();
		}
	}

	public void ClearLog()
	{
		ClearAndDeleteItems!(_messages);
	}

	public void Log(DateTime timestamp, LogLevel severity, StringView message, MessageSource source)
	{
		LogMessage logMessage = new LogMessage(timestamp, message, MessageType(severity), source);
		_messages.Add(logMessage);
	}

	public void LogException(DateTime timestamp, ScriptException exception)
	{
		StringView firstLine = exception.StackTrace;

		int firstInIndex = exception.StackTrace.IndexOf("\n");

		if (firstInIndex != -1)
			firstLine = firstLine.Substring(0, firstInIndex);

		String message = scope .(128);
		message.AppendF($"Exception: \"{exception.FullName}\" | Message: \"{exception.Message}\" {firstLine}\0");

		// TODO: are mono exceptions never engine only?
		LogMessage logMessage = new LogMessage(timestamp, message, .Error, new MessageSource(){Entity = exception.EntityId, Exception = exception, IsEngineMessage = false});
		_messages.Add(logMessage);
	}
}