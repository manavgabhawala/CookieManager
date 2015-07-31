//
//  CookieStore.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 29/07/15.
//  Copyright © 2015 Manav Gabhawala. All rights reserved.
//

import Foundation

protocol CookieStoreDelegate: class
{
	
	func startedParsingCookies()
	func finishedParsingCookies()
	
	func stoppedTrackingCookiesForBrowser(browser: Browser)
	
	func madeProgress(progress: Double)
	
	func updatedCookies()
	func fullUpdate()
}

final class CookieStore
{
	weak var delegate: CookieStoreDelegate?
	
	private var safariStore: SafariCookieStore?
	private var chromeStore: ChromeCookieStore?
	private var firefoxStore : FirefoxCookieStore?
	
	private let cookieHashQueue : dispatch_queue_t
	
	private var cookieHash = [String : HTTPCookieDomain]()
	{
		didSet
		{
			if cookieHash.count % 50 == 0
			{
				delegate?.updatedCookies()
			}
		}
	}
	private var sortedHash = [String]()
	private(set) var cookieCount : Int = 0
	
	
	private var currentParses = 0
	
	private var myProgress = 0.0
	
	var domainCount : Int
	{
		return cookieHash.count
	}
	
	
	init(delegate: CookieStoreDelegate? = nil)
	{
		self.delegate = delegate
		cookieHashQueue = dispatch_queue_create("ManavGabhawala.cookie-hash", DISPATCH_QUEUE_SERIAL)
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
			self.safariStore = SafariCookieStore(delegate: self)
		})
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
			self.chromeStore = ChromeCookieStore(delegate: self)
		})
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
			self.firefoxStore = FirefoxCookieStore(delegate: self)
		})
	}
	
	func availableBrowsers() -> [Browser]
	{
		var browsers = [Browser]()
		if safariStore != nil
		{
			browsers.append(.Safari)
		}
		if chromeStore != nil
		{
			browsers.append(.Chrome)
		}
		if firefoxStore != nil
		{
			browsers.append(.Firefox)
		}
		return browsers
	}
	func domainAtIndex(index: Int, useRecursion: Bool = true) -> HTTPCookieDomain?
	{
		guard index >= 0 && index < sortedHash.count, let domain = cookieHash[sortedHash[index]]
		else
		{
			sortedHash = cookieHash.keys.sort(<)
			return useRecursion ? domainAtIndex(index, useRecursion: false) : nil
		}
		return domain
	}
	func searchUsingString(string: String) -> [HTTPCookieDomain]
	{
		let searchStrings = string.componentsSeparatedByString(" ")
		let domainsToSend = cookieHash.filter
		{
			for search in searchStrings
			{
				if $0.0.caseInsensitiveContainsString(search)
				{
					return true
				}
				for cookie in $0.1.cookies
				{
					if cookie.name.caseInsensitiveContainsString(search)
					{
						return true
					}
					if cookie.value.caseInsensitiveContainsString(search)
					{
						return true
					}
					if cookie.secure && search == "secure"
					{
						return true
					}
				}
			}
			return false
		}
		return domainsToSend.sort { $0.0 < $1.0 }.map { $0.1 }
	}
	func deleteCookies(cookies: [HTTPCookie]) throws
	{
		guard cookies.count > 0
		else
		{
			return
		}
		
		let firefoxCookies = cookies.filter { $0.browser == .Firefox }
		let firefoxIDs = firefoxCookies.map { $0.firefoxID! }
		do
		{
			try firefoxStore?.deleteRows(firefoxIDs)
		}
		for cookie in firefoxCookies
		{
			guard let dom = cookieHash[cookie.domain]
			else { continue }
			if dom.removeCookie(cookie)
			{
				--cookieCount
			}
			if dom.cookies.count == 0
			{
				cookieHash.removeValueForKey(cookie.domain)
			}
		}
		let chromeCookies = cookies.filter { $0.browser == .Chrome }
		let chromeIDs = chromeCookies.map { $0.creationDate!.timeIntervalSince1970 }
		do
		{
			try chromeStore?.deleteRows(chromeIDs)
		}
		for cookie in chromeCookies
		{
			guard let dom = cookieHash[cookie.domain]
			else { continue }
			if dom.removeCookie(cookie)
			{
				--cookieCount
			}
			if dom.cookies.count == 0
			{
				cookieHash.removeValueForKey(cookie.domain)
			}
		}
		let safariCookies = cookies.filter { $0.browser == .Safari }
		safariCookies
		guard let domain = cookieHash[cookies.first!.domain]
		else
		{
			return
		}
		if domain.cookies.count == 0
		{
			// TODO: Delete the domain also
		}
		delegate?.fullUpdate()
	}
}

// MARK: - Shared
extension CookieStore : GenericCookieStoreDelegate
{
	func startedParsingCookies()
	{
		if currentParses == 0
		{
			delegate?.startedParsingCookies()
		}
		++currentParses
	}
	func finishedParsingCookies()
	{
		--currentParses
		currentParses = max(0, currentParses)
		myProgress -= 1.0
		sortedHash = cookieHash.keys.sort(<)
		if currentParses == 0
		{
			delegate?.finishedParsingCookies()
		}
	}
	func progressMade(progress: Double)
	{
		myProgress += progress
		delegate?.madeProgress(myProgress / Double(currentParses))
	}
	func domainUpdated(domain: String, withCookies cookies: [HTTPCookie], forBrowser browser: Browser)
	{
		self.domainUpdated(domain, withCookies: cookies, forBrowser: browser, progressTime: nil)
	}
	
	func domainUpdated(domain: String, withCookies cookies: [HTTPCookie], forBrowser browser: Browser, progressTime: Double?, moreComing: Bool = true)
	{
		dispatch_async(cookieHashQueue, {
			defer
			{
				if let prog = progressTime
				{
					self.progressMade(prog)
				}
				if !moreComing
				{
					self.finishedParsingCookies()
				}
			}
			if let existingDomain = self.cookieHash[domain]
			{
				guard (existingDomain.cookies.filter { $0.browser == browser }) != cookies
				else
				{
					return
				}
				self.cookieCount -= existingDomain.cookies.count
				existingDomain.removeCookiesForBrowser(browser)
				existingDomain.addCookies(cookies)
				self.cookieCount += existingDomain.cookies.count
			}
			else
			{
				guard cookies.count > 0
				else
				{
					return
				}
				self.cookieCount += cookies.count
				self.cookieHash[domain] = HTTPCookieDomain(domain: domain, cookies: cookies, capacity: cookies.count)
			}
		})
	}
	func browser(browser: Browser, lostDomain domain: String)
	{
		dispatch_async(cookieHashQueue, {
			guard let HTTPDomain = self.cookieHash[domain]
			else
			{
				return
			}
			self.cookieCount -= HTTPDomain.removeCookiesForBrowser(browser)
			if HTTPDomain.cookies.count == 0
			{
				self.cookieHash.removeValueForKey(domain)
			}
		})
	}
	
}
// MARK: - Safari Store
extension CookieStore : SafariCookieStoreDelegate
{
	func safariDomainsUpdated(domains: [(domain: String, cookies: [HTTPCookie])], eachProgress: Double, moreComing: Bool)
	{
		for domain in domains
		{
			self.domainUpdated(domain.domain, withCookies: domain.cookies, forBrowser: .Safari, progressTime: eachProgress, moreComing: moreComing)
		}
	}
	func stoppedTrackingSafariCookies()
	{
		delegate?.stoppedTrackingCookiesForBrowser(.Safari)
		safariStore = nil
		cookieHash.map { $0.1.removeCookiesForBrowser(.Safari) }
		for (domain, store) in cookieHash
		{
			if store.cookies.count == 0
			{
				cookieHash.removeValueForKey(domain)
			}
		}
	}
}
// MARK: - Chrome Store
extension CookieStore: ChromeCookieStoreDelegate
{
	func stoppedTrackingChromeCookies()
	{
		delegate?.stoppedTrackingCookiesForBrowser(.Chrome)
		chromeStore = nil
		cookieHash.map { $0.1.removeCookiesForBrowser(.Chrome) }
		for (domain, store) in cookieHash
		{
			if store.cookies.count == 0
			{
				cookieHash.removeValueForKey(domain)
			}
		}
 	}
}
// MARK: - Firefox Store
extension CookieStore : FirefoxCookieStoreDelegate
{
	func stoppedTrackingFirefoxCookies()
	{
		delegate?.stoppedTrackingCookiesForBrowser(.Firefox)
		firefoxStore = nil
	}
}
