//
//  HTTPCookie.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 23/07/15.
//  Copyright © 2015 Manav Gabhawala. All rights reserved.
//

import Foundation

/// A HTTPCookie instance represents a single http cookie. It is an object initialized from a NSHTTPCookie that contains the various cookie attributes or for newer versions using the exact values of the cookies from the binary file. It has accessors and setters to get the various attributes of a cookie. It also has an update method to update the cookie's details.
struct HTTPCookie
{
	/// Returns the domain of the receiver. This value specifies URL domain to which the cookie should be sent. A domain with a leading dot means the cookie should be sent to subdomains as well, assuming certain other restrictions are valid. See RFC 2965 for more detail.
	var domain : String
	/// Returns the name of the receiver.
	var name: String
	/// Returns the value of the receiver.
	var value: String
	
	/// Whether the receiver should only be sent to HTTP servers per RFC 2965. Cookies may be marked as HTTPOnly by a server (or by a javascript). Cookies marked as such must only be sent via HTTP Headers in HTTP Requests for URL's that match both the path and domain of the respective Cookies. Specifically these cookies should not be delivered to any javascript applications to prevent cross-site scripting vulnerabilities. `true` if this cookie should only be sent via HTTP headers, `false` otherwise.
	var HTTPOnly: Bool
	
	/// Returns whether the receiver should be sent only over secure channels. Cookies may be marked secure by a server (or by a javascript). Cookies marked as such must only be sent via an encrypted connection to 	trusted servers (i.e. via SSL or TLS), and should not be delievered to any javascript applications to prevent cross-site scripting vulnerabilities. `true` if this cookie should be sent only over secure channels, `false` otherwise.
	var secure: Bool
	
	/// Returns the version of the receiver. Version 0 maps to "old-style" Netscape cookies. Version 1 maps to RFC2965 cookies. There may be future versions.
	var version: Int
	
	/// Returns the expires date of the receiver. The expires date is the date when the cookie should be deleted. The result will be nil if there is no specific expires date. This will be the case only for "session-only" cookies.
	var expiryDate : NSDate?
	
	/// Returns the path of the receiver. This value specifies the URL path under the cookie's domain for which this cookie should be sent. The cookie will also be sent for children of that path, so "/" is the most general.
	var path: String
	
	/// Returns the comment of the receiver. This value specifies a string which is suitable for presentation to the user explaining the contents and purpose of this cookie. It may be `nil`.
	var comment: String?
	
	/// An NSHTTPCookie representation of the HTTPCookie
	var cookie: NSHTTPCookie
	{
		get
		{
			var properties : [String : AnyObject] =
			  [ NSHTTPCookieDomain	:	self.domain,
				NSHTTPCookieName   	: 	self.name,
            	NSHTTPCookiePath		: 	self.path,
            	NSHTTPCookieValue	: 	self.value,
            	NSHTTPCookieVersion	: 	"\(version)"]
			if let expiry = expiryDate
			{
				if version == 0
				{
					properties[NSHTTPCookieExpires] = expiry
				}
				else
				{
					properties[NSHTTPCookieMaximumAge] = "\(expiry.timeIntervalSinceNow)"
				}
			}
			if version == 1 && comment != nil
			{
				properties[NSHTTPCookieComment] = comment!
			}
			return NSHTTPCookie(properties: properties)!
		}
		
	}
	
	
	///  Intializes the cookie using an NSHTTPCookie representation. This allows for the cookie to be created easily.
	///
	///  - parameter cookie: The cookie based on which this cookie is created.
	///
	///  - returns: An initialized HTTPCookie.
	init(cookie: NSHTTPCookie)
	{
		domain = cookie.domain
		name = cookie.name
		value = cookie.value
		secure = cookie.secure
		HTTPOnly = cookie.HTTPOnly
		expiryDate = cookie.expiresDate
		version = cookie.version
		path = cookie.path
		if version >= 1
		{
			comment = cookie.comment
		}
	}
	
	///  Intializes the cookie based on the values found from the binary. See the properties of this class for more information about the parameters.
	///
	///
	///  - returns: An initialized HTTPCookie
	init(URL: String, name: String, value: String, path: String, expiryDate: NSDate, creationDate: NSDate, secure: Bool, HTTPOnly: Bool, version: Int, comment: String?)
	{
		self.domain = URL
		self.value = value
		self.name = name
		self.expiryDate = expiryDate
		self.path = path
		self.HTTPOnly = HTTPOnly
		self.secure = secure
		self.version = version
		if self.version >= 1
		{
			self.comment = comment
		}
	}
	
	// TODO: Add functionality for modifying and deleting cookies.
}
extension HTTPCookie: Equatable
{
}
func ==(lhs: HTTPCookie, rhs: HTTPCookie) -> Bool
{
	// Enough properties that if these are all equal the cookie is probably equal.
	return  lhs.domain == rhs.domain && lhs.name == rhs.name && lhs.value == rhs.value && lhs.version == rhs.version && lhs.secure == rhs.secure
}
class HTTPCookieWrapper
{
	let cookie: HTTPCookie
	init(cookie: HTTPCookie)
	{
		self.cookie = cookie
	}
}

