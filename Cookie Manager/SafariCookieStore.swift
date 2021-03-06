//
//  CookieStore.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 22/07/15.
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

/// A callback mechanism for the safari cookie store.
protocol SafariCookieStoreDelegate : class, GenericCookieStoreDelegate
{
	func stoppedTrackingSafariCookies()
	func safariDomainsUpdated(domains: [(domain: String, cookies: [HTTPCookie])], eachProgress: Double, moreComing: Bool)
}


/// This class is responsible for parsing, accessing and writing cookies for `Safari`
final class SafariCookieStore: GenericCookieStore
{
	/// A jar of cookies created from the shared cookie store.
	private let cookieJar = NSHTTPCookieStorage.sharedHTTPCookieStorage()
	
	/// The delegate for the cookie store.
	weak var delegate: SafariCookieStoreDelegate?
	
	///  Initializes the Safari cookie store.
	/// - Warning: This function takes a long time to run because the cookie store takes time to setup. Perform initialization on a background thread.
	///  - returns: nil if something goes wrong like if the cookie's file cannot be accessed. Otherwise this returns an initialized `CookieStore`.
	init?(delegate: SafariCookieStoreDelegate)
	{
		self.delegate = delegate
		let cookiesURL : NSURL
		do
		{
			let fileManager = NSFileManager()
			let userLibraryURL = try fileManager.URLForDirectory(.LibraryDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: false)
			cookiesURL = userLibraryURL.URLByAppendingPathComponent("Cookies").URLByAppendingPathComponent("Cookies.binarycookies")
		}
		catch
		{
			cookiesURL = NSURL(string: "")!
			if #available(OSX 10.11, *)
			{
				super.init(cookiesURL: cookiesURL)
				return nil  // On later versions of OS X accessing the global store is not possible so we cannot do anything useful if the file wasn't found
			}
		}
		super.init(cookiesURL: cookiesURL)
		if #available(OSX 10.11, *) // If we are on a later version of OS X use the updateCookies method otherwise default to the other way.
		{
			do
			{
				try updateCookies()
			}
			catch
			{
				return nil // If updating the cookies fails return nil.
			}
			startMonitoringCookieChanges()
		}
		else
		{
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "cookiesChanged:", name:  NSHTTPCookieManagerCookiesChangedNotification, object: cookieJar)
			readCookiesFromJar()
		}
		
	}
	
	///  Updates the cookie store to contain all the cookies.
	///  - Parameter fileDescriptor: An optional file descriptor that the `callee` can use to parse the cookies, only use this parameter if the `caller` knows for sure it has a valid file descriptor to the cookies file. If you call it without this parameter or with nil, it creates a file descriptor on its own.
	///  - Throws: `CookieError` with `FilePermissionError` if the file descriptor could not be created. A `FileParsingError` if the file could not be parsed properly however, the function tries to be as robust as possible and only throws errors when absolutely necessary. As a result not all the domains will have associated cookies.
	override func updateCookies(fileDescriptor: Int32? = nil) throws
	{
		var startedBackgroundParsing = false
		
		delegate?.startedParsingCookies()
		let file: NSFileHandle
		if let fd = fileDescriptor
		{
			file = NSFileHandle(fileDescriptor: fd)
		}
		else
		{
			file = NSFileHandle(fileDescriptor: try createFileDescriptor())
		}
		defer
		{
			if !startedBackgroundParsing
			{
				delegate?.finishedParsingCookies()
			}
			file.closeFile()
		}
		guard cookieJar.cookies?.count == 0
		else
		{
			// We already have shared cookies from Safari return here.
			readCookiesFromJar()
			return
		}
		
		guard let header = String(data: file.readDataOfLength(4)) where header == "cook" // Short for cookies? Who knows? Special string
		else
		{
			throw CookieError.FileParsingError
		}
		
		let numberOfPages = Int(binary: file.readDataOfLength(4), endian: .LittleEndian) // Number of pages in binary file
		// Get the page sizes
		var pageSizes = [Int]()
		pageSizes.reserveCapacity(numberOfPages)
		for _ in 0..<numberOfPages
		{
			pageSizes.append(Int(binary: file.readDataOfLength(4), endian: .LittleEndian))
		}
		
		// Get the actual page data using the sizes.
		var pages = [(NSData, pageSizeOffset: Int, pageDataOffset: Int)]()
		pages.reserveCapacity(numberOfPages)
		for (i, size) in pageSizes.enumerate()
		{
			let dataOffset = Int(file.offsetInFile)
			pages.append((file.readDataOfLength(size), pageSizeOffset: 4 + 4 + i * 4, pageDataOffset: dataOffset))
		}
		startedBackgroundParsing = true
		let pageProgress = 1.0 / Double(numberOfPages)
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
			var thisCookieDomain = self.cookieDomains
			self.cookieDomains.removeAll(keepCapacity: true)
			var cachedCookieDomains = [(domain: String, cookies: [HTTPCookie])]()
			cachedCookieDomains.reserveCapacity(10)
			for (page, sizeOffset, dataOffset) in pages
			{
				var location = 0
				let pageHeaderRange = NSRange(location: location, length: 4) // Page header is always the first 4 bytes.
				location += pageHeaderRange.length
				let pageHeader = Int(binary: page.subdataWithRange(pageHeaderRange), endian: .LittleEndian)
				guard pageHeader == 256
				else
				{
					continue // Could not read data for page.
				}
				
				let numCookiesRange = NSRange(location: location, length: 4)
				location += numCookiesRange.length
				
				let numberOfCookies = Int(binary: page.subdataWithRange(numCookiesRange), endian: .BigEndian) // Number of cookies in each page, its always the first 4 bytes after the page header.
				
				// Cookie offsets.
				var cookieOffsets = [Int]()
				cookieOffsets.reserveCapacity(numberOfCookies)
				for _ in 0..<numberOfCookies
				{
					let cookieRange = NSRange(location: location, length: 4)
					location += cookieRange.length
					cookieOffsets.append(Int(binary: page.subdataWithRange(cookieRange), endian: .BigEndian))
				}
				
				let pageHeaderEndRange = NSRange(location: location, length: 4)
				let pageHeaderEnd = Int(binary: page.subdataWithRange(pageHeaderEndRange), endian: .BigEndian)
				guard pageHeaderEnd == 0 // end of page header.
				else
				{
					continue
				}
				var currentDomain : HTTPCookieDomain?
				for offset in cookieOffsets
				{
					location = offset
					let cookieSizeRange = NSRange(location: location, length: 4)
					_ = Int(binary: page.subdataWithRange(cookieSizeRange), endian: .BigEndian) // Read the cookie size.
					location += cookieSizeRange.length // Move the pointer to the beginning of the cookie data.
					
					let cookieType = Int(binary: page.subdataWithRange(NSRange(location: location, length: cookieSizeRange.length)), endian: .BigEndian)
					
					location += cookieSizeRange.length
					
					// Read the cookie's flags
					let flagRange = NSRange(location: location, length: 4)
					let flag = Int(binary: page.subdataWithRange(flagRange), endian: .BigEndian)
					location += flagRange.length
					// Cookie flags:  1=secure, 4=httponly, 5=secure+httponly
					var secure = false
					var HTTPOnly = false
					
					switch flag
					{
					case 0:
						break
					case 1:
						secure = true
						break
					case 4:
						HTTPOnly = true
						break
					case 5:
						secure = true
						HTTPOnly = true
						break
					default:
						print("Unknown cookie flag \(flag) found.")
					}
					let padding = Int(binary: page.subdataWithRange(NSRange(location: location, length: 4)), endian: .BigEndian)
					guard padding == 0
					else
					{
						continue
					}
					location += cookieSizeRange.length
					
					var standardRange = NSRange(location: location, length: 4)
					let URLOffset = Int(binary: page.subdataWithRange(standardRange), endian: .BigEndian) // Cookie domain offset from cookie starting point
					standardRange.location += standardRange.length
					let nameOffset = Int(binary: page.subdataWithRange(standardRange), endian: .BigEndian) // Cookie name offset from cookie starting point
					standardRange.location += standardRange.length
					let pathOffset = Int(binary: page.subdataWithRange(standardRange), endian: .BigEndian) // Cookie path offset from cookie starting point
					standardRange.location += standardRange.length
					let valueOffset = Int(binary: page.subdataWithRange(standardRange), endian: .BigEndian) // Cookie value offset from cookie starting point
					standardRange.location += standardRange.length
					location = standardRange.location
					
					let commentOffset = Int(binary: page.subdataWithRange(NSRange(location: location, length: cookieSizeRange.length)), endian: .BigEndian)
					location += cookieSizeRange.length
					let endBits = Int(binary: page.subdataWithRange(NSRange(location: location, length: cookieSizeRange.length)), endian: .BigEndian)
					location += cookieSizeRange.length
					
					let comment: String?
					if commentOffset != 0
					{
						comment = String(readData: page, fromLocationTillNullChar: offset + commentOffset)
					}
					else
					{
						comment = nil
					}
					guard endBits == 0
					else
					{
						continue
					}
					
					var dateRange = NSRange(location: location, length: 8)
					let expiryDate = NSDate(epochBinary: page.subdataWithRange(dateRange))
					dateRange.location += dateRange.length
					let creationDate = NSDate(epochBinary: page.subdataWithRange(dateRange))
					
					let URL =  String(readData: page, fromLocationTillNullChar: offset + URLOffset) // Fetch domain value from url offset
					let name = String(readData: page, fromLocationTillNullChar: offset + nameOffset) // Fetch cookie name from name offset
					let path = String(readData: page, fromLocationTillNullChar: offset + pathOffset) // Fetch cookie path from path offset
					let value = String(readData: page, fromLocationTillNullChar: offset + valueOffset) // Fetch cookie value from value offset
					
					// Create and add the cookie where required.
					let cookie = HTTPCookie(URL: URL, name: name, value: value, path: path, expiryDate: expiryDate, creationDate: creationDate, secure: secure, HTTPOnly: HTTPOnly, version: cookieType, browser: .Safari, comment: comment)
					
					if currentDomain == nil
					{
						currentDomain = HTTPCookieDomain(domain: URL, cookies: [cookie], capacity: numberOfCookies)
						
					}
					else
					{
						currentDomain!.addCookie(cookie)
					}
				}
				guard let domain = currentDomain
				else
				{
					continue
				}
				thisCookieDomain.removeElement(domain.domain)
				self.cookieDomains.append(domain.domain)
				cachedCookieDomains.append((domain: domain.domain, cookies: domain.cookies))
				if cachedCookieDomains.count >= 10
				{
					self.delegate?.safariDomainsUpdated(cachedCookieDomains, eachProgress: pageProgress, moreComing: true)
					cachedCookieDomains.removeAll(keepCapacity: true)
				}
			}
			self.delegate?.safariDomainsUpdated(cachedCookieDomains, eachProgress: pageProgress, moreComing: false)
			for domain in thisCookieDomain
			{
				self.delegate?.browser(.Safari, lostDomain: domain)
			}
		})
	}
	
	/// Reciever for a cookies changed notification dispatched on versions of Mac OS X before El Capitan.
	///
	///  - parameter notification: The notification that the cookie jar was updated.
	func cookiesChanged(notification: NSNotification)
	{
		readCookiesFromJar()
	}
	
	///  Reads cookies from the jar for versions of Mac OS X before El Capitan
	private func readCookiesFromJar()
	{
		let sortDescriptor = NSSortDescriptor(key: NSHTTPCookieDomain, ascending: true)
		let jarCookies = cookieJar.sortedCookiesUsingDescriptors([sortDescriptor])
		guard jarCookies.count > 0
		else
		{
			do
			{
				startMonitoringCookieChanges()
				try updateCookies()
			}
			catch
			{
				stoppedTrackingCookies()
			}
			return
		}
		delegate?.startedParsingCookies()
		var domain: HTTPCookieDomain?
		let doubleCount = Double(jarCookies.count)
		let cookieProgress = 1.0 / doubleCount
		for cookie in jarCookies
		{
			delegate?.progressMade(cookieProgress)
			if domain == nil
			{
				domain = HTTPCookieDomain(domain: cookie.domain, cookies: [HTTPCookie(cookie: cookie, browser: .Safari)], capacity: 1)
			}
			else
			{
				if domain!.domain == cookie.domain
				{
					domain!.addCookie(HTTPCookie(cookie: cookie, browser: .Safari))
				}
				else
				{
					delegate?.domainUpdated(domain!.domain, withCookies: domain!.cookies, forBrowser: .Safari)
					domain = HTTPCookieDomain(domain: cookie.domain, cookies: [HTTPCookie(cookie: cookie, browser: .Safari)], capacity: 1)
				}
			}
		}
		if let domain = domain
		{
			delegate?.domainUpdated(domain.domain, withCookies: domain.cookies, forBrowser: .Safari) // Add the last domain that didn't get added.
		}
		delegate?.finishedParsingCookies()
	}
	
	override func stoppedTrackingCookies()
	{
		delegate?.stoppedTrackingSafariCookies()
	}
	
	///  Removes a cookie from the domain from the binary file from safari.
	///
	///  - parameter cookie: The cookie to remove.
	///  - parameter domain: The domain from which to remove the cookie.
	func removeCookie(cookie: HTTPCookie, fromDomain domain: HTTPCookieDomain) throws
	{
		precondition(cookie.browser == .Safari)
		if #available(OSX 10.11, *)
		{
			cookieJar.deleteCookie(cookie.cookie)
		}
		let fd = try self.createFileDescriptor()
		let fileHandle = NSFileHandle(fileDescriptor: fd)
		fileHandle.seekToFileOffset(<#T##offset: UInt64##UInt64#>)
		
		if domain.cookies.count == 1 && domain.cookies.first! == cookie
		{
			// TODO: Reduce the number of pages and remove its size and all its data.
		}
	}
}