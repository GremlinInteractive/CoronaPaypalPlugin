To use this plugin, add an entry into the plugins table of build.settings. When added, the build server will integrate the plugin during the build phase.

    settings =
    {
        plugins =
        {
            ["plugin.paypal"] =
            {
                publisherId = "com.gremlininteractive"
            },
        },      
    }

For Android, the following permissions/features are automatically added when using this plugin:

    android =
    {
        usesPermissions =
        {
            "android.permission.INTERNET",
            "android.permission.ACCESS_NETWORK_STATE",
            "android.permission.ACCESS_WIFI_STATE",
            "android.permission.CAMERA",  --used for card scanning
            "android.permission.VIBRATE",  --vibration occurs when card scanner successfully scans a credit card
        },
        usesFeatures =
        {
            { name="android.hardware.camera", required=false },
            { name="android.hardware.camera.autofocus", required=false }
        },
    },