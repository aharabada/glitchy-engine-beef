///
/// Loading and usage of an asset.
///
// Shows the usage of the Content Manager.
// An asset is loaded with Content.LoadAsset(AssetName)
// Loading an asset returns an AssetHandle.
// Usually you want to hold on to the AssetHandle.
// If you need the actual asset you can use Content.GetAsset<AssetType>(AssetHandle) to retrieve the actual asset.

/*
 * Only hold on to AssetHandle.
 * Do NOT hold actual Assets! The Asset might get invalidated
 * (e.g. reloading after the source-file changed).
 */
AssetHandle _lineEffect;

void Start()
{
    /*
     * Loading an asset returns a handle to that asset.
     */
    _lineEffect = Content.LoadAsset("Shaders\\LineEffect.hlsl");
}

void Update()
{
    // Use case 1:
    {
        // Retrieve the actual asset. Note that this Asset is only guaranteed to persist
        // for the current frame.
        Effect fx = Content.GetAsset<Effect>(_lineEffect);

        // Note: Assets are ref counted, however since they are not inteded to be held GetAsset 
        // does NOT increment the reference counter so you usually should NOT decrement it.
        // The exception is when you manually hold on to an asset (see Example below)

        // Use asset
        fx.Variables["ViewProjection"].SetData(viewProjection * transform);
        fx.Variables["Color"].SetData(color);
        fx.ApplyChanges();
        fx.Bind();
    }

    // Use case 2:
    {
        // Retrieve the actual asset.
        Effect fx = _lineEffect.Get<Effect>();

        // ...
        // Same as case 1
    }
}


///
/// Holding on to an actual asset.
///
// Shows the usage of the Content Manager when you hold a reference to the actual Asset instead of the handle.
// This should usually not be done. Eventhough it is technically fine, it has the implication, that if the
// content manager decides to reload the asset the changes will not be reflected in the held reference
// (which they would if you used GetAsset before every usage.)
// Also the content manager can't unload the asset because the reference counter wouldn't be zero.
// Though there currently is no way for the content manager to unload an asset unless it is specifically told to do so.

/*
 * Field to hold the asset.
 */
Effect _lineEffect;

void Start()
{
    // Load the Asset.
    AssetHandle handle = Content.LoadAsset("Shaders\\LineEffect.hlsl");
    // Get the actual asset.
    _lineEffect = Content.GetAsset<Effect>(handle); // Alternative: _lineEffect = handle.Get<Effect>();
    // Increment the reference counter so that the asset doesn't get unloaded.
    _lineEffect.AddRef();
}

void Destroy()
{
    // Make sure to release the asset once you don't need it anymore. Otherwise it will leak.
    _lineEffect.Release();
}

void Update()
{
    _lineEffect.Variables["ViewProjection"].SetData(viewProjection * transform);
    _lineEffect.Variables["Color"].SetData(color);
    _lineEffect.ApplyChanges();
    _lineEffect.Bind();
}
