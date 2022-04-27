using System.Numerics;
using DotNetScriptingHelper.Components;

namespace DotNetScriptingHelper;

public class TestEntityScript : ScriptableEntity
{
    private TransformComponent _transform;

    public override void OnCreate()
    {
        _transform = GetTransform();
    }

    protected override void OnUpdate(GameTime gameTime)
    {
        float f = (float)Math.Sin(gameTime.TotalSeconds);
        
        Vector3 pos = _transform.Position;

        pos.Y = f;

        _transform.Position = pos;

        float fx = MathF.Sin(gameTime.TotalSeconds * 2) / 2 + 1;
        float fy = MathF.Cos(gameTime.TotalSeconds * 2) / 2 + 1;

        Vector3 scl = _transform.Scale;

        scl.X = fx;
        scl.Y = fy;

        _transform.Scale = scl;

        float fr = MathF.Cos(gameTime.TotalSeconds / 4) * MathF.PI * 10;
        
        _transform.Rotation = Quaternion.CreateFromYawPitchRoll(0, 0, fr);
    }
}
