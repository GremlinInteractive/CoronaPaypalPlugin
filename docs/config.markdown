#### Overview

Configures the PayPal library. This function is required and must be executed before making any calls to `PayPal.show`. This configures PayPal with various properties such as your production/sandbox client IDs, language, and more.

## Syntax

`````
PayPal.config( options )
`````

This function accepts a single argument, `options`, which is a table that accepts the following parameters:

##### productionClientID - (required)

__[String]__ Your PayPal client ID for production, gathered from the [PayPal Developer](https://developer.paypal.com/webapps/developer/index) site.

##### sandboxClientID - (required)

__[String]__ Your PayPal client ID for sandbox, gathered from the [PayPal Developer](https://developer.paypal.com/webapps/developer/index) site.

##### environment - (optional)

__[String]__ The PayPal environment you wish to use. Valid values are `"sandbox"`, `"noNetwork"` and `"production"`. Use `"production"` to handle real money, `"sandbox"` to use your test credentials and communicate with PayPal's sandbox servers, or `"noNetwork"` to test without communicating with PayPal's servers.

##### acceptCreditCards - (optional)

__[Boolean]__ This value determines whether or not you allow credit card payments. If set to `true`, your app will allow payment by credit card and allow users to pay by scanning their credit card with the device's camera. If set to `false`, your app will only allow payments via a registered PayPal account. Default is `true`.

##### language - (optional)

__[String]__ The users language/locale. If omitted, PayPal will show its views according to the device's current language setting.

##### rememberUser - (optional)

__[Boolean]__ If set to `true`, PayPal will remember any previous user name, email, or phone number entered. Default is `true`.

##### merchant - (required)

__[Table]__ A required table of values used to set the PayPal merchant details. Valid properties include:

*   `name` the merchant name (required).
*   `privacyPolicyURL` an optional URL to the merchant's privacy policy. Defaults to PayPal's privacy policy URL.
*   `userAgreementPolicyURL` an optional URL to the merchant's user agreement. Defaults to PayPal's user agreement URL.

##### sandbox - (optional)

__[Table]__ An optional table of values used to set your PayPal sandbox default values. Valid properties include:

*   `useDefaults` an optional boolean value. If set to `true`, the sandbox password and PIN will be <nobr>pre-filled</nobr> in the login fields. Default is `false`.
*   `password` password in string format to use for the sandbox if `useDefaults` is set to `true`. Default is none.
*   `pin` PIN in string format to use for the sandbox if `useDefaults` is set to `true`. Default is none.

##### user - (optional)

__[Table]__ An optional table of values used to pre-fill the user's `email`, `phoneNumber` or `phoneCountryCode` properties. Valid properties include:

*   `email` an optional PayPal account email to pre-fill the login form with. Default is none.
*   `phoneNumber` an optional PayPal account phone number to pre-fill the login form with. Default is none.
*   `phoneCountryCode` an optional PayPal account phone country code to pre-fill the login form with. Default is none.

## Validation

Note that if your developer credentials are **invalid**, you will see an error in the `Xcode Organizer` or `adb logcat`.

[Xcode Organizer]

    PayPal SDK: Request has failed with error: invalid_client - System error (invalid_client). Please try again later. (401) | PayPal Debug-ID: 0d1db967d8a9b | Details: (
        {
            "error_description" = "The client credentials are invalid";
        }

[adb logcat]

    E/paypal.sdk(29823): request failed with server response:{"error":"invalid_client","error_description":"The client credentials are invalid"}
    E/PayPalService(29823): invalid_client

## Example

    -- Require the PayPal library
    local PayPal = require( "plugin.paypal" )

    -- Configure Paypal
    PayPal.config(
    {
        productionClientID = "Your_Production_Client_ID_Here",
        sandboxClientID = "Your_Sandbox_Client_ID_Here",
        acceptCreditCards = true,  --accept payments by card
        language = "en",  --sets the language to English
        merchant =
        {
            name = "Your_Company_Name_Here",
            privacyPolicyURL = "Url_To_Your_Privacy_Policy", 
            userAgreementURL = "Url_To_Your_User_Agreement"
        },
        rememberUser = false,  --don't remember the user's details
        environment = "sandbox",  --sets the environment to sandbox
        sandbox =
        {
            useDefaults = true,
            password = "Your_Sandbox_Password_Here",
            pin = "Your_Sandbox_Pin_Here"
        },
        user = 
        {
            email = "User_Paypal_Email_Address_Here",
            phoneNumber = "User_Phone_Number_Here",
            phoneCountryCode = "User_Phone_Country_Code_Here"
        }
    })