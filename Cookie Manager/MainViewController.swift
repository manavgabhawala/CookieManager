//
//  MainViewController.swift
//  Cookie Manager
//
//  Created by Manav Gabhawala on 22/07/15.
//  Copyright © 2015 Manav Gabhawala. All rights reserved.
//

import Cocoa

class MainViewController: NSViewController
{
	@IBOutlet var tableView: NSTableView!
	@IBOutlet var sourceList: NSTableView!
	
	@IBOutlet var splitView: NSView!
	
	var store : SafariCookieStore!
	var selectedCookies = [HTTPCookie]()
	
	
    override func viewDidLoad()
	{
        super.viewDidLoad()
        // Do view setup here.
		tableView.setDataSource(self)
		tableView.setDelegate(self)
		sourceList.setDataSource(self)
		sourceList.setDelegate(self)
		// TODO: Check for preferences and null of that manager here.
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
			self.store = SafariCookieStore()
			self.store?.delegate = self
			self.didUpdateCookies()
		})
    }
	override func viewWillTransitionToSize(newSize: NSSize)
	{
		splitView.frame.size = newSize
	}
}
// MARK: - Safari Cookie reader
extension MainViewController : SafariCookieStoreDelegate
{
	func didUpdateCookies()
	{
		dispatch_async(dispatch_get_main_queue(), {
			self.sourceList.reloadData()
			self.tableView.reloadData()
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
			return store?.cookieDomains.count ?? 0
		}
		return selectedCookies.count
	}
	func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView?
	{
		guard tableView !== sourceList
		else
		{
			let cell = tableView.makeViewWithIdentifier("cell", owner: self) as? NSTableCellView
			cell?.textField?.stringValue = store.cookieDomains[row].domain
			return cell
		}
		guard let id = tableColumn?.identifier
		else
		{
			return nil
		}
		let view = tableView.makeViewWithIdentifier("\(id)_cell", owner: self) as? NSTableCellView
		
		switch id
		{
		case "domain":
			view?.textField?.stringValue = selectedCookies[row].domain
			break
		case "name":
			view?.textField?.stringValue = selectedCookies[row].name
			break
		case "value":
			view?.textField?.stringValue = selectedCookies[row].value
			break
		case "path":
			view?.textField?.stringValue = selectedCookies[row].path
			break
		case "expires":
			view?.textField?.stringValue = selectedCookies[row].expiryDate?.descriptionWithLocale(NSLocale.currentLocale()) ?? "Session"
			break
		case "version":
			view?.textField?.stringValue = "\(selectedCookies[row].version)"
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
			guard index >= 0 && index < store?.cookieDomains.count
			else
			{
				continue
			}
			store?.cookieDomains[index].cookies.map { selectedCookies.append($0) }
		}
		tableView.reloadData()
	}
}
