using System.Numerics;
using System.Runtime.InteropServices;

namespace DotNetScriptingHelper.Components;

[GameComponent, StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct LameTransformComponent
{
    private EcsEntity _parent;
    
    private Vector3 _position;
    private Quaternion _rotation;
    private Vector3 _scale;

    private Vector3 _editorRotationEuler;

    private Matrix4x4 _localTransform;
    private bool _isDirty;
    private Matrix4x4 _worldTransform;

    private UIntPtr _frame;
    
    public EcsEntity Parent
    {
        get => _parent;
        set
        {
            if (_parent == value)
                return;

            _parent = value;
            _isDirty = true;
        }
    }
    
    public Matrix4x4 LocalTransform
    {
        get => _localTransform;
        set
        {
            if (_localTransform == value)
                return;

            _localTransform = value;

            Matrix4x4.Decompose(_localTransform, out _position, out _rotation, out _scale);
            _isDirty = true;
        }
    }
    // Todo: WorldTransform?

    public Vector3 Position
    {
        get => _position;
        set
        {
            if (_position == value)
                return;
            
            _position = value;
            _isDirty = true;
        }
    }
    
    public Quaternion Rotation
    {
        get => _rotation;
        set
        {
            if (_rotation == value)
                return;
            
            _rotation = value;
            _isDirty = true;
        }
    }

    public (Vector3 Axis, float Angle) RotationAxisAngle
    {
        get => _rotation.ToAxisAngle();
        set
        {
            Quaternion quat = Quaternion.CreateFromAxisAngle(value.Axis, value.Angle);

            if (_rotation == quat)
                return;

            _rotation = quat;
            _isDirty = true;
        }
    }

    public Vector3 RotationEuler
    {
        get => _rotation.ToEulerAngles();
        set => Rotation = Quaternion.CreateFromYawPitchRoll(value.Y, value.X, value.Z);
    }

    public Vector3 Scale
    {
        get => _scale;
        set
        {
            if (_scale == value)
                return;

            _scale = value;
            _isDirty = true;
        }
    }
}

public unsafe struct TransformComponent
{
    [GameComponent, StructLayout(LayoutKind.Sequential, Pack = 1)]
    internal struct TransformComponentData
    {
        internal EcsEntity _parent;

        internal Vector3 _position;
        internal Quaternion _rotation;
        internal Vector3 _scale;

        internal Vector3 _editorRotationEuler;

        internal Matrix4x4 _localTransform;
        internal bool _isDirty;
        internal Matrix4x4 _worldTransform;

        internal UIntPtr _frame;
    }

    private TransformComponentData* _component;

    internal TransformComponent(IntPtr component)
    {
        _component = (TransformComponentData*)component;
    }

    public EcsEntity Parent
    {
        get => _component->_parent;
        set
        {
            if (_component->_parent == value)
                return;

            _component->_parent = value;
            _component->_isDirty = true;
        }
    }

    public Matrix4x4 LocalTransform
    {
        get => _component->_localTransform;
        set
        {
            if (_component->_localTransform == value)
                return;

            _component->_localTransform = value;

            Matrix4x4.Decompose(_component->_localTransform, 
                out _component->_position, out _component->_rotation, out _component->_scale);
            _component->_isDirty = true;
        }
    }
    // Todo: WorldTransform?

    public Vector3 Position
    {
        get => _component->_position;
        set
        {
            if (_component->_position == value)
                return;

            _component->_position = value;
            _component->_isDirty = true;
        }
    }

    public Quaternion Rotation
    {
        get => _component->_rotation;
        set
        {
            if (_component->_rotation == value)
                return;

            _component->_rotation = value;
            _component->_isDirty = true;
        }
    }

    public (Vector3 Axis, float Angle) RotationAxisAngle
    {
        get => _component->_rotation.ToAxisAngle();
        set
        {
            Quaternion quat = Quaternion.CreateFromAxisAngle(value.Axis, value.Angle);

            if (_component->_rotation == quat)
                return;

            _component->_rotation = quat;
            _component->_isDirty = true;
        }
    }

    public Vector3 RotationEuler
    {
        get => _component->_rotation.ToEulerAngles();
        set => Rotation = Quaternion.CreateFromYawPitchRoll(value.Y, value.X, value.Z);
    }

    public Vector3 Scale
    {
        get => _component->_scale;
        set
        {
            if (_component->_scale == value)
                return;

            _component->_scale = value;
            _component->_isDirty = true;
        }
    }
}
