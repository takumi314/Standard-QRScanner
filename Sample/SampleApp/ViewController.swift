//
//  ViewController.swift
//  SampleApp
//
//  Created by NishiokaKohei on 25/03/2020.
//  Copyright © 2020 Takumi. All rights reserved.
//

import UIKit
import StandardQRScanner

class ViewController: UIViewController {

    @IBOutlet private weak var qrScannerView: QRScannerView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        qrScannerView.configure(self, .default)
        qrScannerView.startRunning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        qrScannerView.stopRunning()
    }

}

extension ViewController: QRScanerViewDelegate {

    func qrScannerView(_ qrScannerView: QRScannerView, didSuccess code: String) {
        print(code)
    }

    func qrScannerView(_ qrScannerView: QRScannerView, didFailure error: ScannerError) {
        print(error)
    }

}
