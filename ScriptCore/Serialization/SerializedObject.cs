using GlitchyEngine.Core;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;

namespace GlitchyEngine.Serialization;

internal class SerializedObject
{
    private IntPtr _internalContext;

    private UUID _id;

    private Stack<string> _structScope = new();

    private string _structScopeName;

    public Dictionary<object, SerializedObject> SerializedClasses;

    public SerializedObject(IntPtr internalContext, UUID id, Dictionary<object, SerializedObject> serializedClasses)
    {
        _internalContext = internalContext;
        _id = id;
        SerializedClasses = serializedClasses;
    }
    
    private (SerializedObject context, bool newContext) GetSerializedObject(object o)
    {
        SerializedObject context;

        if (SerializedClasses.TryGetValue(o, out context))
            return (context, false);
        
        ScriptGlue.Serialization_CreateObject(_internalContext, o.GetType().FullName, out IntPtr contextPtr, out UUID id);

        context = new SerializedObject(contextPtr, id, SerializedClasses);

        SerializedClasses.Add(o, context);

        return (context, true);
    }

    private void PushScope(string name)
    {
        _structScope.Push(name);

        _structScopeName += $"{name}.";
    }

    private void PopScope()
    {
        string scopeToRemove = _structScope.Pop();
        _structScopeName = _structScopeName.Remove(_structScopeName.Length - scopeToRemove.Length - 1);
    }

    private void AddField(string fieldName, SerializationType serializationType, object value, string fullTypeName = null)
    {
        string completeFieldName = $"{_structScopeName}{fieldName}";

        ScriptGlue.Serialization_SerializeField(_internalContext, serializationType, completeFieldName, value, fullTypeName);
    }

    public void Serialize(Entity entity)
    {
        SerializeFields(entity);
    }
    
    private void SerializeFields(object obj)
    {
        Type type = obj.GetType();

        foreach (FieldInfo field in type.GetFields())
        {
            if (!EntitySerializer.SerializeField(field))
                continue;

            object fieldValue = field.GetValue(obj);
            Type fieldType = fieldValue?.GetType() ?? field.FieldType;

            SerializeField(field.Name, fieldValue, fieldType);
        }
    }

    private void SerializeField(string fieldName, object fieldValue, Type fieldType)
    {
        if (fieldType.IsPrimitive)
        {
            SerializePrimitive(fieldName, fieldValue, fieldType);
        }
        else if (fieldType == typeof(string))
        {
            AddField(fieldName, SerializationType.String, fieldValue);
        }
        else if (fieldType.IsEnum)
        {
            SerializeEnum(fieldName, fieldValue, fieldType);
        }
        else if (fieldType.IsArray)
        {
            Log.Error($"Array serialization not yet implemented");
        }
        else if (fieldType.IsGenericType)
        {
            if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
            {
                //SerializeList(fieldName, type, o);
                Log.Error($"List serialization not yet implemented");
            }
            //else if (fieldType.GetGenericTypeDefinition() == typeof(Dictionary<,>))
            //{
            //    ImGui.Text($"{fieldName} Dictionary");
            //}
            else
            {
                // TODO: what to do?
                Log.Error($"Generic class serialization not yet implemented");
            }
        }
        else if (fieldType.IsValueType)
        {
            SerializeStruct(fieldName, fieldValue, fieldType);
        }
        else if (fieldType.IsClass)
        {
            SerializeClass(fieldName, fieldValue, fieldType);
        }
        else
        {
            Log.Error($"Encountered unhandled type \"{fieldType}\" while serializing.");
        }
    }

    private void SerializePrimitive(string fieldName, object fieldValue, Type fieldType)
    {
        Debug.Assert(fieldType.IsPrimitive, $"{fieldType} is not a primitive type.");

        SerializationType type = SerializationType.None;
        
        if (fieldType == typeof(bool))
            type = SerializationType.Bool;
        else if (fieldType == typeof(char))
            type = SerializationType.Char;
        else if (fieldType == typeof(byte))
            type = SerializationType.UInt8;
        else if (fieldType == typeof(sbyte))
            type = SerializationType.Int8;
        else if (fieldType == typeof(ushort))
            type = SerializationType.UInt16;
        else if (fieldType == typeof(short))
            type = SerializationType.Int16;
        else if (fieldType == typeof(uint))
            type = SerializationType.UInt32;
        else if (fieldType == typeof(int))
            type = SerializationType.Int32;
        else if (fieldType == typeof(ulong))
            type = SerializationType.UInt64;
        else if (fieldType == typeof(long))
            type = SerializationType.Int64;
        else if (fieldType == typeof(float))
            type = SerializationType.Float;
        else if (fieldType == typeof(double))
            type = SerializationType.Double;
        else if (fieldType == typeof(decimal))
            type = SerializationType.Decimal;
        else
        {
            Log.Error($"The primitive {fieldType} is not implemented.");
        }

        AddField(fieldName, type, fieldValue);
    }

    private void SerializeEnum(string fieldName, object fieldValue, Type fieldType)
    {
        AddField(fieldName, SerializationType.Enum, fieldValue.ToString());
    }

    private void SerializeStruct(string fieldName, object fieldValue, Type fieldType)
    {
        PushScope(fieldName);

        SerializeFields(fieldValue);

        PopScope();
    }

    private void SerializeClass(string fieldName, object fieldValue, Type fieldType)
    {
        if (typeof(Entity).IsAssignableFrom(fieldType))
        {
            AddField(fieldName, SerializationType.EntityReference, ((Entity)fieldValue)?.UUID ?? UUID.Zero, fieldValue?.GetType().FullName);
        }
        else if (fieldType.IsSubclassOf(typeof(Component)))
        {
            AddField(fieldName, SerializationType.ComponentReference, ((Component)fieldValue)?.UUID ?? UUID.Zero, fieldValue?.GetType().FullName);
        }
        else
        {
            if (fieldValue == null)
            {
                AddField(fieldName, SerializationType.ObjectReference, UUID.Zero);
            }
            else
            {
                var (context, newContext) = GetSerializedObject(fieldValue);

                if (newContext)
                {
                    context.SerializeFields(fieldValue);
                }

                AddField(fieldName, SerializationType.ObjectReference, context._id);   
            }
        }
    }
}