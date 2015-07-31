//
//  GeneralCookieTypes.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 23/07/15.
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
import AppKit

let monitorQueue = dispatch_queue_create("ManavGabhawala.cookie-file-monitor", DISPATCH_QUEUE_CONCURRENT)

///  These are the possible errors that the `CookieStore`s can throw.
enum CookieError : ErrorType
{
	/// A FilePermission error indicates that there was a problem accessing the file and either file doesn't exist or the user doesn't have enough privileges to access the cookie file.
	case FilePermissionError
	/// A FileParsing error indicates that there was an issue with reading the cookie file.
	case FileParsingError
	/// The operation failed.
	case OperationFailedError
}

private let safariImage = NSImage(named: "Safari")!
private let chromeImage = NSImage(named: "Chrome")!
private let firefoxImage = NSImage(named: "Firefox")!

///  An enumeration of the browsers this utility supports.
enum Browser : String
{
	case Safari
	case Chrome
	case Firefox
	func compare(rhs: Browser) -> NSComparisonResult
	{
		guard self != rhs
		else
		{
			return NSComparisonResult.OrderedSame
		}
		if self == .Safari || (self == .Chrome && rhs != .Safari)
		{
			return NSComparisonResult.OrderedAscending
		}
		return NSComparisonResult.OrderedDescending
	}
	
	var image: NSImage
	{
		switch self
		{
		case .Safari:
			return safariImage
		case .Chrome:
			return chromeImage
		case .Firefox:
			return firefoxImage
		}
 	}
}

protocol GenericCookieStoreDelegate
{
	///  Called when the cookie store begins parsing cookies if there is a change in the cookie store, or for the first time data is being read.
	func startedParsingCookies()
	
	///  Called when the cookie store finishes parsing cookies. This call is balanced with calls to `startedParsingCookies`
	func finishedParsingCookies()
	///  Called when a store wants to report progress made. This call is done as frequently as needed for a smooth progress update yet as infrequently as possible without an impact to the smoothness of the progress being updated.
 	///
 	///  - parameter: progress The progress made. This value should be bound between `0.0` and `1.0` where `0.0` indicates no progress has been made so far. The progress made should be called with the value of the amount of progress made **since** the last call to the progress made method on the delegate.
	func progressMade(progress: Double)
	
	///  Called when the cookie store has parsed and now recieved an entire domain.
 	///
 	///  - parameter domain:  The domain that was parsed.
 	///  - parameter cookies: The cookies associated with the domain parsed.
 	///  - parameter browser: The browser for which the domain was parsed.
	func domainUpdated(domain: String, withCookies cookies: [HTTPCookie], forBrowser browser: Browser)
	
	///  Called just before parsing completes where the store can notify its delegate that it no longer has any cookies for a particular domain that it used to.
 	///
 	///  - parameter browser: The browser for which the domain was lost.
	 ///  - parameter domain:  The domain lost.
	func browser(browser: Browser, lostDomain domain: String)
}
