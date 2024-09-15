using System;

namespace GlitchyEngine.System;

class Clipboard
{
	/// Clears the clipboard.
	public static extern void Clear();
	
	/// Reads a unicode text from the clipboard.
	public static extern void Read(String outBuffer);
	
	/// Sets the content of the clipboard to the given unicode text.
	public static extern void Set(StringView text);
}
