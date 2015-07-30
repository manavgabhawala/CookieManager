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
protocol SafariCookieStoreDelegate : class
{
	func stoppedTrackingSafariCookies()
	func startedParsingCookies()
	func finishedParsingCookies()
	func safariDomainUpdated(domain: String, withCookies cookies: [HTTPCookie])
	func safariLostDomain(domain: String)
	func safariProgressMade(progress: Double)
}


/// This class is responsible for parsing, accessing and writing cookies for `Safari`
class SafariCookieStore
{
	/// A jar of cookies created from the shared cookie store.
	private let cookieJar = NSHTTPCookieStorage.sharedHTTPCookieStorage()
	
	/// The delegate for the cookie store.
	weak var delegate: SafariCookieStoreDelegate?
	
	/// A URL to the cookies file setup inside the initializer.
	private let cookiesURL: NSURL
	
	private var cookieDomains = [String]()
	
	///  Initializes the Safari cookie store.
	/// - Warning: This function takes a long time to run because the cookie store takes time to setup. Perform initialization on a background thread.
	///  - returns: nil if something goes wrong like if the cookie's file cannot be accessed. Otherwise this returns an initialized `CookieStore`.
	init?(delegate: SafariCookieStoreDelegate)
	{
		self.delegate = delegate
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
				return nil  // On later versions of OS X accessing the global store is not possible so we cannot do anything useful if the file wasn't found
			}
		}
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
	
	///  Creates a file descriptor to the cookies file.
	///
	///  - throws: `CookieError` with `FilePermissionError` if the fd could not be created.
	///  - returns: The file descriptor to the cookies file.
	func createFileDescriptor() throws -> Int32
	{
		var fd : CInt = 0
		var numTries = 0
		repeat
		{
			fd = open(self.cookiesURL.path!.fileSystemRepresentation(), O_EVTONLY, 0)
			if fd == 0
			{
				sleep(1)
				++numTries
			}
		} while fd == 0 && numTries > 10
		if numTries >= 10 || fd == 0
		{
			throw CookieError.FilePermissionError
		}
		return fd
	}
	
	/// Begins monitoring changes to the cookies file. It blocks on a background thread until the file is updated. Once it is updated, it calls `updateCookies`
	func startMonitoringCookieChanges()
	{
		let kQueue = kqueue()
		var kEvent = kevent()
		var theEvent = kevent()
		kEvent.filter = Int16(EVFILT_VNODE)
		kEvent.flags = UInt16(EV_ADD | EV_ENABLE | EV_CLEAR)
		kEvent.fflags = UInt32(NOTE_WRITE | NOTE_DELETE)
		kEvent.data = 0
		kEvent.udata = nil
		// Block on a background thread.
		dispatch_async(monitorQueue, {
			while true
			{
				do
				{
					let fd = try self.createFileDescriptor() // we need a new fd every time so that we get the refreshed changes.
					kEvent.ident = UInt(fd)
					kevent(kQueue, &kEvent, 1, nil, 0, nil) // watching for changes to the cookies
					kevent(kQueue, nil, 0, &theEvent, 1, nil) // block!
					try self.updateCookies(fd) // Now when this is executed the file was changed.
				}
				catch
				{
					// Error handling.
					self.delegate?.stoppedTrackingSafariCookies()
					return
				}
			}
		})
	}
	
	///  Updates the cookie store to contain all the cookies.
	///  - Parameter fileDescriptor: An optional file descriptor that the `callee` can use to parse the cookies, only use this parameter if the `caller` knows for sure it has a valid file descriptor to the cookies file. If you call it without this parameter or with nil, it creates a file descriptor on its own.
	///  - Throws: `CookieError` with `FilePermissionError` if the file descriptor could not be created. A `FileParsingError` if the file could not be parsed properly however, the function tries to be as robust as possible and only throws errors when absolutely necessary. As a result not all the domains will have associated cookies.
	func updateCookies(fileDescriptor: Int32? = nil) throws
	{
		var startedBackgroundParsing = false
		
		delegate?.startedParsingCookies()
		var cookieStore = [HTTPCookieDomain]()
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
		var pages = [NSData]()
		pages.reserveCapacity(numberOfPages)
		cookieStore.reserveCapacity(numberOfPages)
		for size in pageSizes
		{
			pages.append(file.readDataOfLength(size))
		}
		startedBackgroundParsing = true
		let pageProgress = 1.0 / Double(numberOfPages)
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
			var thisCookieDomain = self.cookieDomains
			self.cookieDomains.removeAll(keepCapacity: true)
			for page in pages
			{
				self.delegate?.safariProgressMade(pageProgress)
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
				self.delegate?.safariDomainUpdated(domain.domain, withCookies: domain.cookies)
			}
			for domain in thisCookieDomain
			{
				self.delegate?.safariLostDomain(domain)
			}
			self.delegate?.finishedParsingCookies()
		})
	}
	
	/// Reciever for a cookies changed notification dispatched on versions of Mac OS X before El Capitan.
	///
	///  - parameter notification: The notification that the cookie jar was updated.
	func cookiesChanged(notification: NSNotification)
	{
		readCookiesFromJar()
	}
	
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
				delegate?.stoppedTrackingSafariCookies()
			}
			return
		}
		delegate?.startedParsingCookies()
		var domain: HTTPCookieDomain?
		let doubleCount = Double(jarCookies.count)
		let cookieProgress = 1.0 / doubleCount
		for cookie in jarCookies
		{
			delegate?.safariProgressMade(cookieProgress)
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
					delegate?.safariDomainUpdated(domain!.domain, withCookies: domain!.cookies)
					domain = HTTPCookieDomain(domain: cookie.domain, cookies: [HTTPCookie(cookie: cookie, browser: .Safari)], capacity: 1)
				}
			}
		}
		if let domain = domain
		{
			delegate?.safariDomainUpdated(domain.domain, withCookies: domain.cookies) // Add the last domain that didn't get added.
		}
		delegate?.finishedParsingCookies()
	}
}