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
}

class CookieStore
{
	weak var delegate: CookieStoreDelegate?
	
	private var safariStore: SafariCookieStore?
	private var chromeStore: ChromeCookieStore?
	private var firefoxStore : FirefoxCookieStore?
	
	private var cookieHash = [String : HTTPCookieDomain]()
	{
		didSet
		{
			if cookieHash.count % 20 == 0
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
	func domainAtIndex(index: Int) -> HTTPCookieDomain?
	{
		guard index >= 0 && index < sortedHash.count, let domain = cookieHash[sortedHash[index]]
		else
		{
			sortedHash = cookieHash.keys.sort(<)
			return nil
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
}

// MARK: - Shared
extension CookieStore
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
		myProgress -= 1.0
		sortedHash = cookieHash.keys.sort(<)
		if currentParses == 0
		{
			delegate?.finishedParsingCookies()
		}
	}
}
// MARK: - Safari Store
extension CookieStore : SafariCookieStoreDelegate
{
	func stoppedTrackingSafariCookies()
	{
		delegate?.stoppedTrackingCookiesForBrowser(.Safari)
		safariStore = nil
	}
	func safariProgressMade(progress: Double)
	{
		myProgress += progress
		delegate?.madeProgress(myProgress / Double(currentParses))
	}
	func safariDomainUpdated(domain: String, withCookies cookies: [HTTPCookie])
	{
		if let existingDomain = cookieHash[domain]
		{
			cookieCount -= existingDomain.cookies.count
			existingDomain.removeCookiesForBrowser(.Safari)
			existingDomain.addCookies(cookies)
			cookieCount += existingDomain.cookies.count
		}
		else
		{
			guard cookies.count > 0
			else
			{
				return
			}
			cookieCount += cookies.count
			cookieHash[domain] = HTTPCookieDomain(domain: domain, cookies: cookies, capacity: cookies.count)
		}
	}
	func safariLostDomain(domain: String)
	{
		guard let HTTPDomain = cookieHash[domain]
		else
		{
			return
		}
		cookieCount -= HTTPDomain.removeCookiesForBrowser(.Safari)
		if HTTPDomain.cookies.count == 0
		{
			cookieHash.removeValueForKey(domain)
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
	}
	func chromeProgressMade(progress: Double)
	{
		myProgress += progress
		delegate?.madeProgress(myProgress / Double(currentParses))
	}
	func chromeDomainUpdated(domain: String, withCookies cookies: [HTTPCookie])
	{
		if let existingDomain = cookieHash[domain]
		{
			cookieCount -= existingDomain.cookies.count
			existingDomain.removeCookiesForBrowser(.Chrome)
			existingDomain.addCookies(cookies)
			cookieCount += existingDomain.cookies.count
		}
		else
		{
			guard cookies.count > 0
				else
			{
				return
			}
			cookieCount += cookies.count
			cookieHash[domain] = HTTPCookieDomain(domain: domain, cookies: cookies, capacity: cookies.count)
		}
	}
	func chromeLostDomain(domain: String)
	{
		guard let HTTPDomain = cookieHash[domain]
		else
		{
			return
		}
		cookieCount -= HTTPDomain.removeCookiesForBrowser(.Chrome)
		if HTTPDomain.cookies.count == 0
		{
			cookieHash.removeValueForKey(domain)
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
