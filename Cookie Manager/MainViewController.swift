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

    override func viewDidLoad()
	{
        super.viewDidLoad()
        // Do view setup here.
		let store = CookieStore()
		print(store!.cookies)
    }
    
}
