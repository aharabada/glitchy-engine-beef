using System;
using System.Collections.Generic;
using System.Text;

namespace GlitchyEngine.Physics;

/// <summary>
/// Describes whether the rigid body is static, dynamic or kinematic.
/// </summary>
public enum BodyType : byte
{
    /// <summary>
    /// A static body does not move under simulation and behaves as if it has infinite mass.
    /// Internally, Box2D stores zero for the mass and the inverse mass
    /// Static bodies can be moved manually by the user. A static body has zero velocity. 
    /// Static bodies do not collide with other static or kinematic bodies.
    /// </summary>
    Static = 0,
    /// <summary>
    /// A dynamic body is fully simulated. They can be moved manually by the user, but normally they move according to forces.
    /// A dynamic body can collide with all body types. A dynamic body always has finite, non-zero mass.
    /// If you try to set the mass of a dynamic body to zero, it will automatically acquire a mass of one kilogram and it won't rotate.
    /// </summary>
    Dynamic = 1,
    /// <summary>
    /// A kinematic body moves under simulation according to its velocity.
    /// Kinematic bodies do not respond to forces. They can be moved manually by the user, but normally a kinematic body is moved by setting its velocity.
    /// A kinematic body behaves as if it has infinite mass, however, Box2D stores zero for the mass and the inverse mass.
    /// Kinematic bodies do not collide with other kinematic or static bodies.
    /// </summary>
    Kinematic = 2
}
