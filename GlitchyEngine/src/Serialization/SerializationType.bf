using GlitchyEngine.Core;
using System;
using Bon;

namespace GlitchyEngine.Serialization;

[BonTarget]
public enum SerializationType : uint32
{
	case None = 0;

	case Bool = 1 << 31;

	case TextTypes = 1 << 30;

	case Char = TextTypes | 1;
	case String = TextTypes | 2;

	case Number = 1 << 29;
	case Integer = Number | 1 << 28;

	case Int8 = Integer | 1;
	case Int16 = Integer | 2;
	case Int32 = Integer | 3;
	case Int64 = Integer | 4;
	case UInt8 = Integer | 5;
	case UInt16 = Integer | 6;
	case UInt32 = Integer | 7;
	case UInt64 = Integer | 8;
	
	case FloatingPoint = Number | 1 << 27;

	case Float = FloatingPoint | 1;
	case Double = FloatingPoint | 2;
	case Decimal = FloatingPoint | 3;

	case Enum = 1 << 26;
	
	case EngineObjectReference = 1 << 25;
	
	case ObjectReference = 1 << 24;

	public int GetSize()
	{
		switch (this)
		{
		case .Bool:
			return 1;
		case .Char:
			return 2;
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
		case .EngineObjectReference:
			return sizeof(UUID);
		case .ObjectReference:
			return sizeof(UUID);
		case .String:
			return sizeof(StringView);
		case .Enum:
			return sizeof(StringView);
		default:
			return 0;
		}
	}

	public bool IsNumber => this.HasFlag(.Number);
	public bool IsInteger => this.HasFlag(.Integer);
	public bool IsFloatpoint => this.HasFlag(.FloatingPoint);

	public bool CanConvertTo(SerializationType destinationType)
	{
		if (this.IsNumber && destinationType.IsNumber)
			return true;

		return false;
	}
}
