//
//  PreviewController.swift
//  BanubaCoreSandbox
//
//  Created by Victor Privalov on 7/20/18.
//  Copyright © 2018 Banuba. All rights reserved.
//

import UIKit

class PreviewController: UIViewController {
    
    var image: UIImage?
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = self.image
        // Do any additional setup after loading the view.
    }
    
    @IBAction func backAction(_ sender: Any) {
        self.dismiss(animated: false, completion: nil)
    }
}
