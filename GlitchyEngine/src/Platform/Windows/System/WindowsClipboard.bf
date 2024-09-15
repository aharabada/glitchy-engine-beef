#if BF_PLATFORM_WINDOWS
using System;
using DirectX.Common;
using System.Text;

using static System.Windows;

namespace GlitchyEngine.System;

extension Clipboard
{
	[CLink, CallingConvention(.Stdcall)]
	private static extern IntBool OpenClipboard(HWnd hWndNewOwner);
	[CLink, CallingConvention(.Stdcall)]
	private static extern IntBool CloseClipboard();
	[CLink, CallingConvention(.Stdcall)]
	private static extern IntBool EmptyClipboard();

	[AllowDuplicates]
	private enum ClipboardFormat : uint32
	{
		Bitmap = 2,
		Dib = 8,
		DibV5 = 17,
		Dif = 5,
		DspBitmap = 0,
		Dspenhmetafile = 0,
		DspMetaFilepict = 0,
		DspText = 0,
		Enhmetafile = 14,
		Gdiobjfirst = 0,
		Gdiobjlast = 0,
		Hdrop = 15,
		Locale = 16,
		Metafilepict = 3,
		Oemtext = 7,
		Ownerdisplay = 0,
		Palette = 9,
		Pendata = 10,
		Privatefirst = 0,
		Privatelast = 0,
		Riff = 11,
		Sylk = 4,
		Text = 1,
		Tiff = 6,
		UnicodeText = 13,
		Wave = 12
	}

	[CLink, CallingConvention(.Stdcall)]
	private static extern Handle GetClipboardData(ClipboardFormat format);
	[CLink, CallingConvention(.Stdcall)]
	private static extern Handle SetClipboardData(ClipboardFormat format, Handle memory);

	[CLink, CallingConvention(.Stdcall)]
	private static extern void* GlobalLock(Handle memory);
	[CLink, CallingConvention(.Stdcall)]
	private static extern IntBool GlobalUnlock(Handle memory);

	[AllowDuplicates]
	private enum GlobalMemoryFlags : uint32
	{
		Fixed = 0x0000,
		Moveable = 0x0002,
		ZeroInit = 0x0040,
		/// Combines Fixed and ZeroInit
		GPTR = 0x0040,
		/// Combines Moveable and ZeroInit
		GHND = 0x0042
	}

	[CLink, CallingConvention(.Stdcall)]
	private static extern Handle GlobalAlloc(GlobalMemoryFlags uFlags, int dwBytes);
	[CLink, CallingConvention(.Stdcall)]
	private static extern Handle GlobalFree(Handle memory);

	public static mixin TryLogging(IntBool result)
	{
		if (!result)
		{
			HResult hresult = HResult.FromWin32((uint32)GetLastError());
			Log.EngineLogger.Error($"{hresult.Underlying}: {hresult}");
			return;
		}
	}

	public static mixin TryLoggingSilent(IntBool result)
	{
		if (!result)
		{
			HResult hresult = HResult.FromWin32((uint32)GetLastError());
			Log.EngineLogger.Error($"{hresult.Underlying}: {hresult}");
		}
	}

	public override static void Clear()
	{
		TryLogging!(OpenClipboard(0));
		TryLogging!(EmptyClipboard());
		TryLogging!(CloseClipboard());
	}

	public override static void Read(String outBuffer)
	{
		TryLogging!(OpenClipboard(0));

		do
		{
			Handle handle = GetClipboardData(.UnicodeText);

			if (handle == 0)
				break;

			char16* clipboardData = (char16*)GlobalLock(handle);

			if (clipboardData != null)
			{
				outBuffer.Append(clipboardData);

				TryLoggingSilent!(GlobalUnlock(handle));
			}
			else
			{
				HResult hresult = HResult.FromWin32((uint32)GetLastError());
				Log.EngineLogger.Error($"{hresult.Underlying}: {hresult}");
			}
		}

		TryLogging!(CloseClipboard());
	}

	public override static void Set(StringView text)
	{
		TryLogging!(OpenClipboard(0));

		do
		{
			char16* nativeTextPtr = text.ToScopedNativeWChar!();
			Span<char16> nativeText = .(nativeTextPtr, UTF16.CStrLen(nativeTextPtr) + 1);

			Handle handle = GlobalAlloc(.Moveable, sizeof(char16) * nativeText.Length);

			if (handle == 0)
				break;

			char16* clipboardDataPtr = (char16*)GlobalLock(handle);
			Span<char16> clipboardData = .(clipboardDataPtr, nativeText.Length);

			if (clipboardDataPtr == null)
			{
				HResult hresult = HResult.FromWin32((uint32)GetLastError());
				Log.EngineLogger.Error($"{hresult.Underlying}: {hresult}");
				break;
			}
			
			nativeText.CopyTo(clipboardData);
			TryLoggingSilent!(GlobalUnlock(handle));

			TryLoggingSilent!(EmptyClipboard());

			if (SetClipboardData(.UnicodeText, handle) == 0)
			{
				HResult hresult = HResult.FromWin32((uint32)GetLastError());
				Log.EngineLogger.Error($"{hresult.Underlying}: {hresult}");

				GlobalFree(handle);
			}
		}

		TryLogging!(CloseClipboard());
	}
}

#endif
