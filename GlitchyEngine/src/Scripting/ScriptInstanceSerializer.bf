using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Serialization;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

/// Provides capability to serialize and deserialize C# objects managed by the script engine
public class ScriptInstanceSerializer
{
	append Dictionary<UUID, SerializedObject> _serializedData = .();

	public int SerializedObjectCount => _serializedData.Count;

	public Dictionary<UUID, SerializedObject> SerializedObjects => _serializedData;

	public ~this()
	{
		Clear();
		delete:append _serializedData;
	}

	public void Clear()
	{
		ClearDictionaryAndDeleteValues!(_serializedData);
		ScriptEngine.Classes.EntitySerializer.DestroySerializationContext(this);
	}

	public void Init()
	{
		ScriptEngine.Classes.EntitySerializer.CreateSerializationContext(this);
	}

	/// Serializes all script instances that are currently managed by the ScriptEngine.
	public void SerializeScriptInstances()
	{
		Debug.Profiler.ProfileFunction!();

		Init();

		for (let (id, scriptInstance) in ScriptEngine._entityScriptInstances)
		{
			SerializeScriptInstance(scriptInstance);
		}

		for (let (name, scriptClass) in ScriptEngine.EntityClasses)
		{
			SerializeStaticScriptClassFields(scriptClass);
		}
	}

	/// Serializes the given script instance.
	public void SerializeScriptInstance(ScriptInstance script)
	{
		SerializedObject object = new SerializedObject(this, false, script.ScriptClass.FullName, script.EntityId);
		object.Serialize(script);
	}

	/// Serializes the given script instance.
	public void SerializeStaticScriptClassFields(ScriptClass scriptClass)
	{
		SerializedObject object = new SerializedObject(this, true, scriptClass.FullName, null);
		object.SerializeStaticFields(scriptClass);
	}

	/// Deserializes this context into the instances currently managed by the script engine.
	public void DeserializeScriptInstances()
	{
		Debug.Profiler.ProfileFunction!();

		Init();

		for (let (id, script) in ScriptEngine._entityScriptInstances)
		{
			DeserializeScriptInstance(id, script);
		}
		
		for (let (name, scriptClass) in ScriptEngine.EntityClasses)
		{
			DeserializeStaticScriptClassFields(scriptClass);
		}
	}

	/// Deserializes the data into the given script instance, if there is data available.
	/// @returns true if the script had serialized data; false otherwise.
	public bool DeserializeScriptInstance(UUID id, ScriptInstance script)
	{
		if (_serializedData.TryGetValue(id, let object))
		{
			object.Deserialize(script);

			return true;
		}

		return false;
	}

	public bool DeserializeStaticScriptClassFields(ScriptClass scriptClass)
	{
		for (let object in _serializedData.Values)
		{
			if (object.IsStatic && object.TypeName == scriptClass.FullName)
			{
				// No data anyway, save some time.
				if (object.Fields.Count == 0)
					return false;

				object.DeserializeStaticFields(scriptClass);
				return true;
			}
		}

		return false;
	}


	/// Replaces Entity references in the given serialized data using the specified translation table.
	public void FixupSerializedIds(Dictionary<UUID, UUID> originalToCopyIds)
	{
		for (let (id, object) in _serializedData)
		{
			for (var fieldData in ref object.Fields.Values)
			{
				if (fieldData.PrimitiveType != .EntityReference && fieldData.PrimitiveType != .ComponentReference)
					continue;

				if (originalToCopyIds.TryGetValue(fieldData.Data.EngineObject.ID, let copyId))
					fieldData.Data.EngineObject.ID = copyId;
			}
		}
	}

	public SerializedObject GetSerializedObject(UUID id)
	{
		return _serializedData[id];
	}

	public bool TryGetSerializedObject(UUID id, out SerializedObject object)
	{
		return _serializedData.TryGetValue(id, out object);
	}

	public bool ContainsId(UUID id)
	{
		return _serializedData.ContainsKey(id);
	}

	internal void AddObject(SerializedObject object)
	{
		_serializedData.Add(object.Id, object);
	}	
}
