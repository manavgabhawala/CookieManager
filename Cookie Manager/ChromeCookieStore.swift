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
protocol ChromeCookieStoreDelegate : class, GenericCookieStoreDelegate
{
	func stoppedTrackingChromeCookies()
}
private let tableName = "cookies"
/// This class is responsible for parsing, accessing and writing cookies for `Chrome`
final class ChromeCookieStore : GenericCookieStore
{
	private let db : FMDatabase
	weak var delegate: ChromeCookieStoreDelegate?
	
	init?(delegate: ChromeCookieStoreDelegate)
	{
		self.delegate = delegate
		let cookiesURL: NSURL
		do
		{
			let fileManager = NSFileManager()
			let userLibraryURL = try fileManager.URLForDirectory(.LibraryDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: false)
			cookiesURL = userLibraryURL.URLByAppendingPathComponent("Application Support").URLByAppendingPathComponent("Google").URLByAppendingPathComponent("Chrome").URLByAppendingPathComponent("Default").URLByAppendingPathComponent("Cookies")
			guard let path = cookiesURL.path where fileManager.fileExistsAtPath(path)
			else
			{
				db = FMDatabase()
				super.init(cookiesURL: cookiesURL)
				return nil
			}
			guard let db = FMDatabase(path: path) where db.open()
			else
			{
				self.db = FMDatabase()
				super.init(cookiesURL: cookiesURL)
				return nil
			}
			self.db = db
		}
		catch
		{
			cookiesURL = NSURL(string: "")!
			db = FMDatabase()
			super.init(cookiesURL: cookiesURL)
			return nil
		}
		super.init(cookiesURL: cookiesURL)
		do
		{
			try updateCookies()
		}
		catch
		{
			return nil
		}
	}
	deinit
	{
		db.close()
	}
	override func updateCookies(fd: Int32? = nil) throws
	{
		delegate?.startedParsingCookies()
		defer { delegate?.finishedParsingCookies() }
		guard let count = db.intForQuery("SELECT COUNT(*) FROM \(tableName)"), let cookies = db.executeQuery("SELECT * FROM \(tableName) ORDER BY host_key")
		else
		{
			throw CookieError.FileParsingError
		}
		
		var domainsForCurrentUpdate = cookieDomains
		
		cookieDomains.removeAll(keepCapacity: true)
		
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
					delegate?.domainUpdated(domain.domain, withCookies: domain.cookies, forBrowser: .Chrome)
				}
				cookieDomains.append(URL)
				domain = HTTPCookieDomain(domain: URL, cookies: [cookie], capacity: 1)
			}
			else
			{
				domain!.addCookie(cookie)
			}
			delegate?.progressMade(cookieProgress)
		}
		
		for domain in domainsForCurrentUpdate
		{
			delegate?.browser(.Chrome, lostDomain: domain)
		}
	}
	override func stoppedTrackingCookies()
	{
		delegate?.stoppedTrackingChromeCookies()
	}
	func deleteRows(ids: [Double]) throws
	{
		guard ids.count > 0
		else
		{
			return
		}
		var idsString = ids.reduce("", combine: { "\($0), \(Int($1))"})
		idsString.removeRange(Range<String.Index>(start: idsString.startIndex, end: advance(idsString.startIndex, 2)))
		db.beginTransaction()
		guard db.executeStatements("DELETE FROM \(tableName) WHERE creation_utc IN (\(idsString))")
		else
		{
			throw CookieError.OperationFailedError
		}
		db.commit()
	}
}