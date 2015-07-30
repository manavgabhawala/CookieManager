//
//  Extensions.swift
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


extension String
{
	///  An initializer that allows for a native Swift `String` to be created using `NSData`
	///
	///  - parameter data:     The data with which to create the `String`
	///  - parameter encoding: The encoding with which to parse the data. This defaults to `NSUTF8StringEncoding` if no encoding is specified.
	///
	///  - returns: nil if the data passed was nil or if the `String` couldn't be formed using the encoding specified.
	init?(data: NSData?, encoding: NSStringEncoding = NSUTF8StringEncoding)
	{
		guard let data = data
		else
		{
			return nil
		}
		guard let str = NSString(data: data, encoding: encoding) as? String
		else
		{
			return nil
		}
		self.init(str)
	}
	
	///  Initializes a String by reading data from an `NSData` instance one character at a time until it reaches a null character.
	///
	///  - parameter data:     The data from which to read off to form the string.
	///  - parameter location: The location inside the data from which to start reading the `String` one character at a time.
	///  - parameter encoding: The encoding with which to parse the data. This defaults to `NSUTF8StringEncoding` if no encoding is specified.
	///
	///  - returns: An initialized string with the characters till a null character or `\0` was read or if the data couldn't be converted to a string using the encoding specified. This can return an empty `String` too if the first character read was null.
	init(readData data: NSData, fromLocationTillNullChar location: Int, encoding: NSStringEncoding = NSUTF8StringEncoding)
	{
		self = ""
		var range = NSRange(location: location, length: 1)
		while let str = String(data: data.subdataWithRange(range), encoding: encoding) where str != "\0"
		{
			self += str
			++range.location
		}
	}
	
	///  A function that checks if the reciever contains a string with considering case.
	///
	///  - parameter string: The string which should be inside the reciever.
	///
	///  - returns: `true` if the string is contained. Else `false`
	func caseInsensitiveContainsString(string: String) -> Bool
	{
		return self.rangeOfString(string, options: NSStringCompareOptions.CaseInsensitiveSearch) != nil
	}
}
///  This enum specifies the types of Endianness available to parse binary data.
enum Endianness
{
	/// BigEndian meaning the first bits are least significant (reversed).
	case BigEndian
	/// LittleEndian meaning the first bits are most significant.
	case LittleEndian
}

extension Int
{
	///  Creates an Integer from binary data using the endian to parse the binary data.
	///
	///  - Warning: This function will fail if the `length` of `data != 4`. Therefore data must be of length 4.
	///  - parameter data:   The binary data to use to form the integer.
	///  - parameter endian: The endianness with which to read the data.
	///
	///  - returns: An initialized Integer read from the binary data.
	init(binary data: NSData, endian: Endianness)
	{
		assert(data.length == 4)
		var bytes = [UInt8]()
		bytes.reserveCapacity(data.length)
		var dataBytes = data.bytes
		for _ in 0..<data.length
		{
			bytes.append(UnsafePointer<UInt8>(dataBytes).memory)
			dataBytes = dataBytes.successor()
		}
		self = 0
		if endian == .LittleEndian
		{
			for (i, byte) in bytes.reverse().enumerate()
			{
				self += Int(pow(2.0, 8.0 * Double(i))) * Int(byte)
			}
		}
		else
		{
			for (i, byte) in bytes.enumerate()
			{
				self += Int(pow(2.0, 8.0 * Double(i))) * Int(byte)
			}
		}
	}
}

extension Double
{
	///  Creates an Double from binary data using the endian to parse the binary data.
	///
	///  - Warning: This function will fail if the `length` of `data != 8`. Therefore data must be of length 8.
	///  - parameter data:   The binary data to use to form the double.
	///  - parameter endian: The endianness with which to read the data.
	///
	///  - returns: An initialized Double read from the binary data.
	init(binary data: NSData, endian: Endianness)
	{
		assert(data.length == 8)
		self = 0
		memcpy(&self, data.bytes, data.length)
	}
}

extension NSDate
{
	///  A convenience initializer for NSDate that creates an NSDate using an epochBinary data of length 8. The underlying double in the binary data must be a date of the form of time interval in the Mac + iOS epoch format, i.e. the reference date is 1/1/2001. This method only supports `BigEndian` endianness.
	///
	///  - Warning: This function will fail if the `length` of `data != 8`. Therefore data must be of length 8.
	///  - parameter data: The epoch binary data to use to form the NSDate
	///
	///  - returns: An initialized NSDate created using the underlying Double value.
	convenience init(epochBinary data: NSData)
	{
		let timeInterval = Double(binary: data, endian: .BigEndian)
		self.init(timeIntervalSinceReferenceDate: timeInterval)
	}
}

extension Array where Element : Equatable
{
	mutating func removeElement(element: Element)
	{
		for (i, elem) in enumerate()
		{
			if elem == element
			{
				self.removeAtIndex(i)
				return
			}
		}
	}
}
