//
//  init.java
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

// Android Imports
import android.content.Context;

// JNLua imports
import com.naef.jnlua.LuaState;
import com.naef.jnlua.LuaType;

// Corona Imports
import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeTask;
import com.ansca.corona.CoronaRuntimeTaskDispatcher;

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
 * Implements the init() function in Lua.
 * <p>
 * Used for initializing the PayPal Plugin.
 */
public class init implements com.naef.jnlua.NamedJavaFunction 
{
	/**
	 * Gets the name of the Lua function as it would appear in the Lua script.
	 * @return Returns the name of the custom Lua function.
	 */
	@Override
	public String getName()
	{
		return "init";
	}

	// Init callback Event task
	private static class initCallBackListenerTask implements CoronaRuntimeTask 
	{
		private int fLuaListenerRegistryId;
		private String fStatus = null;

		public initCallBackListenerTask( int luaListenerRegistryId, String status ) 
		{
			fLuaListenerRegistryId = luaListenerRegistryId;
			fStatus = status;
		}

		@Override
		public void executeUsing( CoronaRuntime runtime )
		{
			try 
			{
				// Fetch the Corona runtime's Lua state.
				final LuaState L = runtime.getLuaState();

				// Dispatch the lua callback
				if ( CoronaLua.REFNIL != fLuaListenerRegistryId ) 
				{
					// Setup the event
					CoronaLua.newEvent( L, "license" );

					// Event type
					L.pushString( "check" );
					L.setField( -2, "type" );

					// Status
					L.pushString( fStatus );
					L.setField( -2, "status" );

					// Dispatch the event
					CoronaLua.dispatchEvent( L, fLuaListenerRegistryId, 0 );

					// Free native reference to the listener
					CoronaLua.deleteRef( L, fLuaListenerRegistryId );

					// Null the reference
					fLuaListenerRegistryId = 0;
				}
			}
			catch ( Exception ex ) 
			{
				ex.printStackTrace();
			}
		}
	}

	// Our lua callback listener
	private int listenerRef;

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
			// Get the corona application context
			Context coronaApplication = CoronaEnvironment.getApplicationContext();

			// If an options table has been passed
			if ( luaState.isTable( -1 ) )
			{				
				// Get the listener field
				luaState.getField( -1, "listener" );
				if ( CoronaLua.isListener( luaState, -1, "payPal" ) ) 
				{
					// Assign the callback listener to a new lua ref
					listenerRef = CoronaLua.newRef( luaState, -1 );
				}
				else
				{
					// Assign the listener to a nil ref
					listenerRef = CoronaLua.REFNIL;
				}
				luaState.pop( 1 );

				// Pop the options table
				luaState.pop( 1 );
			}
			// No options table passed in
			else
			{
				System.out.println( "Error: payPal.init(), options table expected, got " + luaState.typeName( -1 ) );
			}

			// Corona Activity
			CoronaActivity coronaActivity = null;
			if ( CoronaEnvironment.getCoronaActivity() != null )
			{
				coronaActivity = CoronaEnvironment.getCoronaActivity();
			}

			// Corona runtime task dispatcher
			final CoronaRuntimeTaskDispatcher dispatcher = new CoronaRuntimeTaskDispatcher( luaState );

			// Create a new runnable object to invoke our activity
			Runnable runnableActivity = new Runnable()
			{
				public void run()
				{
					// Create the task (for backwards compat)
					initCallBackListenerTask task = new initCallBackListenerTask( listenerRef, "valid" );

					// Send the task to the Corona runtime asynchronously.
					dispatcher.send( task );
				}
			};

			// Run the activity on the uiThread
			if ( coronaActivity != null )
			{
				// We have called init
				paypal.hasCalledInit = true;
				// Run the activity
				coronaActivity.runOnUiThread( runnableActivity );
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
