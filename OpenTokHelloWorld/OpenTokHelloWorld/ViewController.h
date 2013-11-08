//
//  ViewController.h
//  SampleApp
//
//  Created by Charley Robinson on 12/13/11.
//  Copyright (c) 2011 Tokbox, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Opentok/Opentok.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "CorePlot-CocoaTouch.h"

@interface ViewController : UIViewController <OTSessionDelegate, OTSubscriberDelegate, OTPublisherDelegate, MFMailComposeViewControllerDelegate, CPTPlotDataSource>
@property (weak, nonatomic) IBOutlet UIButton *exceptionRaise;
@property (weak, nonatomic) IBOutlet UIButton *crashApp;

@property (weak, nonatomic) IBOutlet UIButton *statsWebRtc;
@property (weak, nonatomic) IBOutlet UIButton *emailConsoleLogs;
@property (weak, nonatomic) IBOutlet UITextView *statsTextView;


@property (weak, nonatomic) IBOutlet UIView *corePlotView;

@property (nonatomic, strong) CPTGraphHostingView *bytesSentHostView;
@property (nonatomic, strong) CPTTheme *selectedTheme;

- (void)doConnect;
- (void)doPublish;
- (void)showAlert:(NSString*)string;
@end
