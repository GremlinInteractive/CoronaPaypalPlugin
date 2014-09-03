//
//  config.java
//  PayPal Plugin
//
/*
The MIT License (MIT)

Copyright (c) 2014 Gremlin Interactive Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/
// ----------------------------------------------------------------------------

// Package name
package plugin.paypal;

// Java Imports
import java.util.*;

// JNLua imports
import com.naef.jnlua.LuaState;
import com.naef.jnlua.LuaType;

// Corona Imports
import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaEnvironment;

// Java/Misc Imports
import java.math.BigDecimal;
import org.json.JSONException;

// Android Imports
import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

// Paypal Imports
import com.paypal.android.sdk.payments.PayPalAuthorization;
import com.paypal.android.sdk.payments.PayPalConfiguration;
import com.paypal.android.sdk.payments.PayPalFuturePaymentActivity;
import com.paypal.android.sdk.payments.PayPalPayment;
import com.paypal.android.sdk.payments.PayPalService;
import com.paypal.android.sdk.payments.PaymentActivity;
import com.paypal.android.sdk.payments.PaymentConfirmation;

/**
 * Implements the config() function in Lua.
 * <p>
 * Used for configuring the PayPal Plugin.
 */
public class config implements com.naef.jnlua.NamedJavaFunction 
{
	/**
	 * Gets the name of the Lua function as it would appear in the Lua script.
	 * @return Returns the name of the custom Lua function.
	 */
	@Override
	public String getName()
	{
		return "config";
	}

	/**
	 * This method is called when the Lua function is called.
	 * <p>
	 * Warning! This method is not called on the main UI thread.
	 * @param luaState Reference to the Lua state.
	 *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
	 * @return Returns the number of values to be returned by the Lua function.
	 */
	@Override
	public int invoke( LuaState luaState ) 
	{
		try
		{
			// This requires an options table with the following params
			/*
				productionClientID = "XXX" (reqyured) -- The users client id for production.
				sandboxClientID = "XXX" (required - shouldn't this only be required for test mode??) -- The users client id for sandbox.
				environment = "sandbox" (optional) -- Valid values are `sandbox`, `noNetwork` and `production` -- Note: Production can only be used if the user has a valid license key.
				acceptCreditCards = true/false (optional) -- default false.
				language = "en" (optional) -- The users language/locale -- If omitted paypal will show it's views in accordance with the device's current language setting.
				rememberUser = true/false (optional) -- If set to true, paypal will remember any previous username/email/phonenumber/creditcard token entered. -- default is true.
				merchant = -- Table (required).
				{
					name = "Your Company Name", (required) -- The name of the merchant/company.
					privacyPolicyURL = "someUrl", (optional) -- The merchants privacy policy url -- default is paypals privacy policy url.
					userAgreementURL = "someUrl", (optional) -- The user agreement URL -- default is paypals user agreement url.
				},
				sandbox = -- Table (optional)
				{
					useDefaults = true/false, (optional) -- If set to true, the sandboxUserPassword and sandboxUserPin will always be pre-populated into the login fields. Default is false.
					password = "xxx", (optional) -- Password to use for sandbox if useDefaults is set to true. Default is nil.
					pin = "xxx", (optional) -- Password to use for sandbox if useDefaults is set to true. Default is nil.
				},
				user = -- table (optional)
				{
					email = "me@me.com", (optional) -- The users email to prefil the login form with.
					phoneNumber = "0873895538", (optional) -- The users phone number to prefil the login form with.
					phoneCountryCode = "+353", (optional) -- The users phone country code.
				}
			*/

			// If PayPal has not been initialized
			if ( paypal.hasCalledInit == false )
			{
				System.out.println( "Error: You must call payPal.init() before calling payPal.config()\n" );
				return 0;
			}

			// Paypal production client ID
			String productionClientID = null;
			// Paypal Sandbox client ID
			String sandboxClientID = null;
			// Accept Credit Cards bool
			boolean acceptCreditCards = false;
			// The langauge the Paypal view controllers will use
			String language = null;
			// The name of the Paypal Merchant
			String merchantName = null;
			// The Paypal merchants privacy policy URL
			String merchantPrivacyPolicyURL = "https://www.paypal.com/webapps/mpp/ua/privacy-full";
			// The Paypal merchants user agreement policy URL
			String merchantUserAgreementURL = "https://www.paypal.com/webapps/mpp/ua/useragreement-full";
			// Paypal Environment
			String environment = null;
			// Remember user
			boolean rememberUser = true;
			// Use sandbox defaults
			boolean useSandboxDefaults = false;
			// Sandbox password
			String sandboxPassword = null;
			// Sandbox Pin
			String sandboxPin = null;
			// Email
			String email = null;
			// Phone Number
			String phoneNumber = null;
			// Phone Country code
			String phoneCountryCode = null;

			// If an options table has been passed
			if ( luaState.isTable( -1 ) )
			{
				// Production ID
				luaState.getField( -1, "productionClientID" );
				if ( luaState.isString( -1 ) )
				{
					productionClientID = luaState.checkString( -1 );
				}
				else
				{
					System.out.println( "Error: productionClientID expected, got " + luaState.typeName( -1 ) + "\n" );
				}
				luaState.pop( 1 );

				// Sandbox ID
				luaState.getField( -1, "sandboxClientID" );
				if ( luaState.isString( -1 ) )
				{
					sandboxClientID = luaState.checkString( -1 );
				}
				else
				{
					System.out.println( "Error: sandboxClientID expected, got " + luaState.typeName( -1 ) + "\n" );
				}
				luaState.pop( 1 );

				// Accept Credit Cards
				luaState.getField( -1, "acceptCreditCards" );
				if ( luaState.isBoolean( -1 ) )
				{
					acceptCreditCards = luaState.checkBoolean( -1 );
				}
				luaState.pop( 1 );

				// Language
				luaState.getField( -1, "language" );
				if ( luaState.isString( -1 ) )
				{
					language = luaState.checkString( -1 );
				}
				luaState.pop( 1 );

				// Merchant
				luaState.getField( -1, "merchant" );
				if ( luaState.isTable( -1 ) )
				{
					// Merchant Name
					luaState.getField( -1, "name" );
					if ( luaState.isString( -1 ) )
					{
						merchantName = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
					
					// Merchant Privacy Policy URL
					luaState.getField( -1, "privacyPolicyURL" );
					if ( luaState.isString( -1 ) )
					{
						merchantPrivacyPolicyURL = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
					
					// Merchant User Agreement URL
					luaState.getField( -1, "userAgreementURL" );
					if ( luaState.isString( -1 ) )
					{
						merchantUserAgreementURL = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
				}
				luaState.pop( 1 );

				// Environment
				luaState.getField( -1, "environment" );
				if ( luaState.isString( -1 ) )
				{
					environment = luaState.checkString( -1 );
				}
				luaState.pop( 1 );
				
				// Remember user
				luaState.getField( -1, "rememberUser" );
				if ( luaState.isBoolean( -1 ) )
				{
					rememberUser = luaState.checkBoolean( -1 );
				}
				luaState.pop( 1 );

				// Sandbox
				luaState.getField( -1, "sandbox" );
				
				// If sandbox is a table
				if ( luaState.isTable( -1 ) )
				{
					// Use defaults
					luaState.getField( -1, "useDefaults" );
					if ( luaState.isBoolean( -1 ) )
					{
						useSandboxDefaults = luaState.checkBoolean( -1 );
					}
					luaState.pop( 1 );
					
					// Sandbox password
					luaState.getField( -1, "password" );
					if ( luaState.isString( -1 ) )
					{
						sandboxPassword = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
					
					// Sandbox pin
					luaState.getField( -1, "pin" );
					if ( luaState.isString( -1 ) )
					{
						sandboxPin = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
				}
				luaState.pop( 1 );

				// User
				luaState.getField( -1, "user" );
				
				// If user is a table
				if ( luaState.isTable( -1 ) )
				{
					// Email
					luaState.getField( -1, "email" );
					if ( luaState.isString( -1 ) )
					{
						email = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
					
					// Phone Number
					luaState.getField( -1, "phoneNumber" );
					if ( luaState.isString( -1 ) )
					{
						phoneNumber = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
					
					// Phone Country Code
					luaState.getField( -1, "phoneCountryCode" );
					if ( luaState.isString( -1 ) )
					{
						phoneCountryCode = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
				}
				// Pop the user and options table
				luaState.pop( 2 );
			}
			// No options table passed in
			else
			{
				System.out.println( "Error: payPal.config(), options table expected, got " + luaState.typeName( -1 ) );
			}

			// The PayPal Environment string
			String paypalEnvironment = null;
			// The client id, set differently if mode is sandbox or production
			String theClientID = null;

			// Connect PayPal to the specified environment
			if ( environment.equalsIgnoreCase( "sandbox" ) ) 
			{
				// Set the client id to the sandbox client id
				theClientID = sandboxClientID;
				// Set the environment
				paypalEnvironment = PayPalConfiguration.ENVIRONMENT_SANDBOX;
			}
			if ( environment.equalsIgnoreCase( "noNetwork" ) )
			{
				// Set the client id to the sandbox client id
				theClientID = sandboxClientID;
				// Set the environment
				paypalEnvironment = PayPalConfiguration.ENVIRONMENT_NO_NETWORK;
			}
			if ( environment.equalsIgnoreCase( "production" ) )
			{
				// Set the client id to the production client id
				theClientID = productionClientID;
				// Set the environment
				paypalEnvironment = PayPalConfiguration.ENVIRONMENT_PRODUCTION;
			}

			// Create a paypal configuration object
    		PayPalConfiguration payPalConfig = new PayPalConfiguration()
            .environment( paypalEnvironment )
            .clientId( theClientID )
            // Set user defaults
            .defaultUserEmail( email )
            .defaultUserPhone( phoneNumber )
            .defaultUserPhoneCountryCode( phoneCountryCode )
            // Set PayPal config options
            .acceptCreditCards( acceptCreditCards )
            .languageOrLocale( language )
            .merchantName( merchantName )
            .merchantPrivacyPolicyUri( Uri.parse( merchantPrivacyPolicyURL ) )
            .merchantUserAgreementUri( Uri.parse( merchantUserAgreementURL ) )
            .rememberUser( rememberUser )
            // Set sandbox options
            .forceDefaultsOnSandbox( useSandboxDefaults )
            .sandboxUserPin( sandboxPin )
            .sandboxUserPassword( sandboxPassword );

            // If we are using sandbox defaults
			if ( useSandboxDefaults == true )
			{
				// Sandbox password
				if ( sandboxPassword == null )
				{
					System.out.println( "Error: You have set sandbox useDefaults to true, but have not specified a password in your sandbox table\n " );
				}
				
				// Sandbox pin
				if ( sandboxPin == null )
				{
					System.out.println( "Error: You have set sandbox useDefaults to true, but have not specified a pin in your sandbox table\n " );
				}
			}

			/*
			  // Setting the languageOrLocale property is optional.
			  //
			  // If you do not set languageOrLocale, then the PayPalPaymentViewController will present
			  // its user interface according to the device's current language setting.
			  //
			  // Setting languageOrLocale to a particular language (e.g., @"es" for Spanish) or
			  // locale (e.g., @"es_MX" for Mexican Spanish) forces the PayPalPaymentViewController
			  // to use that language/locale.
			  //
			  // For full details, including a list of available languages and locales, see PayPalPaymentViewController.h.
			*/

			// Corona Activity
			CoronaActivity coronaActivity = null;
			if ( CoronaEnvironment.getCoronaActivity() != null )
			{
				coronaActivity = CoronaEnvironment.getCoronaActivity();
			}

			// If we have non null production and sandbox ID, then lets initialize Paypal
			if ( productionClientID != null && sandboxClientID != null )
			{				
				// Initialize paypal
				Intent paypalIntent = new Intent( coronaActivity, PayPalService.class );
			    paypalIntent.putExtra( PayPalService.EXTRA_PAYPAL_CONFIGURATION, payPalConfig );
			    coronaActivity.startService( paypalIntent );

			    // We have called config.
			    paypal.hasCalledConfig = true;
			}
		}
		catch( Exception ex )
		{
			// An exception will occur if given an invalid argument or no argument. Print the error.
			ex.printStackTrace();
		}
		
		return 0;
	}
}
