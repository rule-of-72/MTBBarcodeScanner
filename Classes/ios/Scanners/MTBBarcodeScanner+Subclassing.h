//
//  MTBBarcodeScanner+Subclassing.h
//
//  Created by Sebastian Hagedorn on 23/02/15.
//
//

/**
 *  Subclasses may **overwrite** these hooks to change
 *  the default behaviour and configuration.
 */
@interface MTBBarcodeScanner (SubclassingHooks)
- (NSString *)sessionPreset;
@end

/**
 *  Subclasses may **use** this interface to gain access
 *  to methods not defined in the public interface. These
 *  methods are not meant to be overwritten.
 */
@interface MTBBarcodeScanner (Protected)
- (AVCaptureMetadataOutput *)captureOutput;
- (AVCaptureVideoPreviewLayer *)capturePreviewLayer;
@end
