//
//  HTTPCookieDomain.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 24/07/15.
//  Copyright © 2015 Manav Gabhawala. All rights reserved.
//
// The MIT License (MIT)

// Copyright (c) 2015 Manav Gabhawala
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

/// An HTTPCookieDomain instance stores all the cookies for a particular domain. It also encapsulates other shared data between all the cookies in that particular domain.
class HTTPCookieDomain
{
	private(set) var cookies : [HTTPCookie]
	
	/// Returns the domain of the receiver. This value specifies URL domain to which the cookie should be sent. A domain with a leading dot means the cookie should be sent to subdomains as well, assuming certain other restrictions are valid. See RFC 2965 for more detail.
	var domain : String
	var type: Int?
	
	///  Initializes the `HTTPCookieDomain` with the parameters.
	///
	///  - parameter domain:   The domain for which this contains cookies.
	///  - parameter cookies:  The initial cookies with which to initialize the array
	///  - parameter capacity: The total number of cookies going to be added.
	///
	///  - returns: An initialized `HTTPCookieDomain` object.
	init(domain: String, cookies: [HTTPCookie], capacity: Int)
	{
		self.domain = domain
		self.cookies = cookies
		self.type = cookies.first?.version
		self.cookies.reserveCapacity(capacity)
	}
	
	///  Adds a cookie to this domain.
	///
	///  - parameter cookie: The cookie to add.
	func addCookie(cookie: HTTPCookie)
	{
		cookies.append(cookie)
		if type == nil
		{
			type = cookie.version
		}
	}
	
	///  Adds multiple cookies to the domain directly.
	///
	///  - parameter cookies: The cookies to add.
	func addCookies(cookies: [HTTPCookie])
	{
		self.cookies.reserveCapacity(self.cookies.count + cookies.count)
		if type == nil
		{
			type = cookies.first?.version
		}
		cookies.map { self.cookies.append($0) }
	}
	
	///  Removes cookies for a specific browser.
	///
	///  - parameter browser: The browser for which to remove the cookies.
	///  - returns: The number of cookies removed.
	func removeCookiesForBrowser(browser: Browser) -> Int
	{
		let startCount = cookies.count
		cookies = cookies.filter { $0.browser != browser }
		return startCount - cookies.count
	}
	
}
extension HTTPCookieDomain: Equatable {}
func ==(lhs: HTTPCookieDomain, rhs: HTTPCookieDomain) -> Bool
{
	return lhs.domain == rhs.domain && lhs.cookies.count == rhs.cookies.count
}

class HTTPCookieDomainWrapper
{
	let domain: HTTPCookieDomain
	init(domain: HTTPCookieDomain)
	{
		self.domain = domain
	}
}
