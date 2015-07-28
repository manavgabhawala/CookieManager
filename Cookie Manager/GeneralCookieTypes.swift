//
//  GeneralCookieTypes.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 23/07/15.
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