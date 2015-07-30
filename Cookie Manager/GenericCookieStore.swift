//
//  GenericCookieStore.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 30/07/15.
//  Copyright © 2015 Manav Gabhawala. All rights reserved.
//

import Foundation


class GenericCookieStore
{
	/// A URL to the cookies file setup inside the initializer.
	let cookiesURL: NSURL
	
	/// The current domains that exist in the cookies.
	var cookieDomains : [String]
	
	init(cookiesURL : NSURL)
	{
		self.cookiesURL = cookiesURL
		self.cookieDomains = [String]()
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
					self.stoppedTrackingCookies()
					return
				}
			}
		})
	}
	
	func stoppedTrackingCookies()
	{
		fatalError("Subclasses must implement this method")
	}
	
	func updateCookies(fd: Int32? = nil) throws
	{
		fatalError("Subclasses must implement this method.")
	}
}