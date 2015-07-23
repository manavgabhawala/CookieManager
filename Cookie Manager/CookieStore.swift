//
//  CookieStore.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 22/07/15.
//  Copyright © 2015 Manav Gabhawala. All rights reserved.
//

import Foundation

/// The notification name for when Safari's cookies are changed.
let safariCookiesChangedNotification = "SafariCookiesChangedNotification"

///  These are the possible errors that the CookieStore can throw.
enum CookieError : ErrorType
{
	/// A FilePermission error indicates that there was a problem accessing the file and either file doesn't exist or the user doesn't have enough privileges to access the cookie file.
	case FilePermissionError
	/// A FileParsing error indicates that there was an issue with reading the cookie file.
	case FileParsingError
}


/// This class is responsible for parsing, accessing and writing cookies for `Safari`
class CookieStore
{
	/// A jar of cookies created from the shared cookie store.
	private let cookieJar = NSHTTPCookieStorage.sharedHTTPCookieStorage()
	
	private var cookieStore = [HTTPCookie]()
	
	/// An array of cookies from the cookie jar or an empty array if no cookies exist.
	var cookies : [NSHTTPCookie]
	{
		return cookieJar.cookies ?? []
	}
	
	/// A URL to the cookies file setup inside the initializer.
	private let cookiesURL: NSURL
	
	///  Initializes the Safari cookie store.
	/// - Warning: This function takes a long time to run because the cookie store takes time to setup. Perform initialization on a background thread.
	///  - returns: nil if something goes wrong like if the cookie's file cannot be accessed. Otherwise this returns an initialized `CookieStore`.
	init?()
	{
		do
		{
			let fileManager = NSFileManager()
			let userLibraryURL = try fileManager.URLForDirectory(.LibraryDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: false)
			cookiesURL = userLibraryURL.URLByAppendingPathComponent("Cookies").URLByAppendingPathComponent("Cookies.binarycookies")
		}
		catch
		{
			cookiesURL = NSURL(string: "")!
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
			print("Could not find ~/Library/Cookies/Cookies.binarycookies")
			throw CookieError.FilePermissionError
		}
		return fd
	}
	
	///  Begins monitoring changes to the cookies file. It blocks on a background thread until the file is updated. Once it is updated, it calls `updateCookies`
	func startMonitoringCookieChanges()
	{
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
			let kQueue = kqueue()
			var kEvent = kevent()
			var theEvent = kevent()
			kEvent.filter = Int16(EVFILT_VNODE)
			kEvent.flags = UInt16(EV_ADD | EV_ENABLE | EV_CLEAR)
			kEvent.fflags = UInt32(NOTE_WRITE | NOTE_DELETE)
			kEvent.data = 0
			kEvent.udata = nil
			
			while true
			{
				do
				{
					let fd = try self.createFileDescriptor() // we need a new fd every time so that we get the refreshed changes.
					kEvent.ident = UInt(fd)
					kevent(kQueue, &kEvent, 1, nil, 0, nil) // watching for changes to the cookies
					kevent(kQueue, nil, 0, &theEvent, 1, nil) // block!
					try self.updateCookies(fd)
				}
				catch
				{
					// TODO: Signal that we can't monitor cookies anymore.
					return
				}
			}
		})
	}
	
	///  Updates the cookie store to contain all the cookies.
	///  - Parameter fileDescriptor: An optional file descriptor that the `callee` can use to parse the cookies, only use this parameter if the `caller` knows for sure it has a valid file descriptor to the cookies file. If you call it without this parameter, it creates a file descriptor on its own.
	///  - Throws: `CookieError` with `FilePermissionError` if the fd could not be created. A `FileParsingError` if the file could not be parse properly.
	func updateCookies(fileDescriptor: Int32? = nil) throws
	{
		return
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
			file.closeFile()
		}
		
		guard let header = String(data: file.readDataOfLength(4))
		else
		{
			throw CookieError.FileParsingError
		}
		
		guard header == "cook" // Short for cookies? Who knows? Special string
		else
		{
			assertionFailure("Cookie file format incorrect: no cook header found.")
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
		for size in pageSizes
		{
			pages.append(file.readDataOfLength(size))
		}
		for page in pages
		{
			var location = 0
			let pageHeaderRange = NSRange(location: location, length: 4) // Page header is always the first 4 bytes.
			location += pageHeaderRange.length
			let pageHeader = Int(binary: page.subdataWithRange(pageHeaderRange), endian: .LittleEndian)
			guard pageHeader == 256
			else
			{
				assertionFailure("Cookie file format incorrect: no beginning 4 bytes found for page header.")
				throw CookieError.FileParsingError
			}
			
			let numCookiesRange = NSRange(location: location, length: 4)
			location += numCookiesRange.length

			let numberOfCookies = Int(binary: page.subdataWithRange(numCookiesRange), endian: .BigEndian) // Number of cookies in each page, its always the first 4 bytes after the page header
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
				assertionFailure("Cookie file format incorrect: no ending 4 bytes found for page header end.")
				throw CookieError.FileParsingError
			}
			
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
					assertionFailure("Cookie file format incorrect: no 4 padding bytes found.")
					throw CookieError.FileParsingError
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
					assertionFailure("Cookie file format incorrect: no 4 end bytes found.")
					throw CookieError.FileParsingError
				}
				
				var dateRange = NSRange(location: location, length: 8)
				let expiryDate = NSDate(epochBinary: page.subdataWithRange(dateRange))
				dateRange.location += dateRange.length
				let creationDate = NSDate(epochBinary: page.subdataWithRange(dateRange))
				
				let URL =  String(readData: page, fromLocationTillNullChar: offset + URLOffset) // Fetch domain value from url offset
				let name = String(readData: page, fromLocationTillNullChar: offset + nameOffset) // Fetch cookie name from name offset
				let path = String(readData: page, fromLocationTillNullChar: offset + pathOffset) // Fetch cookie path from path offset
				let value = String(readData: page, fromLocationTillNullChar: offset + valueOffset) // Fetch cookie value from value offset
				
				let cookie = HTTPCookie(URL: URL, name: name, value: value, path: path, expiryDate: expiryDate, creationDate: creationDate, secure: secure, HTTPOnly: HTTPOnly, version: cookieType, comment: comment)
				cookieStore.append(cookie)
			}
		}
	}
}