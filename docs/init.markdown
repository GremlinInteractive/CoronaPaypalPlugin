### Overview

Initialises the PayPal library. This function is required and must be executed before making other PayPal calls such as `PayPal.config()` or `PayPal.show()`.

## Syntax

`````
PayPal.init( options )
`````

This function accepts a single argument, `options`, which is a table that accepts the following parameters:

##### listener - (optional)

__[Listener]__ This function is here for backwards compatibility only. it is not required. This function returns `event.status` with a fixed value of `valid`. As there is no more licensing validation being performed.

## Example

	-- Require the PayPal library
	local PayPal = require( "plugin.paypal" )

	-- Initialize the PayPal library
	PayPal.init(
	{
	    listener = function( event )
	        print( "Listener response:", event..status )
	    end
	})