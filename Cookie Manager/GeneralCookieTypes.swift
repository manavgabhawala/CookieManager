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
		if self == .Safari || (self == .Chrome && rhs == .Safari)
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