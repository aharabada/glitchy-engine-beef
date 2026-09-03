using System;
using GlitchyEngine.Core;
using System.Collections;

namespace GlitchyEngine.Scripting;

public class ScriptException
{
	private String _fullName ~ delete:append _;

	private String _message ~ delete:append _;

	private StackTrace _stackTrace ~ delete _;

	public StringView FullName => _fullName;
	public StringView Message => _message;

	public StackTrace StackTrace => _stackTrace;

	public UUID EntityId { get; private set; }

	[AllowAppend]
	public this(UUID entityId, StringView fullExceptionClassName, StringView message, StackTrace ownStackTrace)
	{
		String allocFullExceptionClassName = append String(fullExceptionClassName);
		String allocMessage = append String(message);

		EntityId = entityId;

		_stackTrace = ownStackTrace;

		_fullName = allocFullExceptionClassName;
		_message = allocMessage;
	}
}

public class StackFrameInfo
{
	private String _fileName ~ delete:append _;
	private String _methodSignature ~ delete:append _;
	public int Line;
	public int Column;

	public StringView FileName => _fileName;

	public StringView MethodSignature => _methodSignature;

	[AllowAppend]
	public this(StringView fileName, StringView methodSignature, int line, int column)
	{
		String allocFileName = append String(fileName);
		String allocMethodSignature = append String(methodSignature);

		_fileName = allocFileName;
		_methodSignature = allocMethodSignature;

		Line = line;
		Column = column;
	}

	public override void ToString(String outBuffer)
	{
		outBuffer.Append("at ");

		if (MethodSignature.IsEmpty)
			outBuffer.Append("<unknown>");
		else
			outBuffer.Append(MethodSignature);

		outBuffer.Append(" in ");

		if (!_fileName.IsEmpty)
			outBuffer.AppendF($"{FileName}, line {Line}:{Column}");
		else
			outBuffer.Append("<unknown>");
	}
}

public class StackTrace
{
	private List<StackFrameInfo> _stackFrameInfos ~ DeleteContainerAndItems!(_);

	public Span<StackFrameInfo> Frames => _stackFrameInfos;

	public this(List<StackFrameInfo> ownStackFrameInfos)
	{
		_stackFrameInfos = ownStackFrameInfos;
	}
	
	[Commutable]
	public static bool operator ==(StackTrace a, StackTrace b)
	{
		if (a == null || b == null)
			return a === b;

		return a._stackFrameInfos.Equals(b._stackFrameInfos);
	}

	public override void ToString(String outBuffer)
	{
		for (let frame in _stackFrameInfos)
		{
			frame.ToString(outBuffer);
			outBuffer.Append('\n');
		}
	}
}
