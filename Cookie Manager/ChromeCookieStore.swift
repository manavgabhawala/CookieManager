//
//  ChromeCookieStore.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 29/07/15.
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

/// A callback mechanism for the chrome cookie store.
protocol ChromeCookieStoreDelegate : class
{
	func stoppedTrackingChromeCookies()
	func startedParsingCookies()
	func finishedParsingCookies()
	func chromeProgressMade(progress: Double)
	func chromeDomainUpdated(domain: String, withCookies cookies: [HTTPCookie])
	func chromeLostDomain(domain: String)
}
/// This class is responsible for parsing, accessing and writing cookies for `Chrome`
class ChromeCookieStore
{
	private let cookiesURL : NSURL
	private let db : FMDatabase
	weak var delegate: ChromeCookieStoreDelegate?
	
	private var currentDomains = [String]()
	
	init?(delegate: ChromeCookieStoreDelegate)
	{
		self.delegate = delegate
		do
		{
			let fileManager = NSFileManager()
			let userLibraryURL = try fileManager.URLForDirectory(.LibraryDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: false)
			cookiesURL = userLibraryURL.URLByAppendingPathComponent("Application Support").URLByAppendingPathComponent("Google").URLByAppendingPathComponent("Chrome").URLByAppendingPathComponent("Default").URLByAppendingPathComponent("Cookies")
			guard let path = cookiesURL.path where fileManager.fileExistsAtPath(path)
			else
			{
				db = FMDatabase()
				return nil
			}
			guard let db = FMDatabase(path: path) where db.open()
			else
			{
				self.db = FMDatabase()
				return nil
			}
			self.db = db
		}
		catch
		{
			cookiesURL = NSURL(string: "")!
			db = FMDatabase()
			return nil
		}
		do
		{
			try updateCookies()
		}
		catch
		{
			return nil
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
					try self.updateCookies() // Now when this is executed the file was changed.
				}
				catch
				{
					// Error handling.
					self.delegate?.stoppedTrackingChromeCookies()
					return
				}
			}
		})
	}
	
	
	func updateCookies() throws
	{
		delegate?.startedParsingCookies()
		
		guard let count = db.intForQuery("SELECT COUNT(*) FROM cookies"), let cookies = db.executeQuery("SELECT * FROM cookies ORDER BY host_key")
		else
		{
			throw CookieError.FileParsingError
		}
		
		var domainsForCurrentUpdate = currentDomains
		currentDomains.removeAll(keepCapacity: true)
		
		let cookieProgress = 1.0 / Double(count)
		var domain : HTTPCookieDomain?
		while cookies.next()
		{
			let URL = cookies.stringForColumn("host_key")
			domainsForCurrentUpdate.removeElement(URL)
			guard URL != nil
			else
			{
				continue
			}
			
			let name = cookies.stringForColumn("name")
			let value = cookies.stringForColumn("value")
			let path = cookies.stringForColumn("path")
			let expiryDate = NSDate(timeIntervalSince1970: cookies.doubleForColumn("expires_utc"))
			let creationDate = NSDate(timeIntervalSince1970: cookies.doubleForColumn("creation_utc"))
			
			let secure = cookies.boolForColumn("secure")
			let HTTPOnly = cookies.boolForColumn("httponly")
			
			
			let cookie = HTTPCookie(URL: URL, name: name ?? "", value: value ?? "", path: path ?? "", expiryDate: expiryDate, creationDate: creationDate, secure: secure, HTTPOnly: HTTPOnly, version: 0, browser: .Chrome, comment: nil)
			if URL != domain?.domain
			{
				if let domain = domain
				{
					delegate?.chromeDomainUpdated(URL, withCookies: domain.cookies)
				}
				currentDomains.append(URL)
				domain = HTTPCookieDomain(domain: URL, cookies: [cookie], capacity: 1)
			}
			else
			{
				domain!.addCookie(cookie)
			}
			delegate?.chromeProgressMade(cookieProgress)
		}
		
		for domain in domainsForCurrentUpdate
		{
			delegate?.chromeLostDomain(domain)
		}
		delegate?.finishedParsingCookies()
	}
	
}