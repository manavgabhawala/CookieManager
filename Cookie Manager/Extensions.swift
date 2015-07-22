//
//  Extensions.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 22/07/15.
//  Copyright © 2015 Manav Gabhawala. All rights reserved.
//

import Foundation


extension String
{
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
	
	init(readData data: NSData, fromLocationTillNullChar location: Int)
	{
		self = ""
		var range = NSRange(location: location, length: 1)
		while let str = String(data: data.subdataWithRange(range)) where str != "\0"
		{
			self += str
			++range.location
		}
	}
}

enum Endianness
{
	case BigEndian
	case LittleEndian
}

extension Int
{
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
	init(binary data: NSData, endian: Endianness)
	{
		assert(data.length == 8)
		self = 0
		memcpy(&self, data.bytes, data.length)
	}
}

extension NSDate
{
	convenience init(epochBinary data: NSData)
	{
		let timeInterval = Double(binary: data, endian: .BigEndian)
		self.init(timeIntervalSinceReferenceDate: timeInterval)
	}
}