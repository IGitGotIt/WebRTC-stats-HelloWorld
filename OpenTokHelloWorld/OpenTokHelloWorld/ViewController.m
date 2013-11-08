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
NSMutableArray * packetsSentAssignments;
NSMutableArray * audioInputLevelAssignments;

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
    
    //mutable to make it thread safe
    
    for (NSString* assignment in [ bytesSentAssignments mutableCopy]) {
        if ([assignment rangeOfString:kBytesSent].location != NSNotFound) {
            [report appendString:[assignment stringByAppendingString:@"\n"]];
           
        }
    }
   
    [report appendString:@"\n"];
    for (NSString* assignment in [ packetsSentAssignments mutableCopy]) {
        if ([assignment rangeOfString:kPacketsSent].location != NSNotFound) {
         [report appendString:[assignment stringByAppendingString:@"\n"]];
        }
    }
    [report appendString:@"\n"];
    
    for (NSString* assignment in [ audioInputLevelAssignments mutableCopy]) {
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
                    if(packetsSentAssignments == nil)
                    {
                        packetsSentAssignments = [[NSMutableArray alloc] init];
                    }
                    if(audioInputLevelAssignments == nil)
                    {
                        audioInputLevelAssignments = [[NSMutableArray alloc] init];
                    }

                    if([assignmentLHS isEqualToString:kBytesSent])
                    {
                        [bytesSentAssignments addObject:[NSString stringWithFormat:@"%@,%@,%@",assignmentLHS,date,assignmentRHS] ];
                        
                    }
                    if([assignmentLHS isEqualToString:kPacketsSent])
                    {
                        [packetsSentAssignments addObject:[NSString stringWithFormat:@"%@,%@,%@",assignmentLHS,date,assignmentRHS] ];
                        
                    }
                    if([assignmentLHS isEqualToString:kAudioInputLevel])
                    {
                        [audioInputLevelAssignments addObject:[NSString stringWithFormat:@"%@,%@,%@",assignmentLHS,date,assignmentRHS] ];
                        
                    }

                   NSNotification * note = [[NSNotification alloc] initWithName:kNotificationName object:nil userInfo:nil];
                    [[NSNotificationCenter defaultCenter] postNotification:note];
                    
                    
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
  //  [self.bytesSentHostView reloadInputViews];
 //   [self.bytesSentHostView.hostedGraph reloadData];
    
}


#pragma mark - CPTPlotDataSource methods

// Therefore this class implements the CPTPlotDataSource protocol
-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plotnumberOfRecords {
        return audioInputLevelAssignments.count;
}
/*
// This method is here because this class also functions as datasource for our graph
// Therefore this class implements the CPTPlotDataSource protocol

*/
-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    
    // This method is actually called twice per point in the plot, one for the X and one for the Y value
    if(fieldEnum == CPTScatterPlotFieldX)
    {
        
        return [NSNumber numberWithInt: index];
    } else {
        NSString * input = [audioInputLevelAssignments objectAtIndex:index];
        NSArray * array = [input componentsSeparatedByString:@","];
        NSString * val = [array objectAtIndex:2];
        
        return [NSNumber numberWithInt:([val integerValue] / 100) ];
    }
}
#pragma mark - Chart behavior



-(void)initPlot {

 // We need a hostview, you can create one in IB (and create an outlet) or just do this:
    CGRect parentRect = self.corePlotView.bounds;
    
    parentRect = CGRectMake(parentRect.origin.x,
                            parentRect.origin.y ,
                            parentRect.size.width,
                            parentRect.size.height);
    // 2 - Create host view
    self.bytesSentHostView = [(CPTGraphHostingView *) [CPTGraphHostingView alloc] initWithFrame:parentRect];

   // CPTGraphHostingView* hostView = [[CPTGraphHostingView alloc] initWithFrame:self.corePlotView.frame];
    self.corePlotView.backgroundColor =[UIColor whiteColor];
    [self.corePlotView addSubview:  self.bytesSentHostView];
    
    // Create a CPTGraph object and add to hostView
    CPTGraph* graph = [[CPTXYGraph alloc] initWithFrame: self.bytesSentHostView.bounds];
    graph.title = @"audio Input Level (00)";
     self.bytesSentHostView.hostedGraph = graph;
    
    // Get the (default) plotspace from the graph so we can set its x/y ranges
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *) graph.defaultPlotSpace;
    
    // Note that these CPTPlotRange are defined by START and LENGTH (not START and END) !!
    [plotSpace setYRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat( 0 ) length:CPTDecimalFromFloat( 10)]];
    [plotSpace setXRange: [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat( -1 ) length:CPTDecimalFromFloat( 8)]];
    
    // Create the plot (we do not define actual x/y values yet, these will be supplied by the datasource...)
    CPTScatterPlot* plot = [[CPTScatterPlot alloc] initWithFrame:CGRectZero];
    
    // Let's keep it simple and let this class act as datasource (therefore we implemtn <CPTPlotDataSource>)
    plot.dataSource = self;
    
        // Finally, add the created plot to the default plot space of the CPTGraph object we created before
    [graph addPlot:plot toPlotSpace:graph.defaultPlotSpace];
}

@end
