//
//  show.java
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
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import android.util.JsonReader;

// Android Imports
import android.app.Activity;
import android.content.Intent;
import android.net.Uri;

// Paypal Imports
import com.paypal.android.sdk.payments.PayPalAuthorization;
import com.paypal.android.sdk.payments.PayPalConfiguration;
import com.paypal.android.sdk.payments.PayPalFuturePaymentActivity;
import com.paypal.android.sdk.payments.PayPalPayment;
import com.paypal.android.sdk.payments.PayPalService;
import com.paypal.android.sdk.payments.PaymentActivity;
import com.paypal.android.sdk.payments.PaymentConfirmation;
import com.paypal.android.sdk.payments.PayPalPaymentDetails;

/**
 * Implements the show() function in Lua.
 * <p>
 * Used for showing native paypal windows/view controllers in the PayPal Plugin.
 */
public class show implements com.naef.jnlua.NamedJavaFunction 
{
	/**
	 * Gets the name of the Lua function as it would appear in the Lua script.
	 * @return Returns the name of the custom Lua function.
	 */
	@Override
	public String getName()
	{
		return "show";
	}

	// Pointer to the lua state
	private LuaState lState;
	// Our lua callback listener
	private int listenerRef;

	// NAME_ME_PLEASE Event task
	private static class luaCallBackListenerTask implements CoronaRuntimeTask 
	{
		private int fLuaListenerRegistryId;
		private String fState = null;
		private String fConfirmationName = null;
		private String fCorrelationID = null;
		private JSONObject fResponse = null;
		private String fCurrencyCode = null;
		private String fAmount = null;
		private String fShortDescription = null;

		// Canceled
		public luaCallBackListenerTask( int luaListenerRegistryId, String state, String confirmationName ) 
		{
			fLuaListenerRegistryId = luaListenerRegistryId;
			fState = state;
			fConfirmationName = confirmationName;
		}

		// Future payment
		public luaCallBackListenerTask( int luaListenerRegistryId, String state, String confirmationName, String correlationID, JSONObject response )
		{
			fLuaListenerRegistryId = luaListenerRegistryId;
			fState = state;
			fConfirmationName = confirmationName;
			fCorrelationID = correlationID;
			fResponse = response;
		}

		// Payment
		public luaCallBackListenerTask( int luaListenerRegistryId, String state, String confirmationName, String correlationID, JSONObject response, String currencyCode, String amount, String shortDescription )
		{
			fLuaListenerRegistryId = luaListenerRegistryId;
			fState = state;
			fConfirmationName = confirmationName;
			fCorrelationID = correlationID;
			fResponse = response;
			fCurrencyCode = currencyCode;
			fAmount = amount;
			fShortDescription = shortDescription;
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
					CoronaLua.newEvent( L, fConfirmationName );

					// Event type
					L.pushString( fState );
					L.setField( -2, "state" );

					// PayPal correlation ID
					if ( fCorrelationID != null )
					{
						// Push the correlation id
						L.pushString( fCorrelationID );
						L.setField( -2, "correlationID" );
					}

					// PayPal Json response
					if ( fResponse != null )
					{
						// Push the JSON string
						L.pushString( fResponse.toString() );
						L.setField( -2, "response" );
					}

					// Currency code
					if ( fCurrencyCode != null )
					{
						// Push the currency code
						L.pushString( fCurrencyCode );
						L.setField( -2, "currencyCode" );
					}

					// Amount
					if ( fAmount != null )
					{
						// Push the amount
						L.pushString( fAmount );
						L.setField( -2, "amount" );
					}

					// Short description
					if ( fShortDescription != null )
					{
						// Push the short description
						L.pushString( fShortDescription );
						L.setField( -2, "shortDescription" );
					}

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

	// The payment request code
	final int REQUEST_CODE_PAYMENT = 1;
	// The future payment request code
	final int REQUEST_CODE_FUTURE_PAYMENT = 2;

	// Create references to the activity handlers
	public static CoronaActivity.OnActivityResultHandler paymentRequestHandler;
	public static CoronaActivity.OnActivityResultHandler futurePaymentRequestHandler;

	// Payment Activity Callback
	final public int paymentRequestCode = CoronaEnvironment.getCoronaActivity().registerActivityResultHandler( new CoronaActivity.OnActivityResultHandler() 
	{
		// This method is called when we return to the CoronaActivity
		@Override
		public void onHandleActivityResult( CoronaActivity activity, int requestCode, int resultCode, Intent data ) 
		{
			// Assign the payment handler to this activity handler
			paymentRequestHandler = this;

			// Payment request
			if ( requestCode == REQUEST_CODE_PAYMENT )
	        {
	        	// Payment was successful
	            if ( resultCode == Activity.RESULT_OK )
	            {
	                // Get the confirmation data
	                final PaymentConfirmation confirmation = data.getParcelableExtra( PaymentActivity.EXTRA_RESULT_CONFIRMATION );
	                
	                // If we have confirmation data
	                if ( confirmation != null )
	                {	                	
                        // The PayPal correlation id
						final String correlationID = PayPalConfiguration.getApplicationCorrelationId( activity );

		                // Corona runtime task dispatcher
						final CoronaRuntimeTaskDispatcher dispatcher = new CoronaRuntimeTaskDispatcher( lState );

						// Create a new runnable object to invoke our activity
						Runnable runnableActivity = new Runnable()
						{
							public void run()
							{
								// Payment details
			                	String currencyCode = null;
			                	String amount = null;
			                	String shortDescription = null;

			                	// Get the payment details
			                	try
			                	{
			                		// Get the confirmation details
			                		JSONObject confirmationDetails = confirmation.getPayment().toJSONObject();
			                		currencyCode = confirmationDetails.getString( "currency_code" );
			                		amount = confirmationDetails.getString( "amount" );
			                		shortDescription = confirmationDetails.getString( "short_description" );
		                    	}
		                    	catch( JSONException e )
		                    	{
		                    		e.printStackTrace();
		                    	}

								// Create the task
								luaCallBackListenerTask task = new luaCallBackListenerTask( listenerRef, "completed", "payment", correlationID, confirmation.toJSONObject(), currencyCode, amount, shortDescription );
								// Send the task to the Corona runtime asynchronously.
								dispatcher.send( task );
							}
						};

						// Run the activity on the uiThread
						if ( activity != null )
						{
							// We have called init
							paypal.hasCalledInit = true;
							// Run the activity
							activity.runOnUiThread( runnableActivity );
						}
	                }
	            } 
	            else if ( resultCode == Activity.RESULT_CANCELED ) 
	            {	                
	                // Corona runtime task dispatcher
					final CoronaRuntimeTaskDispatcher dispatcher = new CoronaRuntimeTaskDispatcher( lState );

					// Create a new runnable object to invoke our activity
					Runnable runnableActivity = new Runnable()
					{
						public void run()
						{
							// Create the task
							luaCallBackListenerTask task = new luaCallBackListenerTask( listenerRef, "canceled", "payment" );

							// Send the task to the Corona runtime asynchronously.
							dispatcher.send( task );
						}
					};

					// Run the activity on the uiThread
					if ( activity != null )
					{
						// We have called init
						paypal.hasCalledInit = true;
						// Run the activity
						activity.runOnUiThread( runnableActivity );
					}
	            }
	        }
		}
	});


	// Future Payment Activity Callback
	final int futurePaymentRequestCode = CoronaEnvironment.getCoronaActivity().registerActivityResultHandler( new CoronaActivity.OnActivityResultHandler() 
	{
		// This method is called when we return to the CoronaActivity
		@Override
		public void onHandleActivityResult( CoronaActivity activity, int requestCode, int resultCode, Intent data ) 
		{
			// Assign the future payment handler to this activity handler
			futurePaymentRequestHandler = this;

			// Future Payment request
			if ( requestCode == REQUEST_CODE_FUTURE_PAYMENT )
	        {
	            if ( resultCode == Activity.RESULT_OK )
	            {
	            	// Get the authorization data
	                final PayPalAuthorization authorization = data.getParcelableExtra( PayPalFuturePaymentActivity.EXTRA_RESULT_AUTHORIZATION );
	                
	                // If we have auth data
	                if ( authorization != null )
	                {
                    	// Get the corona application context
						Context coronaApplication = CoronaEnvironment.getApplicationContext();
                        String authorization_code = authorization.getAuthorizationCode();

                        // The PayPal correlation id
						final String correlationID = PayPalConfiguration.getApplicationCorrelationId( activity );

		                // Corona runtime task dispatcher
						final CoronaRuntimeTaskDispatcher dispatcher = new CoronaRuntimeTaskDispatcher( lState );

						// Create a new runnable object to invoke our activity
						Runnable runnableActivity = new Runnable()
						{
							public void run()
							{
								// Create the task
								luaCallBackListenerTask task = new luaCallBackListenerTask( listenerRef, "completed", "futurePayment", correlationID, authorization.toJSONObject() );
								// Send the task to the Corona runtime asynchronously.
								dispatcher.send( task );
							}
						};

						// Run the activity on the uiThread
						if ( activity != null )
						{
							// We have called init
							paypal.hasCalledInit = true;
							// Run the activity
							activity.runOnUiThread( runnableActivity );
						}
	                }
	            } 
	            else if ( resultCode == Activity.RESULT_CANCELED )
	            {
	                // Corona runtime task dispatcher
					final CoronaRuntimeTaskDispatcher dispatcher = new CoronaRuntimeTaskDispatcher( lState );

					// Create a new runnable object to invoke our activity
					Runnable runnableActivity = new Runnable()
					{
						public void run()
						{
							// Create the task
							luaCallBackListenerTask task = new luaCallBackListenerTask( listenerRef, "canceled", "futurePayment" );

							// Send the task to the Corona runtime asynchronously.
							dispatcher.send( task );
						}
					};

					// Run the activity on the uiThread
					if ( activity != null )
					{
						// We have called init
						paypal.hasCalledInit = true;
						// Run the activity
						activity.runOnUiThread( runnableActivity );
					}
	            }
	        }
		}
	});

	// Payment not processable Event task
	private static class paymentNotProcessableCallBackListenerTask implements CoronaRuntimeTask 
	{
		private int fLuaListenerRegistryId;

		public paymentNotProcessableCallBackListenerTask( int luaListenerRegistryId ) 
		{
			fLuaListenerRegistryId = luaListenerRegistryId;
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
					CoronaLua.newEvent( L, "paymentConfirmation" );

					// Event type
					L.pushString( "payment" );
					L.setField( -2, "type" );

					// Status
					L.pushBoolean( false );
					L.setField( -2, "isProcessable" );

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
			// If PayPal has not been initialized
			if ( paypal.hasCalledInit == false )
			{
				System.out.println( "Error: You must call first call payPal.init(), then payPal.config() before calling payPal.show()\n" );
				return 0;
			}

			// If PayPal has not been configured
			if ( paypal.hasCalledConfig == false )
			{
				System.out.println( "Error: You must first call payPal.init(), then payPal.config() before calling payPal.show()\n" );
				return 0;
			}

			// Assign the lua state pointer to the current lua state
			lState = luaState;

			// The type of PayPal view controller to show
			String viewControllerType = luaState.checkString( 1 );

			// Corona Activity
			CoronaActivity coronaActivity = null;
			if ( CoronaEnvironment.getCoronaActivity() != null )
			{
				coronaActivity = CoronaEnvironment.getCoronaActivity();
			}
			
			// Make Payment
			if ( viewControllerType.equalsIgnoreCase( "payment" ) )
			{
				// Amount of payment
				Double amount = 0.00;
				// Tax on payment
				Double tax = 0.00;
				// Shipping on payment
				Double shipping = 0.00;
				// Currency code
				String currencyCode = null;
				// Accept credit cards?
				boolean acceptCreditCards = false;
				// Short Description
				String description = null;
				// BN Code
				String bnCode = null;
				// Intent
				String paymentIntent = "sale";

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

					// Payment (table)
					luaState.getField( -1, "payment" );
			
					// Payment
					if ( luaState.isTable( -1 ) )
					{
						// Amount
						luaState.getField( -1, "amount" );
						if ( luaState.isNumber( -1 ) )
						{
							amount = luaState.checkNumber( -1 );
						}
						else
						{
							System.out.println( "Error: payment amount expected, got " + luaState.typeName( -1 ) + "\n" );
						}
						luaState.pop( 1 );
					
						// Tax
						luaState.getField( -1, "tax" );
						if ( luaState.isNumber( -1 ) )
						{
							tax = luaState.checkNumber( -1 );
						}
						luaState.pop( 1 );
						
						// Shipping
						luaState.getField( -1, "shipping" );
						if ( luaState.isNumber( -1 ) )
						{
							shipping = luaState.checkNumber( -1 );
						}
						luaState.pop( 1 );
						
						// Intent
						luaState.getField( -1, "intent" );
						if ( luaState.isString( -1 ) )
						{
							paymentIntent = luaState.checkString( -1 );
						}
						luaState.pop( 1 );
					}
					else
					{
						System.out.println( "Error: paypal.show( 'payment' ), payment table expected, got " + luaState.typeName( -1 ) + "\n" );
					}
					luaState.pop( 1 );
					
					// Currency Code
					luaState.getField( -1, "currencyCode" );
					if ( luaState.isString( -1 ) )
					{
						currencyCode = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
					
					// Description
					luaState.getField( -1, "shortDescription" );
					if ( luaState.isString( -1 ) )
					{
						description = luaState.checkString( -1 );
					}
					else
					{
						System.out.println( "Error: shortDescription expected, got " + luaState.typeName( -1 ) + "\n" );
					}
					luaState.pop( 1 );
					
					// Accept Credit Cards
					luaState.getField( -1, "acceptCreditCards" );
					if ( luaState.isBoolean( -1 ) )
					{
						acceptCreditCards = luaState.checkBoolean( -1 );
					}
					luaState.pop( 1 );
					
					// BN Code
					luaState.getField( -1, "bnCode" );
					if ( luaState.isString( -1 ) )
					{
						bnCode = luaState.checkString( -1 );
					}
					luaState.pop( 1 );
				}
				// Pop the options table
				luaState.pop( 1 );

				// If the coronaActivity isn't null
	   			if ( coronaActivity != null )
	   			{
	   				// The payment intent
	   				String thePaymentIntent = null;

	   				// Set the payment intent to one of Paypal's payment constants
	   				if ( paymentIntent.equalsIgnoreCase( "sale" ) ) thePaymentIntent = PayPalPayment.PAYMENT_INTENT_SALE;
	   				else if ( paymentIntent.equalsIgnoreCase( "authorize" ) ) thePaymentIntent = PayPalPayment.PAYMENT_INTENT_AUTHORIZE;

	   				// The total payment amount
	   				Double paymentAmount = amount + tax + shipping;
	   				// The subtotal
	   				Double subTotal = paymentAmount - tax - shipping;

					// Create the Paypal Payment object
		   		 	PayPalPayment payment = new PayPalPayment( new BigDecimal( paymentAmount ), currencyCode, description, thePaymentIntent );

		   		 	// Set the bnCode if any
		   		 	if ( bnCode != null ) payment.bnCode( bnCode );

		   		 	// Create a payment details object
		   		 	PayPalPaymentDetails paymentDetails = new PayPalPaymentDetails( new BigDecimal( shipping ), new BigDecimal( subTotal ), new BigDecimal( tax ) );
		   		 	// Set the payment details
		   		 	payment.paymentDetails( paymentDetails );

		   		 	// Payment processable, lets proceed to show the PayPal payment view controller
		       		if ( payment.isProcessable() )
		       		{
		   		 		// Create the payment intent
		    			Intent intent = new Intent( coronaActivity, PaymentActivity.class );
		    			intent.putExtra( PaymentActivity.EXTRA_PAYMENT, payment );
		    			coronaActivity.startActivityForResult( intent, paymentRequestCode );
		    		}
		    		// The payment was not processable
		    		else
		    		{
		    			// If, for example, the amount was negative or the shortDescription was
						// empty, this payment wouldn't be processable, and you'd want to handle that here.

		    			// Corona runtime task dispatcher
		    			final CoronaRuntimeTaskDispatcher dispatcher = new CoronaRuntimeTaskDispatcher( luaState );

		    			// Create a new runnable object to invoke our activity
		    			Runnable runnableActivity = new Runnable()
		    			{
		    				public void run()
		    				{
		    					// Create the task
		    					paymentNotProcessableCallBackListenerTask task = new paymentNotProcessableCallBackListenerTask( listenerRef );

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
		    	}
			}
			// Future Payment
			else if ( viewControllerType.equalsIgnoreCase( "futurePayment" ) )
			{
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
					luaState.pop( 2 ); // Pop listener and options table
				}

				// If the coronaActivity isn't null
	   			if ( coronaActivity != null )
	   			{
					// Create the future payment intent
					Intent intent = new Intent( coronaActivity, PayPalFuturePaymentActivity.class );
	        		coronaActivity.startActivityForResult( intent, futurePaymentRequestCode );
	        	}
			}
			// Unrecognised option, show error
			else
			{
				System.out.println( "Error: Unrecognised 1st parameter passed to paypal.show(). Valid options are `payment` or `futurePayment`\n" );
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
