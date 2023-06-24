using Mono;
using GlitchyEngine.Core;
using System;

namespace GlitchyEngine.Scripting;

class ScriptInstance : RefCounter
{
	private ScriptClass _scriptClass;

	private MonoObject* _instance;
	private uint32 _gcHandle;

	public ScriptClass ScriptClass => _scriptClass;
	
	/// Gets whether or not the instance has ben initialized.
	public bool IsInitialized => _instance != null;

	/// Gets whether or not the Create-Method of this instance has been called before.
	public bool IsCreated => _isCreated;
	
	private bool _isCreated = false;

	public this(ScriptClass scriptClass)
	{
		Log.EngineLogger.AssertDebug(scriptClass != null);
		_scriptClass = scriptClass..AddRef();
	}

	private ~this()
	{
		if (_instance != null)
		{
			_scriptClass.OnDestroy(_instance);
			Mono.mono_gchandle_free(_gcHandle);
		}
		_scriptClass?.ReleaseRef();
	}

	public void Instantiate(UUID uuid)
	{
		_instance = _scriptClass.CreateInstance(uuid);
		_gcHandle = Mono.mono_gchandle_new(_instance, true);
	}

	public void InvokeOnCreate()
	{
		_scriptClass.OnCreate(_instance);
		_isCreated = true;
	}

	public void InvokeOnUpdate(float deltaTime)
	{
		_scriptClass.OnUpdate(_instance, deltaTime);
	}

	public void InvokeOnDestroy()
	{
		_scriptClass.OnDestroy(_instance);
	}

	public T GetFieldValue<T>(ScriptField field)
	{
		return _scriptClass.GetFieldValue<T>(_instance, field.[Friend]_monoField);
	}

	public void SetFieldValue<T>(ScriptField field, in T value)
	{
		_scriptClass.SetFieldValue<T>(_instance, field.[Friend]_monoField, value);
	}

	public void CopyEditorFieldsTo(ScriptInstance target)
	{
		for (let (fieldName, field) in ScriptClass.Fields)
		{
			switch (field.FieldType)
			{
			case .Bool:
				var value = GetFieldValue<bool>(field);
				target.SetFieldValue(field, value);

			case .SByte:
				var value = GetFieldValue<int8>(field);
				target.SetFieldValue(field, value);
			case .Short:
				var value = GetFieldValue<int16>(field);
				target.SetFieldValue(field, value);
			case .Int:
				var value = GetFieldValue<int32>(field);
				target.SetFieldValue(field, value);
			case .Long:
				var value = GetFieldValue<int64>(field);
				target.SetFieldValue(field, value);

			case .Byte:
				var value = GetFieldValue<uint8>(field);
				target.SetFieldValue(field, value);
			case .UShort:
				var value = GetFieldValue<uint16>(field);
				target.SetFieldValue(field, value);
			case .UInt:
				var value = GetFieldValue<uint32>(field);
				target.SetFieldValue(field, value);
			case .ULong:
				var value = GetFieldValue<uint64>(field);
				target.SetFieldValue(field, value);

			case .Float:
				var value = GetFieldValue<float>(field);
				target.SetFieldValue(field, value);

			/*case .float2:
				GetFieldValue<float2>(field, var value);
				if (ImGui.Editfloat2(fieldName, ref value))
					SetFieldValue(field, value);
			case .float3:
				GetFieldValue<float3>(field, var value);
				if (ImGui.Editfloat3(fieldName, ref value))
					SetFieldValue(field, value);
			case .float4:
				GetFieldValue<float4>(field, var value);
				if (ImGui.Editfloat4(fieldName, ref value))
					SetFieldValue(field, value);

			case .Double:
				var value = GetFieldValue<double>(field);
				if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .Double, &value))
					SetFieldValue(field, value);

			case .Entity:
				// TODO!
				
			case .Class:
				// TODO!
			case .Enum:
				// TODO!
			case .Struct:
				// TODO!*/
			/*case .Struct:
				ShowStructFields();
				{
					
					uint8[128] bla = ?;
					GetFieldValue<uint8[128]>(scriptField);

					Mono.MonoObject* dings = (Mono.MonoObject*)&bla;

					//ShowFields
				}*/
			default:
				Log.EngineLogger.Error($"Unhandled field type {field.FieldType}");
			}
		}
	}
}