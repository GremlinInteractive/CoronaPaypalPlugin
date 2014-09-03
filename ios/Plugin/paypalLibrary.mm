// ----------------------------------------------------------------------------
// paypalLibrary.mm
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

#import "paypalLibrary.h"

// Apple
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Accounts/Accounts.h>
#import <AVFoundation/AVFoundation.h>

// Corona
#import "CoronaRuntime.h"
#include "CoronaAssert.h"
#include "CoronaEvent.h"
#include "CoronaLua.h"
#include "CoronaLibrary.h"

// Paypal
#include "paypalLibrary.h"
#include "PayPalMobile.h"
#include "PayPalConfiguration.h"
#include "PayPalPayment.h"
#include "PayPalFuturePaymentViewController.h"

// The Paypal delegate
@interface PayPalDelegate : UIViewController <PayPalPaymentDelegate, PayPalFuturePaymentDelegate, UIPopoverControllerDelegate>
@property (nonatomic, strong, readwrite) NSString *environment; // TODO
@property (nonatomic, assign, readwrite) BOOL acceptCreditCards; // TODO
// Pointer to our PayPal configuration object
@property (nonatomic, assign) PayPalConfiguration *paypalConfig;
// Reference to the current Lua listener function
@property (nonatomic) Corona::Lua::Ref listenerRef;
// Correlation id
@property (nonatomic, assign) NSString *correlationId;
// Pointer to the current Lua state
@property (nonatomic, assign) lua_State *L;

@end

// ----------------------------------------------------------------------------

@class UIViewController;

namespace Corona
{

// ----------------------------------------------------------------------------

class paypalLibrary
{
	public:
		typedef paypalLibrary Self;

	public:
		static const char kName[];
		
	public:
		static int Open( lua_State *L );
		static int Finalizer( lua_State *L );
		static Self *ToLibrary( lua_State *L );

	protected:
		paypalLibrary();
		bool Initialize( void *platformContext );
		
	public:
		UIViewController* GetAppViewController() const { return fAppViewController; }

	public:
		static int init( lua_State *L );
		static int config( lua_State *L );
		static int show( lua_State *L );

	private:
		UIViewController *fAppViewController;
};

// ----------------------------------------------------------------------------

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
const char paypalLibrary::kName[] = "plugin.paypal";
// Pointer to the Paypal Delegate
PayPalDelegate *paypalDelegate;

int
paypalLibrary::Open( lua_State *L )
{
	// Register __gc callback
	const char kMetatableName[] = __FILE__; // Globally unique string to prevent collision
	CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );
	
	//CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );
	void *platformContext = CoronaLuaGetContext( L );

	// Set library as upvalue for each library function
	Self *library = new Self;

	if ( library->Initialize( platformContext ) )
	{
		// Functions in library
		static const luaL_Reg kFunctions[] =
		{
			{ "init", init },
			{ "config", config },
			{ "show", show },
			{ NULL, NULL }
		};

		// Register functions as closures, giving each access to the
		// 'library' instance via ToLibrary()
		{
			CoronaLuaPushUserdata( L, library, kMetatableName );
			luaL_openlib( L, kName, kFunctions, 1 ); // leave "library" on top of stack
		}
	}

	return 1;
}

int
paypalLibrary::Finalizer( lua_State *L )
{
	Self *library = (Self *)CoronaLuaToUserdata( L, 1 );
	delete library;
	
	// Release the PayPal config object
	[paypalDelegate.paypalConfig release];
	paypalDelegate.paypalConfig = nil;
	
	// Release the Paypal Delegate
	[paypalDelegate release];
	paypalDelegate = nil;

	return 0;
}

paypalLibrary *
paypalLibrary::ToLibrary( lua_State *L )
{
	// library is pushed as part of the closure
	Self *library = (Self *)CoronaLuaToUserdata( L, lua_upvalueindex( 1 ) );
	return library;
}

paypalLibrary::paypalLibrary()
:	fAppViewController( nil )
{
}

bool
paypalLibrary::Initialize( void *platformContext )
{
	bool result = ( ! fAppViewController );

	if ( result )
	{
		id<CoronaRuntime> runtime = (id<CoronaRuntime>)platformContext;
		fAppViewController = runtime.appViewController; // TODO: Should we retain?
	}

	return result;
}

// Function to intiialize the Paypal Plugin
int
paypalLibrary::init( lua_State *L )
{
	// Listener reference
	Corona::Lua::Ref listenerRef = NULL;
	
	// If an options table has been passed
	if ( lua_type( L, -1 ) == LUA_TTABLE )
	{
		// Get listener key
		lua_getfield( L, -1, "listener" );
		
		// Set the delegate's listenerRef to reference the Lua listener function (if it exists)
		if ( Lua::IsListener( L, -1, "payPal" ) )
		{
			listenerRef = Corona::Lua::NewRef( L, -1 );
		}
		lua_pop( L, 1 );
		
		// Initialize the PayPal delegate
		if ( paypalDelegate == nil )
		{
			paypalDelegate = [[PayPalDelegate alloc] init];
			// Assign the lua state so we can access it from within the delegate
			paypalDelegate.L = L;
			// Set the callback reference to MULL
			paypalDelegate.listenerRef = NULL;
		}
		lua_pop( L, 1 );
	}
	// No options table passed in
	else
	{
		luaL_error( L, "Error: payPal.init(), options table expected, got %s", luaL_typename( L, -1 ) );
	}
	
	// If a Listener function exists (fire licensing listener for backwards compat)
	if ( listenerRef != NULL )
	{
		// Create the event
		Corona::Lua::NewEvent( L, "license" );
		lua_pushstring( L, "check" );
		lua_setfield( L, -2, CoronaEventTypeKey() );

		// Push the status string
		lua_pushstring( L, "valid" );
		lua_setfield( L, -2, "status" );
		
		// Dispatch the event
		Corona::Lua::DispatchEvent( L, listenerRef, 1 );
				
		// Free native reference to listener
		Corona::Lua::DeleteRef( L, listenerRef );
		
		// Null the reference
		listenerRef = NULL;
	}
	
	return 0;
}

// Function to configure Paypal settings
int
paypalLibrary::config( lua_State *L )
{
	// This requires an options table with the following params
	/*
		productionClientID = "XXX" (reqyured) -- The users client id for production.
		sandboxClientID = "XXX" (required - shouldn't this only be required for test mode??) -- The users client id for sandbox.
		environment = "sandbox" (optional) -- Valid values are `sandbox`, `noNetwork` and `production`
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
	if ( paypalDelegate == nil )
	{
		luaL_error( L, "Error: You must call payPal.init() before calling payPal.config()\n" );
		return 0;
	}

	// Paypal Production Client ID
	const char *productionClientID = NULL;
	// Paypal Sandbox Client ID
	const char *sandboxClientID = NULL;
	// Accept Credit Cards bool
	bool acceptCreditCards = true;
	// The langauge the Paypal view controllers will use
	const char *language = NULL;
	// The name of the Paypal Merchant
	const char *merchantName = NULL;
	// The Paypal merchants privacy policy URL
	const char *merchantPrivacyPolicyURL = "https://www.paypal.com/webapps/mpp/ua/privacy-full";
	// The Paypal merchants user agreement policy URL
	const char *merchantUserAgreementURL = "https://www.paypal.com/webapps/mpp/ua/useragreement-full";
	// Paypal Environment
	const char *environment = NULL;
	// Remember user
	bool rememberUser = true;
	// Use sandbox defaults
	bool useSandboxDefaults = false;
	// Sandbox password
	const char *sandboxPassword = NULL;
	// Sandbox Pin
	const char *sandboxPin = NULL;
	// Email
	const char *email = NULL;
	// Phone Number
	const char *phoneNumber = NULL;
	// Country code
	const char *phoneCountryCode = NULL;
	
	// If an options table has been passed
	if ( lua_type( L, -1 ) == LUA_TTABLE )
	{
		// Production ID
		lua_getfield( L, -1, "productionClientID" );
		if ( lua_type( L, -1 ) == LUA_TSTRING )
		{
			productionClientID = lua_tostring( L, -1 );
		}
		else
		{
			luaL_error( L, "Error: productionClientID expected, got %s\n", luaL_typename( L, -1 ) );
		}
		lua_pop( L, 1 );
		
		// Sandbox ID
		lua_getfield( L, -1, "sandboxClientID" );
		if ( lua_type( L, -1 ) == LUA_TSTRING )
		{
			sandboxClientID = lua_tostring( L, -1 );
		}
		else
		{
			luaL_error( L, "Error: sandboxClientID expected, got %s\n", luaL_typename( L, -1 ) );
		}
		lua_pop( L, 1 );
		
		// Accept Credit Cards
		lua_getfield( L, -1, "acceptCreditCards" );
		if ( lua_type( L, -1 ) == LUA_TBOOLEAN )
		{
			acceptCreditCards = lua_toboolean( L, -1 );
		}
		lua_pop( L, 1 );
		
		// Language
		lua_getfield( L, -1, "language" );
		if ( lua_type( L, -1 ) == LUA_TSTRING )
		{
			language = lua_tostring( L, -1 );
		}
		lua_pop( L, 1 );
		
		// Merchant
		lua_getfield( L, -1, "merchant" );
		if ( lua_type( L, -1 ) == LUA_TTABLE )
		{
			// Merchant Name
			lua_getfield( L, -1, "name" );
			if ( lua_type( L, -1 ) == LUA_TSTRING )
			{
				merchantName = lua_tostring( L, -1 );
			}
			lua_pop( L, 1 );
			
			// Merchant Privacy Policy URL
			lua_getfield( L, -1, "privacyPolicyURL" );
			if ( lua_type( L, -1 ) == LUA_TSTRING )
			{
				merchantPrivacyPolicyURL = lua_tostring( L, -1 );
			}
			lua_pop( L, 1 );
			
			// Merchant User Agreement URL
			lua_getfield( L, -1, "userAgreementURL" );
			if ( lua_type( L, -1 ) == LUA_TSTRING )
			{
				merchantUserAgreementURL = lua_tostring( L, -1 );
			}
			lua_pop( L, 1 );
		}
		lua_pop( L, 1 );
		
		// Environment
		lua_getfield( L, -1, "environment" );
		if ( lua_type( L, -1 ) == LUA_TSTRING )
		{
			environment = lua_tostring( L, -1 );
		}
		lua_pop( L, 1 );
		
		// Remember user
		lua_getfield( L, -1, "rememberUser" );
		if ( lua_type( L, -1 ) == LUA_TBOOLEAN )
		{
			rememberUser = lua_toboolean( L, -1 );
		}
		lua_pop( L, 1 );
		
		// Sandbox
		lua_getfield( L, -1, "sandbox" );
		
		// If sandbox is a table
		if ( lua_type( L, -1 ) == LUA_TTABLE )
		{
			// Use defaults
			lua_getfield( L, -1, "useDefaults" );
			if ( lua_type( L, -1 ) == LUA_TBOOLEAN )
			{
				useSandboxDefaults = lua_toboolean( L, -1 );
			}
			lua_pop( L, 1 );
			
			// Sandbox password
			lua_getfield( L, -1, "password" );
			if ( lua_type( L, -1 ) == LUA_TSTRING )
			{
				sandboxPassword = lua_tostring( L, -1 );
			}
			lua_pop( L, 1 );
			
			// Sandbox pin
			lua_getfield( L, -1, "pin" );
			if ( lua_type( L, -1 ) == LUA_TSTRING )
			{
				sandboxPin = lua_tostring( L, -1 );
			}
			lua_pop( L, 1 );
		}
		lua_pop( L, 1 );
		
		// User
		lua_getfield( L, -1, "user" );
		
		// If user is a table
		if ( lua_type( L, -1 ) == LUA_TTABLE )
		{
			// Email
			lua_getfield( L, -1, "email" );
			if ( lua_type( L, -1 ) == LUA_TSTRING )
			{
				email = lua_tostring( L, -1 );
			}
			lua_pop( L, 1 );
			
			// Phone Number
			lua_getfield( L, -1, "phoneNumber" );
			if ( lua_type( L, -1 ) == LUA_TSTRING )
			{
				phoneNumber = lua_tostring( L, -1 );
			}
			lua_pop( L, 1 );
			
			// Phone Country Code
			lua_getfield( L, -1, "phoneCountryCode" );
			if ( lua_type( L, -1 ) == LUA_TSTRING )
			{
				phoneCountryCode = lua_tostring( L, -1 );
			}
			lua_pop( L, 1 );
		}
		// Pop the user and options table
		lua_pop( L, 2 );
	}
	// No options table passed
	else
	{
		luaL_error( L, "Error: payPal.config(), options table expected, got %s", luaL_typename( L, -1 ) );
	}

	// Create a paypal configuration object
	paypalDelegate.paypalConfig = [[PayPalConfiguration alloc] init];
	if ( email != NULL ) paypalDelegate.paypalConfig.defaultUserEmail = [NSString stringWithUTF8String:email];
	if ( phoneNumber != NULL ) paypalDelegate.paypalConfig.defaultUserPhoneNumber = [NSString stringWithUTF8String:phoneNumber];
	if ( phoneCountryCode != NULL ) paypalDelegate.paypalConfig.defaultUserPhoneCountryCode = [NSString stringWithUTF8String:phoneCountryCode];
	
	// Setup configuration properties
	paypalDelegate.paypalConfig.acceptCreditCards = acceptCreditCards;
	if ( language ) paypalDelegate.paypalConfig.languageOrLocale = [NSString stringWithUTF8String:language];
	if ( merchantName ) paypalDelegate.paypalConfig.merchantName = [NSString stringWithUTF8String:merchantName];
	if ( merchantPrivacyPolicyURL ) paypalDelegate.paypalConfig.merchantPrivacyPolicyURL = [NSURL URLWithString:[NSString stringWithUTF8String:merchantPrivacyPolicyURL]];
	if ( merchantUserAgreementURL ) paypalDelegate.paypalConfig.merchantUserAgreementURL = [NSURL URLWithString:[NSString stringWithUTF8String:merchantUserAgreementURL]];
	paypalDelegate.paypalConfig.rememberUser = rememberUser;
	paypalDelegate.paypalConfig.forceDefaultsInSandbox = useSandboxDefaults;
	
	// If we are using sandbox defaults
	if ( useSandboxDefaults == true )
	{
		// Sandbox password
		if ( sandboxPassword != NULL )
		{
			paypalDelegate.paypalConfig.sandboxUserPassword = [NSString stringWithUTF8String:sandboxPassword];
		}
		else
		{
			luaL_error( L, "Error: You have set sandbox useDefaults to true, but have not specified a password in your sandbox table\n " );
		}
		
		// Sandbox pin
		if ( sandboxPin != NULL )
		{
			paypalDelegate.paypalConfig.sandboxUserPin = [NSString stringWithUTF8String:sandboxPin];
		}
		else
		{
			luaL_error( L, "Error: You have set sandbox useDefaults to true, but have not specified a pin in your sandbox table\n " );
		}
	}
	
	// If we have non null production and sandbox ID, then lets initialize Paypal
	if ( productionClientID != NULL && sandboxClientID != NULL )
	{
		// Initialize paypal
		[PayPalMobile initializeWithClientIdsForEnvironments:@{PayPalEnvironmentProduction : [NSString stringWithUTF8String:productionClientID],
													 PayPalEnvironmentSandbox : [NSString stringWithUTF8String:sandboxClientID]}];
						
		
		// Connect PayPal to the specified environment
		if ( environment == NULL ) [PayPalMobile preconnectWithEnvironment:PayPalEnvironmentNoNetwork];
		if ( strcmp( environment, "sandbox" ) == 0 )
		{
			[PayPalMobile preconnectWithEnvironment:PayPalEnvironmentSandbox];
			paypalDelegate.correlationId = [PayPalMobile applicationCorrelationIDForEnvironment:PayPalEnvironmentSandbox];
		}
		if ( strcmp( environment, "noNetwork" ) == 0 )
		{
			[PayPalMobile preconnectWithEnvironment:PayPalEnvironmentNoNetwork];
			paypalDelegate.correlationId = [PayPalMobile applicationCorrelationIDForEnvironment:PayPalEnvironmentNoNetwork];
		}
		if ( strcmp( environment, "production" ) == 0 )
		{
			[PayPalMobile preconnectWithEnvironment:PayPalEnvironmentProduction];
			paypalDelegate.correlationId = [PayPalMobile applicationCorrelationIDForEnvironment:PayPalEnvironmentProduction];
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
	
	return 0;
}


// Function to show a PayPal payment view controller
int
paypalLibrary::show( lua_State *L )
{
	// If PayPal has not been initialized
	if ( paypalDelegate == nil )
	{
		luaL_error( L, "Error: You must call first call payPal.init(), then payPal.config() before calling payPal.show()\n" );
		return 0;
	}
	// If PayPal has not been configured
	if ( paypalDelegate.paypalConfig == nil )
	{
		luaL_error( L, "Error: You must first call payPal.init(), then payPal.config() before calling payPal.show()\n" );
		return 0;
	}
		
	// Corona namespace
	using namespace Corona;
	// Context
	Self *context = ToLibrary( L );
	
	// The type of PayPal view controller to show
	const char *viewControllerType = lua_tostring( L, 1 );
	
	// If context is valid
	if ( context )
	{
		// Library
		Self& library = * context;
		
		// Get Corona's view controller
		UIViewController *appViewController = library.GetAppViewController();
			
		// Make Payment
		if ( strcmp( "payment", viewControllerType ) == 0 )
		{
			// Amount of payment
			const char *amount = NULL;
			// Tax on payment
			float tax = 0.00;
			// Shipping on payment
			float shipping = 0.00;
			// Currency code
			const char *currencyCode = NULL;
			// Short Description
			const char *description = NULL;
			// BN Code
			const char *bnCode = NULL;
			// Intent
			const char *paymentIntent = "sale";
		
			// If an options table has been passed
			if ( lua_type( L, -1 ) == LUA_TTABLE )
			{
				// Get listener key
				lua_getfield( L, -1, "listener" );
				
				// Set the delegate's listenerRef to reference the Lua listener function (if it exists)
				if ( Lua::IsListener( L, -1, "payPal" ) )
				{
					paypalDelegate.listenerRef = Corona::Lua::NewRef( L, -1 );
				}
				lua_pop( L, 1 );
		
				// Payment (table)
				lua_getfield( L, -1, "payment" );
		
				// Payment
				if ( lua_type( L, -1 ) == LUA_TTABLE )
				{
					// Amount
					lua_getfield( L, -1, "amount" );
					if ( lua_type( L, -1 ) == LUA_TNUMBER )
					{
						amount = lua_tostring( L, -1 );
					}
					else
					{
						luaL_error( L, "Error: payment amount expected, got %s\n", luaL_typename( L, -1 ) );
					}
					lua_pop( L, 1 );
				
					// Tax
					lua_getfield( L, -1, "tax" );
					if ( lua_type( L, -1 ) == LUA_TNUMBER )
					{
						tax = lua_tonumber( L, -1 );
					}
					lua_pop( L, 1 );
					
					// Shipping
					lua_getfield( L, -1, "shipping" );
					if ( lua_type( L, -1 ) == LUA_TNUMBER )
					{
						shipping = lua_tonumber( L, -1 );
					}
					lua_pop( L, 1 );
					
					// Intent
					lua_getfield( L, -1, "intent" );
					if ( lua_type( L, -1 ) == LUA_TSTRING )
					{
						paymentIntent = lua_tostring( L, -1 );
					}
					lua_pop( L, 1 );
				}
				else
				{
					luaL_error( L, "Error: paypal.show( 'payment' ), payment table expected, got %s\n", luaL_typename( L, -1 ) );
				}
				lua_pop( L, 1 );
				
				// Currency Code
				lua_getfield( L, -1, "currencyCode" );
				if ( lua_type( L, -1 ) == LUA_TSTRING )
				{
					currencyCode = lua_tostring( L, -1 );
				}
				lua_pop( L, 1 );
				
				// Description
				lua_getfield( L, -1, "shortDescription" );
				if ( lua_type( L, -1 ) == LUA_TSTRING )
				{
					description = lua_tostring( L, -1 );
				}
				else
				{
					luaL_error( L, "Error: shortDescription expected, got %s\n", luaL_typename( L, -1 ) );
				}
				lua_pop( L, 1 );
				
				// Accept Credit Cards
				lua_getfield( L, -1, "acceptCreditCards" );
				if ( lua_type( L, -1 ) == LUA_TBOOLEAN )
				{
					// Accept credit cards?
					bool acceptCreditCards = lua_toboolean( L, -1 );
					// If the user requested to update the credit card property, lets update the delegates property also
					paypalDelegate.paypalConfig.acceptCreditCards = acceptCreditCards;
				}
				lua_pop( L, 1 );
				
				// BN Code
				lua_getfield( L, -1, "bnCode" );
				if ( lua_type( L, -1 ) == LUA_TSTRING )
				{
					bnCode = lua_tostring( L, -1 );
				}
				lua_pop( L, 1 );
			}
			lua_pop( L, 1 );
			
			// Create a Paypal payment object
			PayPalPayment *payment = [[PayPalPayment alloc] init];
			NSDecimalNumber *paymentAmount = [[NSDecimalNumber alloc] initWithString:[NSString stringWithUTF8String:amount]];
			payment.currencyCode = [NSString stringWithUTF8String:currencyCode];
			payment.shortDescription = [NSString stringWithUTF8String:description];
			if ( bnCode != NULL ) payment.bnCode = [NSString stringWithUTF8String:bnCode];
			
			// Create a PayPal payment details object
			PayPalPaymentDetails *paymentDetails = [[PayPalPaymentDetails alloc] init];
			paymentDetails.tax = [[NSDecimalNumber alloc] initWithFloat:tax];
			paymentDetails.shipping = [[NSDecimalNumber alloc] initWithFloat:shipping];
			payment.amount = [[paymentAmount decimalNumberByAdding:paymentDetails.tax] decimalNumberByAdding:paymentDetails.shipping];
			paymentDetails.subtotal = [[payment.amount decimalNumberBySubtracting:paymentDetails.tax] decimalNumberBySubtracting:paymentDetails.shipping];
			// Set payment details
			payment.paymentDetails = paymentDetails;
					
			// Setup the Paypal Intent
			if ( strcmp( paymentIntent, "sale" ) == 0 ) payment.intent = PayPalPaymentIntentSale;
			if ( strcmp( paymentIntent, "authorize" ) == 0 ) payment.intent = PayPalPaymentIntentAuthorize;
			
			// Payment processable, lets proceed to show the PayPal payment view controller
			if ( payment.processable )
			{
				// Update the configuration regarding accepting credit cards
				[paypalDelegate.paypalConfig setAcceptCreditCards:paypalDelegate.paypalConfig.acceptCreditCards];
				
				// Create the PayPal Payment view controller
				PayPalPaymentViewController *paymentViewController = [[PayPalPaymentViewController alloc] initWithPayment:payment configuration:paypalDelegate.paypalConfig delegate:paypalDelegate];
					
				// Show the PayPal Payment view controller
				[appViewController presentViewController:paymentViewController animated:YES completion:nil];
			}
			// The payment was not processable
			else
			{
				// If, for example, the amount was negative or the shortDescription was
				// empty, this payment wouldn't be processable, and you'd want to handle that here.

				// If a Listener function exists
				if ( paypalDelegate.listenerRef != NULL )
				{
					// Create the event
					Corona::Lua::NewEvent( L, "paymentConfirmation" );
					lua_pushstring( L, "payment" );
					lua_setfield( L, -2, CoronaEventTypeKey() );

					// Push the error string
					lua_pushboolean( L, false );
					lua_setfield( L, -2, "isProcessable" );
					
					// Dispatch the event
					Corona::Lua::DispatchEvent( L, paypalDelegate.listenerRef, 1 );
							
					// Free native reference to listener
					Corona::Lua::DeleteRef( L, paypalDelegate.listenerRef );
					
					// Null the reference
					paypalDelegate.listenerRef = NULL;
				}
			}
		}
		// Future Payment
		else if ( strcmp( "futurePayment", viewControllerType ) == 0 )
		{
			// If an options table has been passed
			if ( lua_type( L, -1 ) == LUA_TTABLE )
			{
				// Get listener key
				lua_getfield( L, -1, "listener" );
				
				// Set the delegate's listenerRef to reference the Lua listener function (if it exists)
				if ( Lua::IsListener( L, -1, "payPal" ) )
				{
					paypalDelegate.listenerRef = Corona::Lua::NewRef( L, -1 );
				}
				lua_pop( L, 1 );
			}
			lua_pop( L, 1 );

			// Create the PayPal Future Payment view controller
			PayPalFuturePaymentViewController *futurePaymentViewController = [[PayPalFuturePaymentViewController alloc] initWithConfiguration:paypalDelegate.paypalConfig delegate:paypalDelegate];
					
			// Show the PayPal Future Payment view controller
			[appViewController presentViewController:futurePaymentViewController animated:YES completion:nil];
		}
		// Unrecognised option, show error
		else
		{
			luaL_error( L, "Error: Unrecognised 1st parameter passed to paypal.show(). Valid options are `payment` or `futurePayment`\n" );
		}
	}
	
	return 0;
}

// ----------------------------------------------------------------------------

} // namespace Corona

//

// PayPal Delegate implementation
@implementation PayPalDelegate

#pragma mark PayPalPaymentDelegate methods

- (void)payPalPaymentViewController:(PayPalPaymentViewController *)paymentViewController didCompletePayment:(PayPalPayment *)completedPayment
{
	//NSLog(@"PayPal Payment Success!");
	//NSLog( @"Correlation id is:%@", self.correlationId );

	// If there is a callback to execute
	if ( NULL != self.listenerRef )
	{
		// Create the event
		Corona::Lua::NewEvent( self.L, "payment" );
		lua_pushstring( self.L, "confirmation" );
		lua_setfield( self.L, -2, CoronaEventTypeKey() );
		
		// Push the success event
		lua_pushstring( self.L, "completed" );
		lua_setfield( self.L, -2, "state" );
		
		// Push the correlation id
		lua_pushstring( self.L, [self.correlationId UTF8String] );
		lua_setfield( self.L, -2, "correlationID" );
		
		// Convert the NSDictionary response to JSON
		NSError *error;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:completedPayment.confirmation options:kNilOptions error:&error];
		NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		
		// Currency code
		lua_pushstring( self.L, [completedPayment.currencyCode UTF8String ] );
		lua_setfield( self.L, -2, "currencyCode" );
		
		// Amount
		lua_pushnumber( self.L, [completedPayment.amount doubleValue ] );
		lua_setfield( self.L, -2, "amount" );
		
		// Short description
		lua_pushstring( self.L, [completedPayment.shortDescription UTF8String ] );
		lua_setfield( self.L, -2, "shortDescription" );
		
		// Push the JSON string
		lua_pushstring( self.L, [jsonString UTF8String]);
		lua_setfield( self.L, -2, "response" );
		
		// Dispatch the event
		Corona::Lua::DispatchEvent( self.L, self.listenerRef, 1 );
				
		// Free native reference to listener
		Corona::Lua::DeleteRef( self.L, self.listenerRef );
		
		// Null the reference
		self.listenerRef = NULL;
	}
	
	// Dismiss the payment view controller
	[paymentViewController dismissViewControllerAnimated:YES completion:nil];
}

// PayPal Payment Canceled
- (void)payPalPaymentDidCancel:(PayPalPaymentViewController *)paymentViewController
{
	//NSLog(@"PayPal Payment Canceled");
	
	// If there is a callback to execute
	if ( NULL != self.listenerRef )
	{
		// Create the event
		Corona::Lua::NewEvent( self.L, "payment" );
		lua_pushstring( self.L, "confirmation" );
		lua_setfield( self.L, -2, CoronaEventTypeKey() );
		
		// Push the canceled event
		lua_pushstring( self.L, "canceled" );
		lua_setfield( self.L, -2, "state" );
		
		// Dispatch the event
		Corona::Lua::DispatchEvent( self.L, self.listenerRef, 1 );
				
		// Free native reference to listener
		Corona::Lua::DeleteRef( self.L, self.listenerRef );
		
		// Null the reference
		self.listenerRef = NULL;
	}

	// Dismiss the payment view controller
	[paymentViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark PayPalFuturePaymentDelegate methods
// Paypal Future Payment ViewController Auth Completion
- (void)payPalFuturePaymentViewController:(PayPalFuturePaymentViewController *)futurePaymentViewController didAuthorizeFuturePayment:(NSDictionary *)futurePaymentAuthorization
{
	//NSLog(@"PayPal Future Payment Authorization Success!");
	//NSString *authCode = futurePaymentAuthorization[@"code"];
	
	// Correlation id
    //NSString *correlationId = [PayPalMobile applicationCorrelationIDForEnvironment:PayPalEnvironmentProduction];
	//NSLog( @"Correlation id is:%@", self.correlationId );
	
	// If there is a callback to execute
	if ( NULL != self.listenerRef )
	{
		// Create the event
		Corona::Lua::NewEvent( self.L, "futurePayment" );
		lua_pushstring( self.L, "confirmation" );
		lua_setfield( self.L, -2, CoronaEventTypeKey() );
		
		// Convert the NSDictionary response to JSON
		NSError *error;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:futurePaymentAuthorization options:kNilOptions error:&error];
		NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		
		// Push the success event
		lua_pushstring( self.L, "completed" );
		lua_setfield( self.L, -2, "state" );

		// Push the correlation id
		lua_pushstring( self.L, [self.correlationId UTF8String] );
		lua_setfield( self.L, -2, "correlationID" );
		
		// Push the JSON string
		lua_pushstring( self.L, [jsonString UTF8String]);
		lua_setfield( self.L, -2, "response" );
		
		// Dispatch the event
		Corona::Lua::DispatchEvent( self.L, self.listenerRef, 1 );
				
		// Free native reference to listener
		Corona::Lua::DeleteRef( self.L, self.listenerRef );
		
		// Null the reference
		self.listenerRef = NULL;
	}
	
	// Dismiss the future payment view controller
	[futurePaymentViewController dismissViewControllerAnimated:YES completion:nil];
}

// PayPal future payment canceled
- (void)payPalFuturePaymentDidCancel:(PayPalFuturePaymentViewController *)futurePaymentViewController
{
	//NSLog(@"PayPal Future Payment Authorization Canceled");
	
	// If there is a callback to execute
	if ( NULL != self.listenerRef )
	{
		// Create the event
		Corona::Lua::NewEvent( self.L, "futurePayment" );
		lua_pushstring( self.L, "confirmation" );
		lua_setfield( self.L, -2, CoronaEventTypeKey() );
		
		// Push the canceled event
		lua_pushstring( self.L, "canceled" );
		lua_setfield( self.L, -2, "state" );
		
		// Dispatch the event
		Corona::Lua::DispatchEvent( self.L, self.listenerRef, 1 );
				
		// Free native reference to listener
		Corona::Lua::DeleteRef( self.L, self.listenerRef );
		
		// Null the reference
		self.listenerRef = NULL;
	}
	
	// Dismiss the future payment view controller
	[futurePaymentViewController dismissViewControllerAnimated:YES completion:nil];
}
@end

// ----------------------------------------------------------------------------

CORONA_EXPORT
int luaopen_plugin_paypal( lua_State *L )
{
	return Corona::paypalLibrary::Open( L );
}
