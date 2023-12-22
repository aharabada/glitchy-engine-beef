using Mono;
using System.Collections;
using System;
using GlitchyEngine.Core;

namespace GlitchyEngine.Scripting;

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
		default:
			return 0;
		}
	}
}

class SerializedObject
{
	public UUID Id;

	public Dictionary<UUID, SerializedObject> AllObjects;

	private List<String> _ownedString = new List<String>() ~ DeleteContainerAndItems!(_);

	public append Dictionary<StringView, (SerializationType PrimitiveType, uint8[16] Data)> Fields = .();

	public this(Dictionary<UUID, SerializedObject> allObjects)
	{
		AllObjects = allObjects;

		// Make sure we have no duplicate keys
		repeat
		{
			Id = UUID.Create();
		}
		while (AllObjects.ContainsKey(Id));

		AllObjects.Add(Id, this);
	}

	public void AddField(StringView name, SerializationType primitiveType, MonoObject* value)
	{
		uint8[16] data = .();

		if (primitiveType == .String)
		{
			MonoString* string = (.)value;
			
			char8* rawStringValue = Mono.mono_string_to_utf8(string);

			String stringValue = new String(rawStringValue);

			_ownedString.Add(stringValue);

			Mono.mono_free(rawStringValue);
			
			StringView valueView = stringValue;

			Internal.MemCpy(&data, &valueView, sizeof(StringView));
		}
		else if (primitiveType == .Enum)
		{
			MonoString* string = (.)value;
			
			char8* rawEnumValue = Mono.mono_string_to_utf8(string);

			String enumValue = new String(rawEnumValue);

			_ownedString.Add(enumValue);

			Mono.mono_free(rawEnumValue);
			
			StringView valueView = enumValue;

			Internal.MemCpy(&data, &valueView, sizeof(StringView));
		}
		else
		{
			void* rawValue = Mono.mono_object_unbox(value);

			Internal.MemCpy(&data, rawValue, primitiveType.GetSize());

			String nameCopy = new String(name);
			_ownedString.Add(nameCopy);
		}

		String nameCopy = new String(name);
		_ownedString.Add(nameCopy);
		
		Fields.Add(nameCopy, (primitiveType, data));
	}
	
	typealias SerializeMethod = function MonoObject*(MonoObject* entity, void* contextPtr, MonoException** exception);
	typealias DeserializeMethod = function MonoObject*(MonoObject* entity, void* contextPtr, MonoException** exception);

	public void Serialize(ScriptInstance scriptInstance)
	{
		SerializeMethod serialize = (SerializeMethod)ScriptEngine.Classes.EntitySerializer.GetMethodThunk("Serialize", 2);

		void* thisPtr = Internal.UnsafeCastToPtr(this);

		MonoException* exception = null;
		serialize(scriptInstance.[Friend]_instance, thisPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, scriptInstance);
	}

	public void Deserialize(ScriptInstance scriptInstance)
	{
		DeserializeMethod deserialize = (DeserializeMethod)ScriptEngine.Classes.EntitySerializer.GetMethodThunk("Serialize", 2);

		void* thisPtr = Internal.UnsafeCastToPtr(this);

		MonoException* exception = null;
		deserialize(scriptInstance.[Friend]_instance, thisPtr, &exception);

		if (exception != null)
			ScriptEngine.[Friend]HandleMonoException(exception, scriptInstance);
	}
}
