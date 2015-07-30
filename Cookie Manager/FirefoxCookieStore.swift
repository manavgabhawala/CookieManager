//
//  FirefoxCookieStore.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 30/07/15.
//  Copyright © 2015 Manav Gabhawala. All rights reserved.
//

import Foundation

/// A callback mechanism for the firefox cookie store.
protocol FirefoxCookieStoreDelegate : class, GenericCookieStoreDelegate
{
	func stoppedTrackingFirefoxCookies()
}

/// This class is responsible for parsing, accessing and writing cookies for `Firefox`
final class FirefoxCookieStore: GenericCookieStore
{
	weak var delegate: FirefoxCookieStoreDelegate?
	private let db : FMDatabase
	
	init?(delegate: FirefoxCookieStoreDelegate)
	{
		self.delegate = delegate
		let cookiesURL: NSURL
		do
		{
			let fileManager = NSFileManager()
			let userLibraryURL = try fileManager.URLForDirectory(.LibraryDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: false)
			let initialURL = userLibraryURL.URLByAppendingPathComponent("Application Support").URLByAppendingPathComponent("Firefox").URLByAppendingPathComponent("Profiles")
			
			let profiles = try fileManager.contentsOfDirectoryAtURL(initialURL, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants.union(NSDirectoryEnumerationOptions.SkipsHiddenFiles))
			
			guard let URL = profiles.first, let path = URL.path where fileManager.fileExistsAtPath(path)
			else
			{
				db = FMDatabase()
				cookiesURL = NSURL(string: "")!
				super.init(cookiesURL: cookiesURL)
				return nil
			}
			
			cookiesURL = URL.URLByAppendingPathComponent("cookies.sqlite")
			guard let db = FMDatabase(path: cookiesURL.path!) where db.open()
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
	override func updateCookies(fd: Int32? = nil) throws
	{
		delegate?.startedParsingCookies()
		defer { delegate?.finishedParsingCookies() }
		guard let count = db.intForQuery("SELECT COUNT(*) FROM moz_cookies"), let cookies = db.executeQuery("SELECT * FROM moz_cookies ORDER BY host")
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
			let URL = cookies.stringForColumn("host")
			domainsForCurrentUpdate.removeElement(URL)
			guard URL != nil
			else
			{
				continue
			}
			
			let name = cookies.stringForColumn("name")
			let value = cookies.stringForColumn("value")
			let path = cookies.stringForColumn("path")
			let expiryDate = NSDate(timeIntervalSince1970: cookies.doubleForColumn("expiry"))
			let creationDate = NSDate(timeIntervalSince1970: cookies.doubleForColumn("creationTime"))
			
			let secure = cookies.boolForColumn("isSecure")
			let HTTPOnly = cookies.boolForColumn("isHttpOnly")
			
			
			let cookie = HTTPCookie(URL: URL, name: name ?? "", value: value ?? "", path: path ?? "", expiryDate: expiryDate, creationDate: creationDate, secure: secure, HTTPOnly: HTTPOnly, version: 0, browser: .Firefox, comment: nil)
			if URL != domain?.domain
			{
				if let domain = domain
				{
					delegate?.domainUpdated(URL, withCookies: domain.cookies, forBrowser: .Firefox)
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
			delegate?.browser(.Firefox, lostDomain: domain)
		}
	}
	override func stoppedTrackingCookies()
	{
		delegate?.stoppedTrackingFirefoxCookies()
	}
}