using GlitchyEngine.Core;
using System;

namespace GlitchyEngine.Serialization;

public enum SerializationType : int32
{
	case None;

	case Bool;
	
	case Char;
	case String;
	
	case Int8;
	case Int16;
	case Int32;
	case Int64;
	case UInt8;
	case UInt16;
	case UInt32;
	case UInt64;
	
	case Float;
	case Double;
	case Decimal;

	case Enum;
	
	case EntityReference;
	case ComponentReference;
	
	case ObjectReference;

	public int GetSize()
	{
		switch (this)
		{
		case .Bool:
			return 1;
		case .Char:
			return 1;
		case .Int8, .UInt8:
			return 1;
		case .Int16, .UInt16:
			return 2;
		case .Int32, .UInt32:
			return 4;
		case .Int64, .UInt64:
			return 8;
		case .Float:
			return 4;
		case .Double:
			return 8;
		case .Decimal:
			return 16;
		case .EntityReference, .ComponentReference, .ObjectReference:
			return sizeof(UUID);
		case .String:
			return sizeof(StringView);
		case .Enum:
			return sizeof(StringView);
		default:
			return 0;
		}
	}
}
