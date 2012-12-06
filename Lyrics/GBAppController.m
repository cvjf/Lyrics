//
//  GBLyricsBrowserView.m
//  Lyrics
//
//  Created by 竞纬 戴 on 5/6/12.
//  Copyright (c) 2012 Hunan Institute of Science. All rights reserved.
//

#import "GBAppController.h"
#import "iTunes.h"
#import "Safari.h"
#import <ScriptingBridge/ScriptingBridge.h>
#import <ApplicationServices/ApplicationServices.h>

#define GBLocString(key) NSLocalizedString (key, nil)

NSString *GBPrefWindowIsPinned;
NSString *GBPrefWindowIsAtTop;
NSString *GBPrefWindowIsAttachedToOthers;

NSString *kSearchQueryPrefix;

@interface GBAppController ()

@property (unsafe_unretained) IBOutlet NSButton	*postOnWeiboButton;
@property (unsafe_unretained) IBOutlet NSButton *postOnTwitterButton;

@property (nonatomic, strong) NSSharingService *weiboSharingService;
@property (nonatomic, strong) NSSharingService *twitterSharingServer;

@property (unsafe_unretained) IBOutlet NSTextView  *lyricsBrowser;
@property (unsafe_unretained) IBOutlet NSTextField *currentTrackName;
@property (unsafe_unretained) IBOutlet NSTextField *currentTrackAlbum;
@property (unsafe_unretained) IBOutlet NSTextField *currentTrackArtist;

@property (unsafe_unretained) IBOutlet NSPopover *preferencePopover;

@property (nonatomic, strong) iTunesFileTrack *currentTrack;
@property (nonatomic, strong, readonly) iTunesApplication *iTunesApp;
@property (nonatomic, strong, readonly) NSArray *currentTrackDescription;

@property (nonatomic, assign) BOOL hasUnsavedChanges;
@property (nonatomic, assign) BOOL isInteractingWithUser;

@property (nonatomic, assign) BOOL mainWindowIsAtTop;
@property (nonatomic, assign) BOOL mainWindowIsPinned;
@property (nonatomic, assign) BOOL mainWindowIsAttachedToOthers;

- (void)lyricsViewContentDidChange:(NSNotification *)notification;
- (void)iTunesPlayerStateDidChange:(NSNotification *)notification;

- (void)askUserToCommitChanges:(id)sender;					// auto-update property self.userHasMadeChangesToLyrics
- (void)iTunesPlayerDidChangeToNewTrack;
- (void)iTunesPlayerDidStopPlaying;

- (IBAction)searchForLyrics:(id)sender;
- (IBAction)togglePreferencePopover:(id)sender;

- (IBAction)postOnWeiboPressed:(id)sender;
- (IBAction)postOnTwitterPressed:(id)sender;

@end

@implementation GBAppController

@synthesize iTunesApp		= _iTunesApp;
@synthesize currentTrack	= _currentTrack;

@synthesize postOnWeiboButton   = _postOnWeiboButton;
@synthesize postOnTwitterButton = _postOnTwitterButton;

@synthesize lyricsBrowser		= _lyricsBrowser;
@synthesize currentTrackName	= _currentTrackName;
@synthesize currentTrackAlbum	= _currentTrackAlbum;
@synthesize currentTrackArtist	= _currentTrackArtist;

@synthesize preferencePopover		= _preferencePopover;
@synthesize hasUnsavedChanges		= _hasUnsavedChanges;		// auto-update window title
@synthesize mainWindowIsAtTop		= _mainWindowIsAtTop;
@synthesize mainWindowIsPinned		= _mainWindowIsPinned;
@synthesize isInteractingWithUser	= _isInteractingWithUser;
@synthesize mainWindowIsAttachedToOthers = _mainWindowIsAttachedToOthers;

+ (void)initialize
{
	GBPrefWindowIsAtTop  = @"GBPrefWindowIsAtTop";
	GBPrefWindowIsPinned = @"GBPrefWindowIsPinned";
	GBPrefWindowIsAttachedToOthers = @"GBPrefWindowIsAttachedToOthers";

	kSearchQueryPrefix = @"www.google.com/search?q=";

	NSDictionary *defaults = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithBool:YES], GBPrefWindowIsAttachedToOthers, nil];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


#pragma mark
#pragma mark App Controller

- (IBAction)quitApp:(id)sender
{
	if (self.hasUnsavedChanges)
		[self askUserToCommitChanges:nil];

	[[self.window animator] setAlphaValue:0.0];
	NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.3] interval:0 target:NSApp selector:@selector(terminate:) userInfo:nil repeats:NO];

	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (IBAction)hideApp:(id)sender
{
	[[self.window animator] setAlphaValue:0.0];
	NSTimer *hideTimer = [NSTimer timerWithTimeInterval:0 target:NSApp selector:@selector(hide:) userInfo:nil repeats:NO];
	[hideTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
	[[NSRunLoop currentRunLoop] addTimer:hideTimer forMode:NSDefaultRunLoopMode];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
	[[self.window animator] setAlphaValue:1.0];
	NSTimer *unhideTimer = [NSTimer timerWithTimeInterval:0 target:NSApp selector:@selector(unhide:) userInfo:nil repeats:NO];
	[unhideTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
	[[NSRunLoop currentRunLoop] addTimer:unhideTimer forMode:NSDefaultRunLoopMode];

	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(lyricsViewContentDidChange:) 
												 name:NSTextDidChangeNotification object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self 
														selector:@selector(iTunesPlayerStateDidChange:)
															name:@"com.apple.iTunes.playerInfo" object:nil];

	NSString  *	fontFace = @"Optima Italic";
	CGFloat		fontSize = 14.0;
	
	[self.lyricsBrowser setAlignment:NSCenterTextAlignment];
	[self.lyricsBrowser setTextColor:[NSColor whiteColor]];
	[self.lyricsBrowser setFont:[NSFont fontWithName:fontFace size:fontSize]];
	[self.lyricsBrowser setInsertionPointColor:[NSColor whiteColor]];
	
	// update the lyrics browser accrodingly
	if (self.iTunesApp.isRunning && (self.iTunesApp.currentTrack.name != nil))
		[self iTunesPlayerDidChangeToNewTrack];
	else
		[self iTunesPlayerDidStopPlaying];

	[self.window orderFront:self];
	[[self.window animator] setAlphaValue:1.0];

	[self.postOnWeiboButton sendActionOn:NSLeftMouseUpMask];
	[self.postOnTwitterButton sendActionOn:NSLeftMouseUpMask];

//	self.postOnWeiboButton.image = self.weiboSharingService.image;
//	self.postOnTwitterButton.image = self.twitterSharingServer.image;
}


#pragma mark
#pragma mark iTunes Control

- (IBAction)commitChangesToLyrics:(id)sender
{
	[self askUserToCommitChanges:sender];
}

- (void)lyricsViewContentDidChange:(NSNotification *)notification
{
	if (!self.hasUnsavedChanges)
		self.hasUnsavedChanges = YES;
}

- (void)iTunesPlayerStateDidChange:(NSNotification *)notification
{
	if (self.isInteractingWithUser)
		return;

	NSString *playerState = [notification.userInfo valueForKey:@"Player State"];

	if ([playerState isEqualToString:@"Playing"])
	{
		if (![self.currentTrack.persistentID isEqualToString:self.iTunesApp.currentTrack.persistentID])
			[self iTunesPlayerDidChangeToNewTrack];
	}
	
	else if ([playerState isEqualToString:@"Stopped"])
		[self iTunesPlayerDidStopPlaying];
}

- (void)iTunesPlayerDidChangeToNewTrack
{
	if (self.hasUnsavedChanges)
		[self askUserToCommitChanges:nil];

	self.currentTrack = [self.iTunesApp.currentTrack get];
	self.hasUnsavedChanges = NO;		// takes care of window title
}

- (void)iTunesPlayerDidStopPlaying
{
	if (self.hasUnsavedChanges)
		[self askUserToCommitChanges:nil];

	self.currentTrack = nil;
	self.hasUnsavedChanges = NO;
}

- (void)askUserToCommitChanges:(id)sender
{
	if (!self.window.isVisible)
		[[self.window animator] setAlphaValue:1.0];
	
	self.isInteractingWithUser = YES;
	NSString *otherButtonTitle = ( sender == nil ? GBLocString(@"Discard") /* track changed */ : GBLocString(@"Cancel")	/* user clicked save */ );

	NSAlert *saveAlert = [NSAlert alertWithMessageText:GBLocString(@"SaveAlertMessage") defaultButton:GBLocString(@"Save") alternateButton:GBLocString(@"Export...") otherButton:otherButtonTitle informativeTextWithFormat:@"%@: %@\n%@: %@", GBLocString(@"Artist"), self.currentTrack.artist, GBLocString(@"Track"), self.currentTrack.name];
	
	[saveAlert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(saveLyricsSheetDidEnd:returnCode:contextInfo:) contextInfo:(void *)sender];
	[saveAlert runModal];			// very important!!!
}

- (void)saveLyricsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(id)sender
{
	if (returnCode == NSAlertDefaultReturn) {
		self.currentTrack.lyrics = self.lyricsBrowser.string;
		self.hasUnsavedChanges = NO;
	}

	else if (returnCode == NSAlertOtherReturn)
	{
		if (!sender)
			self.hasUnsavedChanges = NO;
	}
	
	else if (returnCode == NSAlertAlternateReturn)
	{
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		
		[savePanel setNameFieldStringValue:[NSString stringWithFormat:@"%@ - %@", self.currentTrack.artist, self.currentTrack.name]];
		[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"txt"]];
		NSInteger returnCode = [savePanel runModal];
		if (returnCode == NSFileHandlingPanelOKButton)
			[self.lyricsBrowser.string writeToURL:savePanel.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
		
		self.hasUnsavedChanges = NO;
	}

	self.isInteractingWithUser = NO;
	[NSApp stopModal];			// stops the modal session incurred by askUserToCommitChanges: sheet
}


#pragma mark
#pragma mark Properties

- (iTunesApplication *)iTunesApp
{
	if (!_iTunesApp)
		_iTunesApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
	return _iTunesApp;
}

- (void)setHasUnsavedChanges:(BOOL)hasUnsavedChanges
{
	_hasUnsavedChanges = hasUnsavedChanges;
	
	if (self.currentTrack != nil)
	{
		if (_hasUnsavedChanges)
			self.window.title = [self.currentTrack.name stringByAppendingString:GBLocString(@"Edited")];
		else
		{
			self.window.title = self.currentTrack.name;
			[[self.lyricsBrowser undoManager] removeAllActionsWithTarget:self.lyricsBrowser.textStorage];		// important!!!!!!!!
		}
	}
	else
		self.window.title = GBLocString(@"Lyrics");
}

- (void)setCurrentTrack:(iTunesFileTrack *)currentTrack
{
	_currentTrack = currentTrack;
	
	if (_currentTrack)
	{
		self.lyricsBrowser.string				= _currentTrack.lyrics;
		self.currentTrackAlbum.stringValue		= _currentTrack.album;
		self.currentTrackArtist.stringValue		= _currentTrack.artist;
		self.currentTrackName.stringValue		= _currentTrack.name;
		
		[self.lyricsBrowser setEditable:YES];
		[self.lyricsBrowser scrollToBeginningOfDocument:self];
	}

	else
	{
		self.lyricsBrowser.string				= @"";
		self.currentTrackAlbum.stringValue		= @"";
		self.currentTrackArtist.stringValue		= @"";
		self.currentTrackName.stringValue		= @"";
		
		[self.lyricsBrowser setEditable:NO];
	}
}

#pragma mark
#pragma mark Popover View

- (BOOL)mainWindowIsAtTop
{
	_mainWindowIsAtTop = [[NSUserDefaults standardUserDefaults] boolForKey:GBPrefWindowIsAtTop];

	if (_mainWindowIsAtTop)
		[self.window setLevel:NSFloatingWindowLevel];
	else
		[self.window setLevel:NSNormalWindowLevel];
	
	return _mainWindowIsAtTop;
}

- (void)setMainWindowIsAtTop:(BOOL)mainWindowIsAtTop
{
	if (_mainWindowIsAtTop == mainWindowIsAtTop)
		return;

	_mainWindowIsAtTop = mainWindowIsAtTop;

	if (_mainWindowIsAtTop)
		[self.window setLevel:NSFloatingWindowLevel];
	else
		[self.window setLevel:NSNormalWindowLevel];

	[[NSUserDefaults standardUserDefaults] setBool:_mainWindowIsAtTop forKey:GBPrefWindowIsAtTop];

}

- (BOOL)mainWindowIsPinned
{
	_mainWindowIsPinned = [[NSUserDefaults standardUserDefaults] boolForKey:GBPrefWindowIsPinned];

	if (_mainWindowIsPinned)
		[self.window setCollectionBehavior:NSWindowCollectionBehaviorDefault];
	else
		[self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];

	return _mainWindowIsPinned;
}

- (void)setMainWindowIsPinned:(BOOL)mainWindowIsPinned
{
	if (mainWindowIsPinned == _mainWindowIsPinned)
		return;

	_mainWindowIsPinned = mainWindowIsPinned;

	if (_mainWindowIsPinned)
		[self.window setCollectionBehavior:NSWindowCollectionBehaviorDefault];
	else
		[self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];

	[[NSUserDefaults standardUserDefaults] setBool:_mainWindowIsPinned forKey:GBPrefWindowIsPinned];
}

- (BOOL)mainWindowIsAttachedToOthers
{
	_mainWindowIsAttachedToOthers = [[NSUserDefaults standardUserDefaults] boolForKey:GBPrefWindowIsAttachedToOthers];

	if (!_mainWindowIsAttachedToOthers) {
		ProcessSerialNumber psn = { 0, kCurrentProcess };

		TransformProcessType(&psn, kProcessTransformToForegroundApplication);
		SetFrontProcess(&psn);
	}

	return _mainWindowIsAttachedToOthers;
}

- (void)setMainWindowIsAttachedToOthers:(BOOL)mainWindowIsAttachedToOthers
{
	_mainWindowIsAttachedToOthers = mainWindowIsAttachedToOthers;
	
	ProcessSerialNumber psn = { 0, kCurrentProcess };

	if (_mainWindowIsAttachedToOthers == NSOnState) {
		TransformProcessType(&psn, kProcessTransformToUIElementApplication);
		SetFrontProcess(&psn);
	}
	else {
        TransformProcessType(&psn, kProcessTransformToForegroundApplication);
        SetFrontProcess(&psn);
	}

	[[NSUserDefaults standardUserDefaults] setBool:_mainWindowIsAttachedToOthers forKey:GBPrefWindowIsAttachedToOthers];
}

- (void)togglePreferencePopover:(NSButton *)sender
{
	if (self.preferencePopover.shown)
		[self.preferencePopover close];
	else
		[self.preferencePopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSMaxYEdge];
}

- (void)searchForLyrics:(id)sender
{
	NSString *trackName = self.currentTrackName.stringValue;
	NSString *trackArtist = self.currentTrackArtist.stringValue;

	NSString *searchQueryRaw = [[NSString stringWithFormat:@"%@ %@", [trackArtist isEqualToString:@""] ? trackName : [NSString stringWithFormat:@"%@ %@", trackArtist, trackName], GBLocString(@"lyrics")] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *searchQuery = [searchQueryRaw stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
	NSString *searchURL = [NSString stringWithFormat:@"http://%@%@", kSearchQueryPrefix, searchQuery];

//	NSLog(@"%@", [NSURL URLWithString:searchURL]);

	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:searchURL]];
}



#pragma mark
#pragma mark Sharing Services

- (void)postOnWeiboPressed:(id)sender
{
	NSSharingService *weiboService = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnSinaWeibo];

	weiboService.delegate = self;

	[weiboService performWithItems:self.currentTrackDescription];
}

- (void)postOnTwitterPressed:(id)sender
{
	NSSharingService *twitterService = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnTwitter];

	twitterService.delegate = self;

	[twitterService performWithItems:self.currentTrackDescription];
}

- (NSWindow *)sharingService:(NSSharingService *)sharingService sourceWindowForShareItems:(NSArray *)items sharingContentScope:(NSSharingContentScope *)sharingContentScope
{
	return self.window;
}

- (NSSharingService *)weiboSharingService
{
	if (!_weiboSharingService) {
		_weiboSharingService = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnSinaWeibo];
		_weiboSharingService.delegate = self;
	}
	return _weiboSharingService;
}

- (NSSharingService *)twitterSharingServer
{
	if (!_twitterSharingServer) {
		_twitterSharingServer = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnTwitter];
		_twitterSharingServer.delegate = self;
	}
	return _twitterSharingServer;
}

- (NSArray *)currentTrackDescription
{
	NSMutableString *descriptionStr = [[NSMutableString alloc] initWithCapacity:30];

	if (![self.currentTrackArtist.stringValue isEqualToString:@""])
		[descriptionStr appendFormat:@"#%@# - ", self.currentTrackArtist.stringValue];

	[descriptionStr appendFormat:@"%@", self.currentTrackName.stringValue];

	iTunesArtwork *artwork = [[self.currentTrack.artworks get] lastObject];
	NSImage *artworkImage = nil;

	if (artwork)
		artworkImage = [[NSImage alloc] initWithData:artwork.rawData];

	return [NSArray arrayWithObjects:descriptionStr, artworkImage, nil];
}


@end
