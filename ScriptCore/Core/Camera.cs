using System;

namespace GlitchyEngine.Core;

/// <summary>
/// The type of projection used by a camera.
/// </summary>
public enum ProjectionType : byte
{
    /// <summary>
    /// An orthographic projection.
    /// </summary>
    Orthographic = 0,
    /// <summary>
    /// A perspective projection.
    /// </summary>
    Perspective = 1,
    /// <summary>
    /// A perspective projection where the far plane is infinitely far away from the camera.
    /// </summary>
    InfinitePerspective = 2
}

/// <summary>
/// A component representing a camera that is attached to the entity.
/// </summary>
public class Camera : Component
{
    /// <summary>
    /// The projection type of the <see cref="Camera"/>.
    /// </summary>
    public ProjectionType ProjectionType
    {
        get
        {
            ScriptGlue.Camera_GetProjectionType(_uuid, out ProjectionType projectionType);

            return projectionType;
        }
        set => ScriptGlue.Camera_SetProjectionType(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the Y field of view in perspective mode.
    /// </summary>
    public float PerspectiveFovY
    {
        get
        {
            ScriptGlue.Camera_GetPerspectiveFovY(_uuid, out float fovY);
            return fovY;
        }
        set => ScriptGlue.Camera_SetPerspectiveFovY(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the X field of view in perspective mode.
    /// </summary>
    public float PerspectiveFovX
    {
        get => PerspectiveFovY * AspectRatio;
        set => PerspectiveFovY = value / AspectRatio;
    }

    /// <summary>
    /// Gets or sets the near plane distance in perspective mode.
    /// </summary>
    public float PerspectiveNearPlane
    {
        get
        {
            ScriptGlue.Camera_GetPerspectiveNearPlane(_uuid, out float nearPlane);
            return nearPlane;
        }
        set => ScriptGlue.Camera_SetPerspectiveNearPlane(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the far plane distance in perspective mode.
    /// </summary>
    public float PerspectiveFarPlane
    {
        get
        {
            ScriptGlue.Camera_GetPerspectiveFarPlane(_uuid, out float farPlane);
            return farPlane;
        }
        set => ScriptGlue.Camera_SetPerspectiveFarPlane(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the orthographic height.
    /// </summary>
    public float OrthographicHeight
    {
        get
        {
            ScriptGlue.Camera_GetOrthographicHeight(_uuid, out float height);
            return height;
        }
        set => ScriptGlue.Camera_SetOrthographicHeight(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the near plane distance in orthographic mode.
    /// </summary>
    public float OrthographicNearPlane
    {
        get
        {
            ScriptGlue.Camera_GetOrthographicNearPlane(_uuid, out float nearPlane);
            return nearPlane;
        }
        set => ScriptGlue.Camera_SetOrthographicNearPlane(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the far plane distance in orthographic mode.
    /// </summary>
    public float OrthographicFarPlane
    {
        get
        {
            ScriptGlue.Camera_GetOrthographicFarPlane(_uuid, out float farPlane);
            return farPlane;
        }
        set => ScriptGlue.Camera_SetOrthographicFarPlane(_uuid, value);
    }

    /// <summary>
    /// Gets or sets the aspect ratio.
    /// </summary>
    /// <exception cref="ArgumentException">The setter throws an <see cref="ArgumentException"/>, when <see langword="value"/> is zero.</exception>
    public float AspectRatio
    {
        get
        {
            ScriptGlue.Camera_GetAspectRatio(_uuid, out float aspectRatio);
            return aspectRatio;
        }
        set
        {
            if (value == 0)
                throw new ArgumentException($"{AspectRatio} must not be zero.");

            ScriptGlue.Camera_SetAspectRatio(_uuid, value);
        }
    }

    /// <summary>
    /// Gets or sets a value indicating whether the aspect ratio is fixed.
    /// </summary>
    public bool FixedAspectRatio
    {
        get
        {
            ScriptGlue.Camera_GetFixedAspectRatio(_uuid, out bool fixedAspectRatio);
            return fixedAspectRatio;
        }
        set => ScriptGlue.Camera_SetFixedAspectRatio(_uuid, value);
    }
}
