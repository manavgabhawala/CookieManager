//
//  FirefoxCookieStore.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 30/07/15.
//  Copyright © 2015 Manav Gabhawala. All rights reserved.
//

import Foundation

/// A callback mechanism for the firefox cookie store.
protocol FirefoxCookieStoreDelegate : class
{
	func stoppedTrackingFirefoxCookies()
	func startedParsingCookies()
	func finishedParsingCookies()
}

/// This class is responsible for parsing, accessing and writing cookies for `Firefox`
final class FirefoxCookieStore
{
	weak var delegate: FirefoxCookieStoreDelegate?
	
	
	init?(delegate: FirefoxCookieStoreDelegate)
	{
		self.delegate = delegate
		
	}
}