using GlitchyEngine.Core;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using GlitchyEngine.Extensions;

namespace GlitchyEngine.Serialization;

public class SerializedObject
{
    private IntPtr _internalContext;

    private UUID _id;

    private Dictionary<object, SerializedObject> _serializedClasses;

    private Stack<string> _structScope = new();

    private string _structScopeName = "";

    private bool _isStatic;
    
    private delegate void SerializeMethod(SerializedObject container, string fieldName, object? fieldValue, Type fieldType);

    private static Dictionary<Type, SerializeMethod> _customSerializers = new();

    public UUID Id => _id;

    public bool IsStatic => _isStatic;
    
    public SerializedObject(IntPtr internalContext, bool isStatic, UUID id, Dictionary<object, SerializedObject> serializedClasses)
    {
        _internalContext = internalContext;
        _isStatic = isStatic;
        _id = id;
        _serializedClasses = serializedClasses;
    }
    
    public (SerializedObject context, bool newContext) GetSerializedObject(object o)
    {
        SerializedObject context;

        if (_serializedClasses.TryGetValue(o, out context))
            return (context, false);
        
        ScriptGlue.Serialization_CreateObject(_internalContext, false, o.GetType().ToString(), out IntPtr contextPtr, out UUID id);

        context = new SerializedObject(contextPtr, false, id, _serializedClasses);

        _serializedClasses.Add(o, context);

        return (context, true);
    }

    static SerializedObject()
    {
        foreach (Type type in TypeExtension.EnumerateAllTypes())
        {
            if (type.TryGetCustomAttribute<CustomSerializerAttribute>(out var attribute))
            {
                MethodInfo? serializeMethod = type.GetMethod("Serialize", BindingFlags.Static | BindingFlags.Public,
                    null,
                    new[] { typeof(SerializedObject), typeof(string), typeof(object), typeof(Type) }, null);

                if (serializeMethod == null)
                {
                    Log.Error($"No Serialize-method found for type {type}");
                }
                else
                {
                    SerializeMethod method = serializeMethod.GetDelegate<SerializeMethod>();

                    _customSerializers.Add(attribute.Type, method);
                }
            }
        }
    }

    public void PushScope(string name)
    {
        _structScope.Push(name);

        _structScopeName += $"{name}.";
    }

    public void PopScope()
    {
        string scopeToRemove = _structScope.Pop();
        _structScopeName = _structScopeName.Remove(_structScopeName.Length - scopeToRemove.Length - 1);
    }

    public void AddField(string fieldName, SerializationType serializationType, object? value, string? fullTypeName = null)
    {
        string completeFieldName = $"{_structScopeName}{fieldName}";

        ScriptGlue.Serialization_SerializeField(_internalContext, serializationType, completeFieldName, value, fullTypeName);
    }
    
    public void AddValueTypeField<T>(string fieldName, SerializationType serializationType, in T value, string? fullTypeName = null) where T : unmanaged
    {
        string completeFieldName = $"{_structScopeName}{fieldName}";

        ScriptGlue.Serialization_SerializeValueType(_internalContext, serializationType, completeFieldName, value, fullTypeName);
    }

    public void Serialize(Entity entity)
    {
        SerializeInstanceFields(entity);
    }

    public void Serialize(Type type)
    {
        SerializeStaticTypeFields(type);
    }
    
    public void SerializeInstanceFields(object obj)
    {
        Type type = obj.GetType();

        foreach (FieldInfo field in type.GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public))
        {
            if (!EntitySerializer.SerializeField(field, false))
                continue;

            object? fieldValue = field.GetValue(obj);
            Type fieldType = fieldValue?.GetType() ?? field.FieldType;

            SerializeField(field.Name, fieldValue, fieldType);
        }
    }
    
    public void SerializeStaticTypeFields(Type type)
    {
        foreach (FieldInfo field in type.GetFields(BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public))
        {
            if (!EntitySerializer.SerializeField(field, true))
                continue;

            object? fieldValue = field.GetValue(null);
            Type fieldType = fieldValue?.GetType() ?? field.FieldType;

            SerializeField(field.Name, fieldValue, fieldType);
        }
    }

    private bool TryCustomSerializer(string fieldName, object? fieldValue, Type fieldType)
    {
        try
        {
            // Try to match the concrete type first (e.g. Foo -> Foo and Foo<Bar> -> List<Bar>)
            // Note: Foo<Bar> wont match a serializer for Foo<>
            if (_customSerializers.TryGetValue(fieldType, out SerializeMethod serializeMethod))
            {
                serializeMethod(this, fieldName, fieldValue, fieldType);
                return true;
            }

            if (fieldType.IsGenericType && _customSerializers.TryGetValue(fieldType.GetGenericTypeDefinition(), out serializeMethod))
            {
                serializeMethod(this, fieldName, fieldValue, fieldType);
                return true;
            }
        }
        catch (Exception e)
        {
            Log.Exception(e);
            // Don't attempt to use any other serializer after this error...
            return true;
        }

        return false;
    }

    public void SerializeField(string fieldName, object? fieldValue, Type fieldType)
    {
        if (fieldType.IsPrimitive || fieldType == typeof(decimal))
        {
            // Primitives can't be null
            SerializePrimitive(fieldName, fieldValue!, fieldType);
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
            Array? myArray = fieldValue as Array;
        
            if (myArray?.Rank > 1)
            {
                throw new NotImplementedException("Serializing multidimensional arrays is not yet supported.");
            }

            SerializeList(fieldName, fieldValue, fieldType, fieldType.GetElementType()!);
        }
        else if (fieldType.IsGenericType)
        {
            if (TryCustomSerializer(fieldName, fieldValue, fieldType))
                return;

            if (fieldType.GetGenericTypeDefinition() == typeof(List<>))
            {
                SerializeList(fieldName, fieldValue, fieldType, fieldType.GetGenericArguments()[0]);
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
            if (TryCustomSerializer(fieldName, fieldValue, fieldType))
                return;

            // Value Types cant be null
            SerializeStruct(fieldName, fieldValue!, fieldType);
        }
        else if (fieldType.IsClass)
        {
            if (TryCustomSerializer(fieldName, fieldValue, fieldType))
                return;

            SerializeClass(fieldName, fieldValue, fieldType);
        }
        else
        {
            Log.Error($"Encountered unhandled type \"{fieldType}\" while serializing.");
        }
    }

    public void SerializeList(string fieldName, object? listObject, Type fieldType, Type elementType)
    {
        if (listObject == null)
        {
            AddValueTypeField(fieldName, SerializationType.ObjectReference, UUID.Zero);
        }
        else
        {
            Debug.Assert(listObject is IList);

            var (context, newContext) = GetSerializedObject(listObject);

            if (newContext)
            {
                IList list = (IList)listObject;

                context.AddValueTypeField("Count", SerializationType.Int32, list.Count);

                for (int i = 0; i < list.Count; i++)
                {
                    object element = list[i];

                    context.SerializeField($"{i}", element, element?.GetType() ?? elementType);
                }
            }
 
            AddValueTypeField(fieldName, SerializationType.ObjectReference, context._id);
        }
    }

    public void SerializePrimitive(string fieldName, object fieldValue, Type fieldType)
    {
        if (fieldType == typeof(bool))
            AddValueTypeField(fieldName, SerializationType.Bool, (bool)fieldValue);
        else if (fieldType == typeof(char))
            AddValueTypeField(fieldName, SerializationType.Char, (char)fieldValue);
        else if (fieldType == typeof(byte))
            AddValueTypeField(fieldName, SerializationType.UInt8, (byte)fieldValue);
        else if (fieldType == typeof(sbyte))
            AddValueTypeField(fieldName, SerializationType.Int8, (sbyte)fieldValue);
        else if (fieldType == typeof(ushort))
            AddValueTypeField(fieldName, SerializationType.UInt16, (ushort)fieldValue);
        else if (fieldType == typeof(short))
            AddValueTypeField(fieldName, SerializationType.Int16, (short)fieldValue);
        else if (fieldType == typeof(uint))
            AddValueTypeField(fieldName, SerializationType.UInt32, (uint)fieldValue);
        else if (fieldType == typeof(int))
            AddValueTypeField(fieldName, SerializationType.Int32, (int)fieldValue);
        else if (fieldType == typeof(ulong))
            AddValueTypeField(fieldName, SerializationType.UInt64, (ulong)fieldValue);
        else if (fieldType == typeof(long))
            AddValueTypeField(fieldName, SerializationType.Int64, (long)fieldValue);
        else if (fieldType == typeof(float))
            AddValueTypeField(fieldName, SerializationType.Float, (float)fieldValue);
        else if (fieldType == typeof(double))
            AddValueTypeField(fieldName, SerializationType.Double, (double)fieldValue);
        else if (fieldType == typeof(decimal))
            AddValueTypeField(fieldName, SerializationType.Decimal, (decimal)fieldValue);
        else
        {
            Log.Error($"The primitive {fieldType} is not implemented.");
        }
    }

    public void SerializeEnum(string fieldName, object? fieldValue, Type fieldType)
    {
        AddField(fieldName, SerializationType.Enum, fieldValue?.ToString());
    }

    public void SerializeStruct(string fieldName, object fieldValue, Type fieldType)
    {
        PushScope(fieldName);

        SerializeInstanceFields(fieldValue);

        PopScope();
    }

    public void SerializeClass(string fieldName, object? fieldValue, Type fieldType)
    {
        if (fieldType.IsSubclassOf(typeof(EngineObject)))
        {
            AddValueTypeField(fieldName, SerializationType.ObjectReference, ((EngineObject?)fieldValue)?.UUID ?? UUID.Zero, fieldValue?.GetType().FullName);
        }
        else
        {
            if (fieldValue == null)
            {
                AddValueTypeField(fieldName, SerializationType.ObjectReference, UUID.Zero);
            }
            else
            {
                var (context, newContext) = GetSerializedObject(fieldValue);

                if (newContext)
                {
                    context.SerializeInstanceFields(fieldValue);
                }

                AddValueTypeField(fieldName, SerializationType.ObjectReference, context._id);
            }
        }
    }
}
