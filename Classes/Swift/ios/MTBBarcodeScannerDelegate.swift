//
//  MTBBarcodeScannerDelegate.swift
//
//  Created by Sam Mortazavi on 21/7/20.
//

import UIKit


public protocol MTBBarcodeScannerDelegate: class {
    
    func barcodeScannerDidStartScanning()
    
    func barcodeScannerDidUnfreezScanner()
    
    func barcodeScanner(didTapToFocustAt point: CGPoint)
    
    func barcodeScanner(didRecognize barcodes: [AVMetadataMachineReadableCodeObject])
    
    func barcodeScanner(failedToCaptureStillImageWith error: Error)
    
    func barcodeScanner(didCapture stillImage: UIImage)
    
    func barcodeScanner(didTapToFocusOn point: CGPoint)
}

extension MTBBarcodeScannerDelegate {
    
    func barcodeScannerDidStartScanning() {}
    
    func barcodeScannerDidUnfreezScanner() {}
    
    func barcodeScanner(didTapToFocustAt point: CGPoint) {}
    
    func barcodeScanner(failedToCaptureStillImageWith error: Error) {}
    
    func barcodeScanner(didCapture stillImage: UIImage) {}
    
    func barcodeScanner(didTapToFocusOn point: CGPoint) {}
}



