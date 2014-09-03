--
--[[
//
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
// ----------------------------------------------------------------------------
--]]
--
-- Abstract: Paypal plugin sample app
--
-- Version: 1.0

-- Related PayPal documentation
--[[
https://github.com/paypal/PayPal-iOS-SDK
https://github.com/paypal/PayPal-iOS-SDK/blob/master/README.md
https://github.com/paypal/PayPal-iOS-SDK/blob/master/docs/future_payments_mobile.md
https://github.com/paypal/PayPal-iOS-SDK/blob/master/docs/future_payments_server.md#obtain-oauth2-tokens
https://developer.paypal.com/webapps/developer/docs/integration/mobile/make-future-payment/#required-best-practices-for-future-payments
https://github.com/paypal/PayPal-iOS-SDK/blob/master/docs/single_payment.md
https://developer.paypal.com/webapps/developer/docs/integration/mobile/verify-mobile-payment/
--]]

--[[
-- Images used in this sample code are sourced from www.openclipart.org
Background image: http://openclipart.org/detail/191047/background-design-by-anarres-191047
T-Shirt image: http://openclipart.org/detail/177398/blue-polo-shirt-remix-by-merlin2525-177398
Bus: http://openclipart.org/detail/182939/bus-1-by-Jarno-182939
Button: http://openclipart.org/detail/26272/pill-button-yellow-by-anonymous
--]]

-- Require the Paypal library
local paypal = require( "plugin.paypal" )
local widget = require( "widget" )
local json = require( "json" )

-- Set the widget theme to iOS 6
widget.setTheme( "widget_theme_ios" )

-- Hide the status bar
display.setStatusBar( display.HiddenStatusBar )

-- Initialize PayPal
paypal.init
{
	listener = function( event )
		for k, v in pairs( event ) do
			print( k, v )
		end
	end,
}

-- Configure PayPal
paypal.config
{
	productionClientID = "",
	sandboxClientID = "",
	acceptCreditCards = true, --true/false (optional) -- default false
	language = "en", --The users language/locale -- If omitted paypal will show it's views in accordance with the device's current language setting.
	merchant =
	{
		name = "Your Company Name", -- (required) -- The name of the merchant/company
		privacyPolicyURL = "", -- (optional) -- The merchants privacy policy url -- default is paypals privacy policy url
		userAgreementURL = "", -- (optional) -- The user agreement URL -- default is paypals user agreement url
	},
	rememberUser = false,
	environment = "sandbox", -- Valid values: "sandbox", "noNetwork", "production"
	-- Uncomment the below lines and fill in with your details, if required.
	---[[
	sandbox = 
	{
		useDefaults = true,
		password = "",
		pin = "",
	},
	user = 
	{
		email = "",
		phoneNumber = "",
		phoneCountryCode = "",
	},--]]
}

-- Display a background
local background = display.newImageRect( "paypalBk.png", 320, 480 )
background.x = display.contentCenterX
background.y = display.contentCenterY

-- Display the name of the sample code
local sampleCodeNameText = display.newText
{
	text = "PayPal Plugin Sample Code",
	font = native.systemFontBold,
	fontSize = 18,
}
sampleCodeNameText.anchorX = 0.5
sampleCodeNameText.anchorY = 0
sampleCodeNameText.x = display.contentCenterX
sampleCodeNameText.y = 10

-- Display the t-shirt image
local tShirt = display.newImageRect( "t-shirt.png", 120, 110 )
tShirt.anchorX = 0.5
tShirt.anchorY = 0
tShirt.x = display.contentCenterX
tShirt.y = 50

-- Create some text to show the t-shirt name and price
local tShirtDescriptionText = display.newText
{
	text = "Item: T-Shirt\nPrice: $50",
	font = native.systemFont,
	fontSize = 14,
	width = 200,
	align = "center",
}
tShirtDescriptionText.anchorX = 0.5
tShirtDescriptionText.anchorY = 1
tShirtDescriptionText.x = tShirt.x
tShirtDescriptionText.y = tShirt.y + tShirt.contentHeight + tShirtDescriptionText.contentHeight

-- Create the pay button
local payButton = widget.newButton
{
	label = "Buy Now!",
	onRelease = function( event )
		paypal.show( "payment",
		{
			payment =
			{
				amount = 30.00,
				tax = 10.00,
				shipping = 10.00,
				intent = "sale", -- Values "sale" and "authorize"
			},
			--bnCode = "XX",
			currencyCode = "USD",
			shortDescription = "Green T-Shirt",
			--acceptCreditCards = false,
			listener = function( event )
				-- Print the event table
				print( "event table: {" )
				for k, v in pairs( event ) do
					if k ~= "response" then
						print( k, ":", v )
					end
				end
				print( "}" )

				if event.response then
					local confirmation = json.decode( event.response )
					
					for k, v in pairs( confirmation ) do
						if type( v ) == "table" then
							print( "response table: {" )
							for k1, v1 in pairs( v ) do
								print( k1, ":", v1 )
							end
							print( "}" )
						else
							print( k, ":", v )
						end
					end
				else
					for k, v in pairs( event ) do
						print( k, ":", v )
					end
				end
			end,
		})
	end,
}
payButton.x = display.contentCenterX
payButton.y = tShirtDescriptionText.y + tShirtDescriptionText.contentHeight


-- Display the bus image
local bus = display.newImage( "bus.png", 213, 110 )
bus.x = display.contentCenterX
bus.y = payButton.y + payButton.contentHeight + ( bus.contentHeight * 0.5 ) - 10

-- Create some text to show the bus name and price
local busDescriptionText = display.newText
{
	text = "Item: Bus Ticket Auto Pass\nPrice: $5 Per Trip",
	font = native.systemFont,
	fontSize = 14,
	width = 200,
	align = "center",
}
busDescriptionText.anchorX = 0.5
busDescriptionText.anchorY = 1
busDescriptionText.x = bus.x
busDescriptionText.y = bus.y + bus.contentHeight - 18

-- Create a button to show a future payment window
local futurePaymentButton = widget.newButton
{
	label = "View Agreement",
	onRelease = function( event )
		paypal.show( "futurePayment",
		{
			listener = function( event )
				-- Print the event table
				print( "event table: {" )
				for k, v in pairs( event ) do
					if k ~= "response" then
						print( k, ":", v )
					end
				end
				print( "}" )
				
				--
				if event.response then
					local confirmation = json.decode( event.response )
					
					for k, v in pairs( confirmation ) do
						if type( v ) == "table" then
							print( "table: {" )
							for k1, v1 in pairs( v ) do
								print( k1, ":", v1 )
							end
							print( "}" )
						else
							print( k, ":", v )
						end
					end
				else
					for k, v in pairs( event ) do
						print( k, ":", v )
					end
				end
			end,
		})
	end,
}
futurePaymentButton.x = display.contentCenterX
futurePaymentButton.y = busDescriptionText.y + busDescriptionText.contentHeight
