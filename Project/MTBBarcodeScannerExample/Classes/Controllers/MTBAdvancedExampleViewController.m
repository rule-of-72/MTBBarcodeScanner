//
//  MTBAdvancedExampleViewController.m
//  MTBBarcodeScannerExample
//
//  Created by Mike Buss on 2/10/14.
//
//

#import "MTBAdvancedExampleViewController.h"
#import "MTBBarcodeScanner.h"
#import "Firebase.h"

#define kTitle @"title"
#define kDescription @"description"
#define kColor @"color"
#define kDate @"date"
#define kExpiry @"expiry"

@interface MTBAdvancedExampleViewController (){
    NSDate *lastSentTime;
    NSMutableDictionary *products;
}

@property (nonatomic, weak) IBOutlet UIView *previewView;
@property (nonatomic, weak) IBOutlet UIButton *toggleScanningButton;
@property (nonatomic, weak) IBOutlet UILabel *instructions;
@property (nonatomic, weak) IBOutlet UIView *viewOfInterest;

@property (nonatomic, strong) MTBBarcodeScanner *scanner;
@property (nonatomic, strong) NSMutableDictionary *overlayViews;
@property (nonatomic, assign) BOOL didShowAlert;

@property (strong, nonatomic) FIRDatabaseReference *ref;
@end

@implementation MTBAdvancedExampleViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    lastSentTime = [[NSDate alloc] init];
    
    
    products = [[NSMutableDictionary alloc] init];
    products[@"Sku101-1"] = @{
                              kTitle:@"Samsung Note 7",
                              kDescription:@"512GB, 8GB Ram",
                              kDate:@"21 Oct 13",
                              kExpiry:@"21 Oct 16",
                              kColor:[UIColor redColor]
                              };
    products[@"Sku101-2"] = @{
                              kTitle:@"Samsung Note 7",
                              kDescription:@"512GB, 8GB Ram",
                              kDate:@"21 Dec 13",
                              kExpiry:@"21 Dec 16",
                              kColor:[UIColor yellowColor]
                              };
    products[@"Sku101-3"] = @{
                              kTitle:@"Samsung Note 7",
                              kDescription:@"512GB, 8GB Ram",
                              kDate:@"21 Dec 13",
                              kExpiry:@"21 Dec 16",
                              kColor:[UIColor yellowColor]
                              };
    products[@"Sku102-1"] = @{
                              kTitle:@"Apple iPhone 7",
                              kDescription:@"128GB, 8GB Ram",
                              kDate:@"25 Jan 14",
                              kExpiry:@"25 Jan 17",
                              kColor:[UIColor yellowColor]
                              };
    products[@"Sku102-2"] = @{
                              kTitle:@"Apple iPhone 7",
                              kDescription:@"128GB, 8GB Ram",
                              kDate:@"25 Jan 16",
                              kExpiry:@"25 Jan 19",
                              kColor:[UIColor greenColor]
                              };
    products[@"Sku102-3"] = @{
                              kTitle:@"Apple iPhone 7",
                              kDescription:@"128GB, 8GB Ram",
                              kDate:@"25 Jan 16",
                              kExpiry:@"25 Jan 19",
                              kColor:[UIColor greenColor]
                              };
    products[@"Sku103-1"] = @{
                              kTitle:@"Google Pixel",
                              kDescription:@"512GB, 16GB Ram",
                              kDate:@"22 Oct 16",
                              kExpiry:@"22 Oct 19",
                              kColor:[UIColor greenColor]
                              };
    products[@"Sku103-2"] = @{
                              kTitle:@"Google Pixel",
                              kDescription:@"512GB, 16GB Ram",
                              kDate:@"9 Nov 15",
                              kExpiry:@"11 Sept 18",
                              kColor:[UIColor greenColor]
                              };
    products[@"Sku103-3"] = @{
                              kTitle:@"Google Pixel",
                              kDescription:@"512GB, 16GB Ram",
                              kDate:@"9 Nov 15",
                              kExpiry:@"11 Sept 18",
                              kColor:[UIColor greenColor]
                              };
    
    
    self.ref = [[FIRDatabase database] reference];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.didShowAlert && !self.instructions) {
        [[[UIAlertView alloc] initWithTitle:@"Example"
                                    message:@"To view this example, point the camera at the sample barcodes on the official MTBBarcodeScanner README."
                                   delegate:nil
                          cancelButtonTitle:@"Ok"
                          otherButtonTitles:nil] show];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.scanner stopScanning];
    [super viewWillDisappear:animated];
}

#pragma mark - Scanner

- (MTBBarcodeScanner *)scanner {
    if (!_scanner) {
        _scanner = [[MTBBarcodeScanner alloc] initWithPreviewView:_previewView];
    }
    return _scanner;
}

#pragma mark - Overlay Views

- (NSMutableDictionary *)overlayViews {
    if (!_overlayViews) {
        _overlayViews = [[NSMutableDictionary alloc] init];
    }
    return _overlayViews;
}

#pragma mark - Scanning

- (void)startScanning {
    
    self.scanner.didStartScanningBlock = ^{
        NSLog(@"The scanner started scanning!");
    };
    
    self.scanner.didTapToFocusBlock = ^(CGPoint point){
        NSLog(@"The user tapped the screen to focus. \
              Here we could present a view at %@", NSStringFromCGPoint(point));
    };
    
    NSError *error;
    [self.scanner startScanningWithResultBlock:^(NSArray *codes) {
        [self drawOverlaysOnCodes:codes];
    } error:&error];
    
    if (error) {
        NSLog(@"An error occurred: %@", error.localizedDescription);
    }
    
    // Optionally set a rectangle of interest to scan codes. Only codes within this rect will be scanned.
    //    self.scanner.scanRect = self.viewOfInterest.frame;
    self.scanner.scanRect = self.previewView.frame;
    [self.viewOfInterest setHidden:true];
    
    
    [self.toggleScanningButton setTitle:@"Stop Scanning" forState:UIControlStateNormal];
    self.toggleScanningButton.backgroundColor = [UIColor redColor];
}

- (void)drawOverlaysOnCodes:(NSArray *)codes {
    // Get all of the captured code strings
    NSMutableArray *codeStrings = [[NSMutableArray alloc] init];
    for (AVMetadataMachineReadableCodeObject *code in codes) {
        if (code.stringValue) {
            [codeStrings addObject:code.stringValue];
        }
    }
    
    // Remove any code overlays no longer on the screen
    for (NSString *code in self.overlayViews.allKeys) {
        if ([codeStrings indexOfObject:code] == NSNotFound) {
            // A code that was on the screen is no longer
            // in the list of captured codes, remove its overlay
            [self.overlayViews[code] removeFromSuperview];
            [self.overlayViews removeObjectForKey:code];
        }
    }
    
    
    for (AVMetadataMachineReadableCodeObject *code in codes) {
        UIView *view = nil;
        NSString *codeString = code.stringValue;
        
        if (codeString) {
            if (self.overlayViews[codeString]) {
                // The overlay is already on the screen
                view = self.overlayViews[codeString];
                
                // Move it to the new location
                view.frame = code.bounds;
                
            } else {
                
                // Create an overlay
                UIView *overlayView = [self overlayForCodeString:codeString
                                                          bounds:code.bounds
                                                         corners:code.corners];
                self.overlayViews[codeString] = overlayView;
                
                // Add the overlay to the preview view
                [self.previewView addSubview:overlayView];
                
            }
        }
    }
    
    
    
        NSDate *now = [[NSDate alloc] init];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        NSString *timeString = [df stringFromDate:now];
        
        
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        for (NSString *str in codeStrings){
            NSString *model = [str substringToIndex:6];
            if ([model isEqualToString:@"Sku123"]||
                [model isEqualToString:@"Sku101"]||
                [model isEqualToString:@"Sku102"]||
                [model isEqualToString:@"Sku103"]){
                
                if ([[dict allKeys] containsObject:model]) {
                    dict[model] = [[NSNumber alloc] initWithInt: [dict[model] intValue] + 1];
                }else{
                    dict[model] = [[NSNumber alloc] initWithInt: 1];
                }
            }
        }
    
    
    if ([lastSentTime timeIntervalSinceNow] < -2 || [[dict allKeys] count] < 1){
        if ([[dict allKeys] count] < 1){
            dict[@"Sku101"] = [[NSNumber alloc] initWithInt: 0];
        }
        lastSentTime = now;
        [[[_ref child:@"cctv"] child:timeString] setValue:dict];
        NSLog(@"%@",dict);
    }
}

- (BOOL)isValidCodeString:(NSString *)codeString {
    BOOL stringIsValid = ([codeString rangeOfString:@"Valid"].location != NSNotFound);
    return stringIsValid;
}

- (UIView *)overlayForCodeString:(NSString *)codeString bounds:(CGRect)bounds corners:(NSArray *)corners {
    //    UIColor *viewColor = valid ? [UIColor greenColor] : [UIColor redColor];
    UIColor *viewColor = [UIColor whiteColor];
    UIView *view = [[UIView alloc] initWithFrame:bounds];
    UILabel *label = [[UILabel alloc] initWithFrame:view.bounds];
    
    
    // Configure the view
    view.layer.borderWidth = 2.0;
    view.backgroundColor = [viewColor colorWithAlphaComponent:0.5];
    view.layer.borderColor = [UIColor blackColor].CGColor;
    
    // Configure the label
    label.font = [UIFont boldSystemFontOfSize:12];
    label.textColor = [UIColor blackColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    if (![[products allKeys] containsObject:codeString]){
        label.text = [@"No data found: " stringByAppendingString: codeString];
    }else{
        NSDictionary *product = products[codeString];
        UIColor *color = product[kColor];
        
        view.backgroundColor = [color colorWithAlphaComponent:0.5];
        
        label.text = codeString;
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(bounds.size.width, 0.0)];
        [path addLineToPoint:CGPointMake(bounds.size.width+50.0, -50.0)];
        CAShapeLayer *shapeLayer = [CAShapeLayer layer];
        shapeLayer.path = [path CGPath];
        shapeLayer.strokeColor = [[UIColor blackColor] CGColor];
        shapeLayer.lineWidth = 2.0;
        shapeLayer.fillColor = [[UIColor clearColor] CGColor];
        [view.layer addSublayer:shapeLayer];
        
        CGFloat width = 200.0;
        UIView *card = [[UIView alloc] initWithFrame: CGRectMake(bounds.size.width+50.0, -50.0, width, 89.0)];
        card.layer.borderWidth = 2.0;
        card.backgroundColor = [viewColor colorWithAlphaComponent:0.8];
        card.layer.borderColor = [UIColor blackColor].CGColor;
        card.layer.zPosition = MAXFLOAT;
        
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(5,5, width-10.0, 20)];
        nameLabel.textColor = [UIColor blackColor];
        nameLabel.textAlignment = NSTextAlignmentLeft;
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.text = product[kTitle];
        [card addSubview: nameLabel];
        UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(5,27, width-10.0, 15)];
        descLabel.textColor = [UIColor blackColor];
        descLabel.textAlignment = NSTextAlignmentLeft;
        descLabel.font = [UIFont italicSystemFontOfSize:12];
        descLabel.text = product[kDescription];
        [card addSubview: descLabel];
        UILabel *dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(5,44, width-10.0, 18)];
        dateLabel.textColor = [UIColor blackColor];
        dateLabel.textAlignment = NSTextAlignmentLeft;
        dateLabel.font = [UIFont systemFontOfSize:14];
        dateLabel.text = [@"MFG: " stringByAppendingString: product[kDate]];
        [card addSubview: dateLabel];
        UILabel *expLabel = [[UILabel alloc] initWithFrame:CGRectMake(5,64, width-10.0, 18)];
        expLabel.textColor = [UIColor blackColor];
        expLabel.textAlignment = NSTextAlignmentLeft;
        expLabel.font = [UIFont systemFontOfSize:14];
        expLabel.text = [@"Expiry: " stringByAppendingString: product[kExpiry]];
        [card addSubview: expLabel];
        [view addSubview: card];
        
        
    }
    

    
//    for(NSDictionary* c in corners){
//        NSLog(@"%@",c);
//    }
    
    
    
    // Add constraints to label to improve text size?
    
    // Add the label to the view
    [view addSubview:label];
    
    return view;
}

- (void)stopScanning {
    [self.scanner stopScanning];
    
    [self.toggleScanningButton setTitle:@"Start Scanning" forState:UIControlStateNormal];
    self.toggleScanningButton.backgroundColor = self.view.tintColor;
    
    for (NSString *code in self.overlayViews.allKeys) {
        [self.overlayViews[code] removeFromSuperview];
    }
    
    NSDate *now = [[NSDate alloc] init];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    NSString *timeString = [df stringFromDate:now];
    [[[_ref child:@"cctv"] child:timeString] setValue:@{@"Sku101":[[NSNumber alloc] initWithInt:0]}];
}

#pragma mark - Actions

- (IBAction)toggleScanningTapped:(id)sender {
    if ([self.scanner isScanning]) {
        [self stopScanning];
    } else {
        [MTBBarcodeScanner requestCameraPermissionWithSuccess:^(BOOL success) {
            if (success) {
                [self startScanning];
            } else {
                [self displayPermissionMissingAlert];
            }
        }];
    }
}

- (IBAction)switchCameraTapped:(id)sender {
    [self.scanner flipCamera];
}

- (void)backTapped {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Notifications

- (void)deviceOrientationDidChange:(NSNotification *)notification {
    self.scanner.scanRect = self.viewOfInterest.frame;
}

#pragma mark - Helper Methods

- (void)displayPermissionMissingAlert {
    NSString *message = nil;
    if ([MTBBarcodeScanner scanningIsProhibited]) {
        message = @"This app does not have permission to use the camera.";
    } else if (![MTBBarcodeScanner cameraIsPresent]) {
        message = @"This device does not have a camera.";
    } else {
        message = @"An unknown error occurred.";
    }
    
    [[[UIAlertView alloc] initWithTitle:@"Scanning Unavailable"
                                message:message
                               delegate:nil
                      cancelButtonTitle:@"Ok"
                      otherButtonTitles:nil] show];
}

@end
