//
//  ViewController.swift
//  Anki Beautify
//
//  Created by gpalya on 8/3/19.
//  Copyright © 2019 gpalya. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    //MARK: Properties
    
    @IBOutlet weak var mainButton: UIButton!
    
    //MARK: Actions
    
    @IBAction func mainButtonAction(_ sender: Any) {
        PasteboardFormat.filterEnglishLines()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    // girish
    // make the font of top status bar white
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

