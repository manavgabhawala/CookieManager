//
//  MainViewController.swift
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

import Cocoa

class MainViewController: NSViewController
{
	@IBOutlet var tableView: NSTableView!
	@IBOutlet var sourceList: NSTableView!
	
	@IBOutlet var splitView: NSView!
	
	var store : CookieStore!
	
	var selectedCookies = [HTTPCookie]()
	
	var searchDomains : [HTTPCookieDomain]?
	
	@IBOutlet var toolbar: NSToolbar!
	
	@IBOutlet var cookieDomainsStatus: NSTextField!
	@IBOutlet var cookiesStatus: NSTextField!
	
	@IBOutlet var cookiesProgress: NSProgressIndicator!
	
    override func viewDidLoad()
	{
        super.viewDidLoad()
        // Do view setup here.
		store = CookieStore(delegate: self)
		
		tableView.setDataSource(self)
		tableView.setDelegate(self)
		sourceList.setDataSource(self)
		sourceList.setDelegate(self)
		
		cookiesProgress.doubleValue = 0.0
		
    }
	override func viewDidAppear()
	{
		super.viewDidAppear()
		view.window?.toolbar = toolbar
	}
}
// MARK: - Safari Cookie reader
extension MainViewController : CookieStoreDelegate
{
	func updateLabels()
	{
		dispatch_async(dispatch_get_main_queue(), {
			let cookieDomainCount = self.sourceList.selectedRowIndexes.count
			let domainWord = cookieDomainCount == 1 ? "domain" : "domains"
			self.cookieDomainsStatus.stringValue = "\(cookieDomainCount) cookie \(domainWord) out of \(self.store.domainCount)"
			let cookieCount = self.selectedCookies.count
			let cookieWord = cookieCount == 1 ? "cookie" : "cookies"
			self.cookiesStatus.stringValue = "Displaying \(cookieCount) \(cookieWord) out of \(self.store.cookieCount)"
		})
	}
	
	func startedParsingCookies()
	{
		dispatch_async(dispatch_get_main_queue(), {
			self.cookiesProgress.alphaValue = 1.0
			self.cookiesProgress.doubleValue = 0.0
		})
	}
	func finishedParsingCookies()
	{
		dispatch_async(dispatch_get_main_queue(), {
			self.updateLabels()
			self.cookiesProgress.alphaValue = 0.0
			self.sourceList.reloadData()
		})
	}
	
	func stoppedTrackingCookiesForBrowser(browser: Browser)
	{
		// TODO: Show error.
	}
	
	func madeProgress(progress: Double)
	{
		dispatch_async(dispatch_get_main_queue(), {
			self.cookiesProgress.doubleValue = progress * self.cookiesProgress.maxValue
		})
	}
	func updatedCookies()
	{
		dispatch_async(dispatch_get_main_queue(), {
			self.updateLabels()
			self.sourceList.reloadData()
		})

	}
	
}
// MARK: - Table View
extension MainViewController : NSTableViewDataSource, NSTableViewDelegate
{
	func numberOfRowsInTableView(tableView: NSTableView) -> Int
	{
		guard tableView !== sourceList
		else
		{
			return store.domainCount
		}
		return selectedCookies.count
	}
	func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView?
	{
		guard tableView !== sourceList
		else
		{
			guard row < (searchDomains?.count ?? store.domainCount)
			else { return nil }
			let cell = tableView.makeViewWithIdentifier("cell", owner: self) as? NSTableCellView
			cell?.textField?.stringValue = searchDomains?[row].domain ?? store.domainAtIndex(row)?.domain ?? ""
			return cell
		}
		guard let id = tableColumn?.identifier
		else
		{
			return nil
		}
		
		let view = tableView.makeViewWithIdentifier("\(id)_cell", owner: self) as? NSTableCellView
		
		let cookie = selectedCookies[row]
		
		switch id
		{
		case "browser":
			view?.imageView?.image = cookie.browser.image
			break
		case "domain":
			view?.textField?.stringValue = cookie.domain
			break
		case "name":
			view?.textField?.stringValue = cookie.name
			break
		case "value":
			view?.textField?.stringValue = cookie.value
			break
		case "path":
			view?.textField?.stringValue = cookie.path
			break
		case "expires":
			view?.textField?.stringValue = cookie.expiryDate?.descriptionWithLocale(NSLocale.currentLocale()) ?? "Session"
			break
		case "version":
			view?.textField?.stringValue = cookie.versionDescription
			break
		case "secure":
			view?.textField?.stringValue = cookie.secure ? "✓" : "✗"
			break
		case "http":
			view?.textField?.stringValue = cookie.HTTPOnly ? "✓" : "✗"
			break
		case "comment":
			view?.textField?.stringValue = cookie.comment ?? ""
			break
		default:
			return nil
		}
		return view
	}
	func tableViewSelectionDidChange(notification: NSNotification)
	{
		guard notification.object === sourceList
		else
		{
			return
		}
		selectedCookies.removeAll(keepCapacity: true)
		for index in sourceList.selectedRowIndexes
		{
			guard index >= 0 && index < (searchDomains?.count ?? store.domainCount)
			else
			{
				continue
			}
			let domain = (searchDomains?[index] ?? store.domainAtIndex(index))
			domain?.cookies.map { selectedCookies.append($0) }
		}
		tableView.reloadData()
		updateLabels()
	}
	func tableView(tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor])
	{
		let newDescriptors = tableView.sortDescriptors
		for descriptor in newDescriptors.reverse()
		{
			let order = descriptor.ascending ? NSComparisonResult.OrderedAscending : NSComparisonResult.OrderedDescending
			guard let key = descriptor.key
			else
			{
				continue
			}
			switch key
			{
			case "browser":
				selectedCookies.sortInPlace { $0.browser.compare($1.browser) == order }
				break
			case "domain":
				selectedCookies.sortInPlace { $0.domain.localizedCaseInsensitiveCompare($1.domain) == order }
				break
			case "name":
				selectedCookies.sortInPlace { $0.name.localizedCaseInsensitiveCompare($1.name) == order }
				break
			case "value":
				selectedCookies.sortInPlace { $0.value.localizedCaseInsensitiveCompare($1.value) == order }
				break
			case "path":
				selectedCookies.sortInPlace { $0.path.localizedCaseInsensitiveCompare($1.path) == order }
				break
			case "expires":
				// TODO: Date sorting.
				selectedCookies.sortInPlace
				{
					guard $0.expiryDate != nil
					else
					{
						return order == .OrderedDescending
					}
					guard $1.expiryDate != nil
					else
					{
						return order == .OrderedAscending
					}
					return $0.expiryDate!.compare($1.expiryDate!) == order
				}
				break
			case "version":
				selectedCookies.sortInPlace { NSNumber(integer: $0.version).compare(NSNumber(integer: $1.version)) == order }
				break
			case "secure":
				selectedCookies.sortInPlace { NSNumber(bool: $0.secure).compare(NSNumber(bool: $1.secure)) == order }
				break
			case "http":
				selectedCookies.sortInPlace { NSNumber(bool: $0.HTTPOnly).compare(NSNumber(bool: $1.HTTPOnly)) == order }
				break
			case "comment":
				selectedCookies.sortInPlace { ($0.comment ?? "").localizedCaseInsensitiveCompare(($1.comment ?? "")) == order }
				break
			default:
				continue
			}
		}
		tableView.reloadData()
	}
}
extension MainViewController : NSToolbarDelegate
{
	@IBAction func addCookie(sender: NSToolbarItem)
	{
		
	}
	@IBAction func search(sender: NSSearchField)
	{
		defer
		{
			selectedCookies = []
			sourceList.reloadData()
			tableView.reloadData()
		}
		let str = sender.stringValue
		guard !str.isEmpty
		else
		{
			searchDomains = nil
			return
		}
		searchDomains = store.searchUsingString(str)
	}
}

