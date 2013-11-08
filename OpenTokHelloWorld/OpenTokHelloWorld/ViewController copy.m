//
//  ViewController.m
//  SampleApp
//
//  Created by Charley Robinson on 12/13/11.
//  Copyright (c) 2011 Tokbox, Inc. All rights reserved.
//

#import "ViewController.h"
void set_ot_log_level(int);



#pragma mark Analytics
NSMutableArray * bytesSentAssignments;
void analyticsParse (NSString * fromString);
NSString* analyticsReport(void);

BOOL isAnalyticsAttachedToMail = YES;

NSNotificationCenter * notificationCenter;
static NSString * kNotificationName = @"tickItNow";

static int statsTypeCount = 1;
static NSString * kBytesSent = @"bytesSent";
static NSString * kPacketsSent = @"packetsSent";
static NSString * kAudioInputLevel = @"audioInputLevel";



NSString* analyticsReport(void)
{
    NSMutableString * report = [[NSMutableString alloc] init];
    //to make it thread safe
    NSMutableArray * assigns = [ bytesSentAssignments mutableCopy];
    
    
    for (NSString* assignment in assigns) {
        if ([assignment rangeOfString:kBytesSent].location != NSNotFound) {
            [report appendString:[assignment stringByAppendingString:@"\n"]];
           
        }
    }
   
    [report appendString:@"\n"];
    for (NSString* assignment in assigns) {
        if ([assignment rangeOfString:kPacketsSent].location != NSNotFound) {
         [report appendString:[assignment stringByAppendingString:@"\n"]];
        }
    }
    [report appendString:@"\n"];
    
    for (NSString* assignment in assigns) {
        if ([assignment rangeOfString:kAudioInputLevel].location != NSNotFound) {
            [report appendString:[assignment stringByAppendingString:@"\n"]];
        }
    }
    
    return report;
}

void analyticsParse (NSString * fromString)
{
    NSError * err = nil;
    __block NSString * assignmentLHS = @"";
    __block NSString * assignmentRHS = @"";
    
    // 1. match logTrackStats
    NSRegularExpression * regex = [[NSRegularExpression alloc] initWithPattern:@"logTrackStats" options:0 error:&err];
    [regex enumerateMatchesInString:fromString options:NSMatchingReportCompletion range:NSMakeRange(0, fromString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        
        if(result)
        {
            
            dispatch_async(dispatch_queue_create("com.tokbox.myqueue", 0), ^{
                
                // 2 match assignments
                NSError * errorAssignmets = nil;
                NSRegularExpression * regexMatchAssignments = [[NSRegularExpression alloc]
                                                               initWithPattern:@"(\\w+)=(\\d+)"
                                                               options:0
                                                               error:&errorAssignmets];
                [regexMatchAssignments enumerateMatchesInString:fromString options:NSMatchingReportCompletion range:NSMakeRange(0, fromString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                    
                    
                    if(result)
                    {
                        assignmentLHS = [NSString stringWithString:[fromString substringWithRange:[result rangeAtIndex:1]]];
                        assignmentRHS = [NSString stringWithString:[fromString substringWithRange:[result rangeAtIndex:2]]];
                        
                        
                    }
                }];
                
                
                //3 store
                
                if(assignmentLHS.length && assignmentRHS.length)
                {
                    
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"HH:mm:ss.SSS"];
                    NSString *date = [formatter stringFromDate: [NSDate date]];
                    
                    if(bytesSentAssignments == nil)
                    {
                        bytesSentAssignments = [[NSMutableArray alloc] init];
                    }
                    if([assignmentLHS isEqualToString:kBytesSent])
                    {
                        [bytesSentAssignments addObject:[NSString stringWithFormat:@"%@,%@,%@",assignmentLHS,date,assignmentRHS] ];
                        NSNotification * note = [[NSNotification alloc] initWithName:kNotificationName object:nil userInfo:nil];
                        [[NSNotificationCenter defaultCenter] postNotification:note];
                    }
                    
                    
                    
                }
                
                
            });
            
            
        }
    }];
    
    
}


#pragma mark Mail crashes

#import <execinfo.h>
#import <signal.h>
#define MAIL_CRASHES    1
#ifdef MAIL_CRASHES
void initSignalAndExceptionsHandler(void);
void onUncaughtException(NSException* exception);
void defaultSignalAndExceptionsHandler(void);
void SignalHandler(int signal);
void mailItAndExit (void);



NSMutableString * mail;

void mailItAndExit (void)
{
    //send only one mail
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        
        NSString * addr = @"mailto:jaideep@tokbox.com?";
        NSString * device = [[UIDevice currentDevice] name];
        device = (NSString *) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                        (CFStringRef) device,
                                                                                        NULL,
                                                                                        (CFStringRef) @"!*'();:@&=+$,/?%#[]",
                                                                                        kCFStringEncodingUTF8));
        
        NSString * subject = [@"subject=Crash%20report%20for%20" stringByAppendingString:device];
        if(isAnalyticsAttachedToMail)
        {
            [mail appendString:analyticsReport()];
        }
        NSString * body = [NSString stringWithFormat:@"%s",[mail UTF8String]];
        body = (NSString *) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                      (CFStringRef) body,
                                                                                      NULL,
                                                                                      (CFStringRef) @"!*'();:@&=+$,/?%#[]",
                                                                                      kCFStringEncodingUTF8));
        
        
        // This call exits the app, if you don't want this, then you will have to implement your own mail picker UI
        // This call implicitly pops up the mail client and asks the user to either send or cancel the mail
        NSString * url = [NSString stringWithFormat:@"%@&%@&body=%@",addr,subject,body];
        [[UIApplication sharedApplication] openURL: [NSURL URLWithString: url]];
        
    });
}

void SignalHandler(int signal)
{
    //since we can have multiple signals we don't want to have 30+ mails/printf going out, only ONE
    // Hence use dispatch_once
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        void *callstack[128];
        int frameCount = backtrace(callstack, 128);
        char **frameStrings = backtrace_symbols(callstack, frameCount);
        
        if ( frameStrings != NULL ) {
            // Start with frame 1 because frame 0 is PrintBacktrace()
            for ( int i = 1; i < frameCount; i++ ) {
                NSLog(@"%s", frameStrings[i]);
            }
            free(frameStrings);
        }
        defaultSignalAndExceptionsHandler();
        mailItAndExit();
        
        //Apple will not like this exit call. If you want to put this code in production, then comment it out.
        //Your app will have a dirty black screen for 10-15 secs. If exit is there you are out of it - fast.
        exit(0);
        
    });
}
void onUncaughtException(NSException* exception)
{
    // just catch one exception
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSLog(@"%@", [exception callStackSymbols]);
        NSLog(@"uncaught exception: %@",exception.description);
        defaultSignalAndExceptionsHandler();
        mailItAndExit();
        exit(0);
    });
    
    
}
void NSLog(NSString *format, ...)
{
    
    va_list args;
    va_start(args, format);
    
    //since initSignalAndExceptionsHandler can be called from anywhere in code, we will miss the NSLog before it is called
    // so do the init here. Can be optimized if desired
    if(mail == nil)
    {
        mail = [[NSMutableString alloc] init];
    }
    NSString * consoleString = [[NSString alloc] initWithFormat:format arguments:args];
    
    [mail appendString: consoleString];
    analyticsParse(consoleString);
    
    
    //don't use NSLog here - infinite recursion !!
    NSLogv(format, args); // xcode
    va_end(args);
}
void defaultSignalAndExceptionsHandler(void)
{
    
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
	signal(SIGILL, SIG_DFL);
	signal(SIGSEGV, SIG_DFL);
	signal(SIGFPE, SIG_DFL);
	signal(SIGBUS, SIG_DFL);
	signal(SIGPIPE, SIG_DFL);
    
}
void initSignalAndExceptionsHandler(void)
{
    // There is no reverting back to default for signal and no setting of exception handle to NULL,
    // since mailing the log, exits the app.
    
    
    NSSetUncaughtExceptionHandler(&onUncaughtException);
    signal(SIGABRT, SignalHandler);
	signal(SIGILL, SignalHandler);
	signal(SIGSEGV, SignalHandler);
	signal(SIGFPE, SignalHandler);
	signal(SIGBUS, SignalHandler);
	signal(SIGPIPE, SignalHandler);
    
}
#endif



@implementation ViewController {
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    
}

static double widgetHeight = 240 ;
static double widgetWidth = 320 ;

// *** Fill the following variables using your own Project info from the Dashboard  ***
// ***                   https://dashboard.tokbox.com/projects                      ***
static NSString* const kApiKey = @"100";    // Replace with your OpenTok API key
static NSString* const kSessionId = @"2_MX4xMDB-MTI3LjAuMC4xfldlZCBPY3QgMTYgMTM6MDg6MTcgUERUIDIwMTN-MC4xNTQzOTQ1N34"; // Replace with your generated session ID
static NSString* const kToken = @"T1==cGFydG5lcl9pZD0xMDAmc2RrX3ZlcnNpb249dGJwaHAtdjAuOTEuMjAxMS0wNy0wNSZzaWc9NmFmZTFiYmY5Y2U0YzBiOGU1YWQ1NjBhMDFlY2I5MGM2OTFjYTU4NDpzZXNzaW9uX2lkPTJfTVg0eE1EQi1NVEkzTGpBdU1DNHhmbGRsWkNCUFkzUWdNVFlnTVRNNk1EZzZNVGNnVUVSVUlESXdNVE4tTUM0eE5UUXpPVFExTjM0JmNyZWF0ZV90aW1lPTEzODE5NTM4NTImcm9sZT1wdWJsaXNoZXImbm9uY2U9MTM4MTk1Mzg1Mi43MjY3MTE0MzM5NzgzNiZleHBpcmVfdGltZT0xMzg0NTQ1ODUy";     // Replace with your generated token (use the Dashboard or an OpenTok server-side library)

static bool subscribeToSelf = NO; // Change to NO to subscribe to streams other than your own.

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    initSignalAndExceptionsHandler();
    self.statsTextView.text = @"";
    notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(statsTick:) name:kNotificationName object:nil];
    
    set_ot_log_level(5);
    [self initPlot];
    _session = [[OTSession alloc] initWithSessionId:kSessionId
                                           delegate:self];
    [self doConnect];
}
-(void) viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
-(void) statsTick : (NSNotification *) note
{
    //since we update via notification from any q. And these are UI
    dispatch_async(dispatch_get_main_queue(),^{
        [self stats:nil];
        
        [self.bytesSentHostView.hostedGraph reloadData];
    });
}
- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return NO;
    } else {
        return YES;
    }
}

- (void)updateSubscriber {
    for (NSString* streamId in _session.streams) {
        OTStream* stream = [_session.streams valueForKey:streamId];
        if (![stream.connection.connectionId isEqualToString: _session.connection.connectionId]) {
            _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
            break;
        }
    }
}

#pragma mark - OpenTok methods

- (void)doConnect
{
    [_session connectWithApiKey:kApiKey token:kToken];
}

- (void)doPublish
{
    _publisher = [[OTPublisher alloc] initWithDelegate:self];
    [_publisher setName:[[UIDevice currentDevice] name]];
    [_session publish:_publisher];
    [self.view addSubview:_publisher.view];
    [_publisher.view setFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
}

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage = [NSString stringWithFormat:@"Session disconnected: (%@)", session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
    [self showAlert:alertMessage];
}


- (void)session:(OTSession*)mySession didReceiveStream:(OTStream*)stream
{
    NSLog(@"session didReceiveStream (%@)", stream.streamId);
    
    // See the declaration of subscribeToSelf above.
    if ( (subscribeToSelf && [stream.connection.connectionId isEqualToString: _session.connection.connectionId])
        ||
        (!subscribeToSelf && ![stream.connection.connectionId isEqualToString: _session.connection.connectionId])
        ) {
        if (!_subscriber) {
            _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
        }
    }
}

- (void)session:(OTSession*)session didDropStream:(OTStream*)stream{
    NSLog(@"session didDropStream (%@)", stream.streamId);
    NSLog(@"_subscriber.stream.streamId (%@)", _subscriber.stream.streamId);
    if (!subscribeToSelf
        && _subscriber
        && [_subscriber.stream.streamId isEqualToString: stream.streamId])
    {
        _subscriber = nil;
        [self updateSubscriber];
    }
}

- (void)session:(OTSession *)session didCreateConnection:(OTConnection *)connection {
    NSLog(@"session didCreateConnection (%@)", connection.connectionId);
}

- (void) session:(OTSession *)session didDropConnection:(OTConnection *)connection {
    NSLog(@"session didDropConnection (%@)", connection.connectionId);
}

- (void)subscriberDidConnectToStream:(OTSubscriber*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)", subscriber.stream.connection.connectionId);
    [subscriber.view setFrame:CGRectMake(0, widgetHeight, widgetWidth, widgetHeight)];
    [self.view addSubview:subscriber.view];
}

- (void)publisher:(OTPublisher*)publisher didFailWithError:(OTError*) error {
    NSLog(@"publisher didFailWithError %@", error);
    [self showAlert:[NSString stringWithFormat:@"There was an error publishing."]];
}

- (void)subscriber:(OTSubscriber*)subscriber didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@", subscriber.stream.streamId, error);
    [self showAlert:[NSString stringWithFormat:@"There was an error subscribing to stream %@", subscriber.stream.streamId]];
}

- (void)session:(OTSession*)session didFailWithError:(OTError*)error {
    NSLog(@"sessionDidFail");
    [self showAlert:[NSString stringWithFormat:@"There was an error connecting to session %@", session.sessionId]];
}


- (void)showAlert:(NSString*)string {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message from video session"
                                                    message:string
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark Actions
- (IBAction)exception:(id)sender {
        NSException* myException = [NSException
                                    exceptionWithName:@"NetworkNotConnectedException"
                                    reason:@"Network is not up or running"
                                    userInfo:nil];
        @throw myException;
}

- (IBAction)crash:(id)sender {
    
    void (*nullFunction)() = NULL;
    
    nullFunction();
}

- (IBAction)stats:(id)sender {
  
    
        [self.statsTextView setText:analyticsReport()];
        [self.statsTextView scrollRangeToVisible:NSMakeRange([self.statsTextView.text length], 0)];
    
    

}
- (IBAction)email:(id)sender {
    if ([MFMailComposeViewController canSendMail]) {
        // Show the composer
        MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
        NSString * device = [[UIDevice currentDevice] name];
        controller.mailComposeDelegate = self;
    
        [controller setToRecipients:[NSArray arrayWithObject:@"jaideep@tokbox.com"]];
        [controller setSubject:[@"Crash report for " stringByAppendingString:device]];
        [controller setMessageBody:analyticsReport() isHTML:NO];
        if (controller) [self presentModalViewController:controller animated:YES];
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Mail" message:@"Device not configured to send mail" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
    }
    
  
}
#pragma mark MailComposer delegate
- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error;
{
    if (result == MFMailComposeResultSent) {
       
    }
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)graphUpdate:(id)sender {
    [self.bytesSentHostView.hostedGraph reloadData];
}

#pragma mark - CPTPlotDataSource methods
#pragma mark - CPTPlotDataSource methods

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot {
    return bytesSentAssignments.count;
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index {
    NSInteger valueCount = bytesSentAssignments.count;
   
    switch (fieldEnum) {
        case CPTScatterPlotFieldX:
            if (index < valueCount) {
                return [NSNumber numberWithUnsignedInteger:index];
            }
            break;
            
        case CPTScatterPlotFieldY:
            if ([plot.identifier isEqual:kBytesSent] == YES) {
                NSString * input = [bytesSentAssignments objectAtIndex:index];
                NSArray * array = [input componentsSeparatedByString:@","];
                NSString * val = [array objectAtIndex:2];
                
                NSNumber *x = [NSNumber numberWithInt:[val integerValue] ];
                NSLog(@"JAY %@",x);
                return [NSNumber numberWithInt:25];
            }
            break;
    }
    return [NSDecimalNumber zero];
}
#pragma mark - Chart behavior



-(void)initPlot {
    [self configureHost];
    [self configureGraph];
    [self configurePlots];
    [self configureAxes];
}

-(void)configureHost {
    // 1 - Set up view frame
    CGRect parentRect = self.corePlotView.bounds;
    
    parentRect = CGRectMake(parentRect.origin.x,
                            parentRect.origin.y ,
                            parentRect.size.width,
                            parentRect.size.height);
    // 2 - Create host view
     self.bytesSentHostView = [(CPTGraphHostingView *) [CPTGraphHostingView alloc] initWithFrame:parentRect];
     self.bytesSentHostView.allowPinchScaling = YES;
    self.bytesSentHostView.backgroundColor = [UIColor whiteColor];
    [self.corePlotView addSubview:self.bytesSentHostView];
}

-(void)configureGraph {
    // 1 - Create the graph
    CPTGraph *graph = [[CPTXYGraph alloc] initWithFrame:self.bytesSentHostView.bounds];
    [graph applyTheme:[CPTTheme themeNamed:kCPTDarkGradientTheme]];
    self.bytesSentHostView.hostedGraph = graph;
    // 2 - Set graph title
    NSString *title = @"bytesSent";
    graph.title = title;
    // 3 - Create and set text style
    CPTMutableTextStyle *titleStyle = [CPTMutableTextStyle textStyle];
    titleStyle.color = [CPTColor whiteColor];
    titleStyle.fontName = @"Helvetica-Bold";
    titleStyle.fontSize = 12.0f;
    graph.titleTextStyle = titleStyle;
    graph.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    graph.titleDisplacement = CGPointMake(0.0f, 10.0f);
    // 4 - Set padding for plot area
    [graph.plotAreaFrame setPaddingLeft:10.0f];
    [graph.plotAreaFrame setPaddingBottom:10.0f];
    // 5 - Enable user interactions for plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *) graph.defaultPlotSpace;
    plotSpace.allowsUserInteraction = NO;
}
-(void)configurePlots {
    // 1 - Get graph and plot space
    CPTGraph *graph = self.bytesSentHostView.hostedGraph;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *) graph.defaultPlotSpace;
    
    // 2 - Create the three plots
    CPTScatterPlot *bytesSentPlot = [[CPTScatterPlot alloc] init];
    bytesSentPlot.dataSource = self;
    bytesSentPlot.identifier = kBytesSent;
    
    [graph addPlot:bytesSentPlot toPlotSpace:plotSpace];
    
    // 3 - Set up plot space
    [plotSpace scaleToFitPlots:[NSArray arrayWithObjects:bytesSentPlot,  nil]];
    CPTMutablePlotRange *xRange = [plotSpace.xRange mutableCopy];
    [xRange expandRangeByFactor:CPTDecimalFromCGFloat(1.1f)];
    plotSpace.xRange = xRange;
    CPTMutablePlotRange *yRange = [plotSpace.yRange mutableCopy];
    [yRange expandRangeByFactor:CPTDecimalFromCGFloat(1.2f)];
    plotSpace.yRange = yRange;
    
    
    // 4 - Create styles and symbols
    CPTMutableLineStyle *bytesSentLineStyle = [bytesSentPlot.dataLineStyle mutableCopy];
    bytesSentLineStyle.lineWidth = 2.5;
    CPTColor *bytesSentColor = [CPTColor redColor];
    bytesSentLineStyle.lineColor = bytesSentColor;
    bytesSentPlot.dataLineStyle = bytesSentLineStyle;
    /*
    CPTMutableLineStyle *bytesSentSymbolLineStyle = [CPTMutableLineStyle lineStyle];
    bytesSentSymbolLineStyle.lineColor = bytesSentColor;
    CPTPlotSymbol *bytesSentSymbol = [CPTPlotSymbol ellipsePlotSymbol];
    bytesSentSymbol.fill = [CPTFill fillWithColor:bytesSentColor];
    bytesSentSymbol.lineStyle = bytesSentLineStyle;
    bytesSentSymbol.size = CGSizeMake(6.0f, 6.0f);
    bytesSentPlot.plotSymbol = bytesSentSymbol;
     */
    
}

-(void)configureAxes {
    
    // 1 - Create styles
    CPTMutableTextStyle *axisTitleStyle = [CPTMutableTextStyle textStyle];
    axisTitleStyle.color = [CPTColor whiteColor];
    axisTitleStyle.fontName = @"Helvetica-Bold";
    axisTitleStyle.fontSize = 12.0f;
    CPTMutableLineStyle *axisLineStyle = [CPTMutableLineStyle lineStyle];
    axisLineStyle.lineWidth = 2.0f;
    axisLineStyle.lineColor = [CPTColor whiteColor];
    CPTMutableTextStyle *axisTextStyle = [[CPTMutableTextStyle alloc] init];
    axisTextStyle.color = [CPTColor whiteColor];
    axisTextStyle.fontName = @"Helvetica-Bold";
    axisTextStyle.fontSize = 11.0f;
    CPTMutableLineStyle *tickLineStyle = [CPTMutableLineStyle lineStyle];
    tickLineStyle.lineColor = [CPTColor whiteColor];
    tickLineStyle.lineWidth = 2.0f;
    CPTMutableLineStyle *gridLineStyle = [CPTMutableLineStyle lineStyle];
    tickLineStyle.lineColor = [CPTColor blackColor];
    tickLineStyle.lineWidth = 1.0f;
    // 2 - Get axis set
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *) self.bytesSentHostView.hostedGraph.axisSet;
    // 3 - Configure x-axis
    CPTAxis *x = axisSet.xAxis;
    x.title = @"Day of Month";
    x.titleTextStyle = axisTitleStyle;
    x.titleOffset = 15.0f;
    x.axisLineStyle = axisLineStyle;
    x.labelingPolicy = CPTAxisLabelingPolicyNone;
    x.labelTextStyle = axisTextStyle;
    x.majorTickLineStyle = axisLineStyle;
    x.majorTickLength = 4.0f;
    x.tickDirection = CPTSignNegative;
    CGFloat dateCount = 2;
    NSMutableSet *xLabels = [NSMutableSet setWithCapacity:dateCount];
    NSMutableSet *xLocations = [NSMutableSet setWithCapacity:dateCount];
    NSInteger i = 0;
    
//    for (NSString *date in [[CPDStockPriceStore sharedInstance] datesInMonth]) {
//        CPTAxisLabel *label = [[CPTAxisLabel alloc] initWithText:date  textStyle:x.labelTextStyle];
//        CGFloat location = i++;
//        label.tickLocation = CPTDecimalFromCGFloat(location);
//        label.offset = x.majorTickLength;
//        if (label) {
//            [xLabels addObject:label];
//            [xLocations addObject:[NSNumber numberWithFloat:location]];
//        }
//    }
    x.axisLabels = xLabels;
    x.majorTickLocations = xLocations;
    // 4 - Configure y-axis
    CPTAxis *y = axisSet.yAxis;
    y.title = @"Price";
    y.titleTextStyle = axisTitleStyle;
    y.titleOffset = -40.0f;
    y.axisLineStyle = axisLineStyle;
    y.majorGridLineStyle = gridLineStyle;
    y.labelingPolicy = CPTAxisLabelingPolicyNone;
    y.labelTextStyle = axisTextStyle;
    y.labelOffset = 16.0f;
    y.majorTickLineStyle = axisLineStyle;
    y.majorTickLength = 4.0f;
    y.minorTickLength = 2.0f;
    y.tickDirection = CPTSignPositive;
    NSInteger majorIncrement = 100;
    NSInteger minorIncrement = 50;
    CGFloat yMax = 700.0f;  // should determine dynamically based on max price
    NSMutableSet *yLabels = [NSMutableSet set];
    NSMutableSet *yMajorLocations = [NSMutableSet set];
    NSMutableSet *yMinorLocations = [NSMutableSet set];
    for (NSInteger j = minorIncrement; j <= yMax; j += minorIncrement) {
        NSUInteger mod = j % majorIncrement;
        if (mod == 0) {
            CPTAxisLabel *label = [[CPTAxisLabel alloc] initWithText:[NSString stringWithFormat:@"%i", j] textStyle:y.labelTextStyle];
            NSDecimal location = CPTDecimalFromInteger(j);
            label.tickLocation = location;
            label.offset = -y.majorTickLength - y.labelOffset;
            if (label) {
                [yLabels addObject:label];
            }
            [yMajorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:location]];
        } else {
            [yMinorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:CPTDecimalFromInteger(j)]];
        }
    }
    y.axisLabels = yLabels;    
    y.majorTickLocations = yMajorLocations;
    y.minorTickLocations = yMinorLocations;
}
@end
