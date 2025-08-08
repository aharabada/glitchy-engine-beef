using GlitchyEngine.Core;
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace GlitchyEngine.Native;

[DebuggerDisplay("{ToString(),raw}")]
[StructLayout(LayoutKind.Sequential, Pack = 0)]
[EngineClass("System.StringView")]
internal unsafe struct StringView
{
    public byte* Utf8Ptr;
    public long Length;

    public StringView()
    {
        Utf8Ptr = null;
        Length = 0;
    }

    public StringView(byte* utf8Ptr, long length)
    {
        Utf8Ptr = utf8Ptr;
        Length = length;
    }

    public override string? ToString()
    {
        if (Utf8Ptr == null)
            return null;

        if (Length == 0)
            return string.Empty;

        if (Length is < 0 or > int.MaxValue)
        {
            throw new InvalidOperationException($"String length is invalid: {Length}.");
        }

        return Encoding.UTF8.GetString(Utf8Ptr, (int)Length);
    }

    /// <summary>
    /// Creates a String<see cref="StringView"/>View that can be passed to native code. This method allocates native memory that must be freed using
    /// <see cref="NativeMemory.Free"/>.
    /// </summary>
    /// <param name="s">The string to convert.</param>
    /// <returns>The <see cref="StringView"/> pointing to the native memory containing the UTF8-text; or null, if <see cref="s"/> was null.</returns>
    /// <remarks>
    /// The allocated string is guaranteed to have a null terminator.
    /// The null terminator is not counted into the length of the resulting <see cref="StringView"/>.
    /// </remarks>
    public static StringView FromManagedString(string? s)
    {
        if (s == null)
            return new StringView();

        int maxByteCount = Encoding.UTF8.GetMaxByteCount(s.Length);

        byte* pointer = (byte*)NativeMemory.Alloc((nuint) checked (maxByteCount + 1));
        int bytes = Encoding.UTF8.GetBytes((ReadOnlySpan<char>) s, new Span<byte>(pointer, maxByteCount));
        pointer[bytes] = (byte) 0;

        return new StringView(pointer, bytes);
    }

    public static void FreeNativeMemory(StringView s)
    {
        NativeMemory.Free(s.Utf8Ptr);
    }
}
