///
/// This shows the usage of a smart/typed Asset Handle.
///
// In the basic usage-patterns the user has two options:
// Either he/she holds a handle and has to query for the actual asset every time
// or he/she hold the actual asset and loses reloading capabilities.
// The idea of the auto asset is to provide a way that can provide both.

AssetHandle<Effect> _lineEffect;

void Start()
{
    /*
     * Loading an asset returns a handle to that asset.
     * The asset handle is implicitly converted to a smart AssetHandle.
     */
    _lineEffect = Content.LoadAsset("Shaders\\LineEffect.hlsl");
}

void Update()
{
    // Use case 1 (Convenience)
    {
        _lineEffect.Variables["ViewProjection"].SetData(viewProjection * transform);
        _lineEffect.Variables["Color"].SetData(color);
        _lineEffect.ApplyChanges();
        _lineEffect.Bind();
    }

    // Use case 2 (Technically more efficient)
    {
        Effect fx = _lineEffect.Get();
        fx.Variables["ViewProjection"].SetData(viewProjection * transform);
        fx.Variables["Color"].SetData(color);
        fx.ApplyChanges();
        fx.Bind();
    }
}

//
// Auto Assets use comp time to expose all the fields, Methods and properties of the actual asset.
// They will automatically check if the asset for the handle changed and update accordingly.
// This means it is more convenient to use than both basic patterns and has all benefits of both. 
//
