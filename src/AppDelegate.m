/*
 * Copyright (C) 2010-2016 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AppDelegate.h"

#import "BrowserWindowController.h"
#import "ExtensionManagerWindowController.h"
#import "SettingsController.h"
#import <WebKit/WKPreferencesPrivate.h>
#import <WebKit/WKProcessPoolPrivate.h>
#import <WebKit/WKUserContentControllerPrivate.h>
#import <WebKit/WKWebViewConfigurationPrivate.h>
#import <WebKit/WKWebsiteDataStorePrivate.h>
#import <WebKit/WebKit.h>
#import <WebKit/_WKFeature.h>
#import <WebKit/_WKProcessPoolConfiguration.h>
#import <WebKit/_WKWebsiteDataStoreConfiguration.h>

@implementation NSApplication (MiniBrowserApplicationExtensions)

- (BrowserAppDelegate *)browserAppDelegate
{
    return (BrowserAppDelegate *)[self delegate];
}

@end

@interface NSApplication (TouchBar)
@property (getter=isAutomaticCustomizeTouchBarMenuItemEnabled) BOOL automaticCustomizeTouchBarMenuItemEnabled;

@property (readonly, nonatomic) WKWebViewConfiguration *defaultConfiguration;

@end

@implementation BrowserAppDelegate

- (id)init
{
    self = [super init];
    if (self) {
        _browserWindowControllers = [[NSMutableSet alloc] init];
        _extensionManagerWindowController = [[ExtensionManagerWindowController alloc] init];
        _openNewWindowAtStartup = true;
    }

    return self;
}

- (void)awakeFromNib
{
    _settingsController = [[SettingsController alloc] initWithMenu:_settingsMenu];

    if ([_settingsController usesGameControllerFramework])
        [WKProcessPool _forceGameControllerFramework];

    if ([NSApp respondsToSelector:@selector(setAutomaticCustomizeTouchBarMenuItemEnabled:)])
        [NSApp setAutomaticCustomizeTouchBarMenuItemEnabled:YES];
}

static WKWebsiteDataStore *persistentDataStore(void)
{
    static WKWebsiteDataStore *dataStore;

    if (!dataStore) {
        _WKWebsiteDataStoreConfiguration *configuration = [[_WKWebsiteDataStoreConfiguration alloc] init];
        configuration.networkCacheSpeculativeValidationEnabled = YES;

        // FIXME: When built-in notifications are enabled, WebKit doesn't yet gracefully handle a missing webpushd service
        // Until it does, uncomment this line when the service is known to be installed.
        // [configuration setWebPushMachServiceName:@"org.webkit.webpushtestdaemon.service"];

        dataStore = [[WKWebsiteDataStore alloc] _initWithConfiguration:configuration];
    }

    return dataStore;
}

- (WKWebViewConfiguration *)defaultConfiguration
{
    static WKWebViewConfiguration *configuration;

    if (!configuration) {
        configuration = [[WKWebViewConfiguration alloc] init];
        configuration.websiteDataStore = persistentDataStore();

        _WKProcessPoolConfiguration *processConfiguration = [[_WKProcessPoolConfiguration alloc] init];
        if (_settingsController.perWindowWebProcessesDisabled)
            processConfiguration.usesSingleWebProcess = YES;

        configuration.processPool = [[WKProcessPool alloc] _initWithConfiguration:processConfiguration];

        NSArray<_WKFeature *> *features = [WKPreferences _features];
        for (_WKFeature *feature in features) {
            if ([feature.key isEqualToString:@"MediaDevicesEnabled"])
                continue;

            BOOL enabled;
            if ([[NSUserDefaults standardUserDefaults] objectForKey:feature.key])
                enabled = [[NSUserDefaults standardUserDefaults] boolForKey:feature.key];
            else
                enabled = [feature defaultValue];
            [configuration.preferences _setEnabled:enabled forFeature:feature];
        }

        configuration.preferences.elementFullscreenEnabled = YES;
        configuration.preferences._allowsPictureInPictureMediaPlayback = YES;
        configuration.preferences._developerExtrasEnabled = YES;
        configuration.preferences._accessibilityIsolatedTreeEnabled = YES;
        configuration.preferences._logsPageMessagesToSystemConsoleEnabled = YES;
    }

    configuration.suppressesIncrementalRendering = _settingsController.incrementalRenderingSuppressed;
    configuration.websiteDataStore._resourceLoadStatisticsEnabled = _settingsController.resourceLoadStatisticsEnabled;
    return configuration;
}

- (WKPreferences *)defaultPreferences
{
    return self.defaultConfiguration.preferences;
}

- (BrowserWindowController *)createBrowserWindowController:(id)sender
{
    BrowserWindowController *controller = nil;

    controller = [[BrowserWindowController alloc] initWithConfiguration:[self defaultConfiguration]];
    if (!controller)
        return nil;

    [_browserWindowControllers addObject:controller];

    return controller;
}

- (IBAction)newWindow:(id)sender
{
    WKWebViewConfiguration *privateConfiguraton = [self.defaultConfiguration copy];
    privateConfiguraton.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];

    BrowserWindowController *controller = [[BrowserWindowController alloc] initWithConfiguration:privateConfiguraton];
    if (!controller)
        return;

    [[controller window] makeKeyAndOrderFront:sender];
    [_browserWindowControllers addObject:controller];

    if (!_settingsController.startWithEmptyPage)
        [controller loadURLString:_settingsController.defaultURL];
}

- (IBAction)newWindowForTab:(id)sender
{
    [self newWindow:sender];
}

- (void)didCreateBrowserWindowController:(BrowserWindowController *)controller
{
    [_browserWindowControllers addObject:controller];
}

- (void)browserWindowWillClose:(NSWindow *)window
{
    [_browserWindowControllers removeObject:window.windowController];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    WebHistory *webHistory = [[WebHistory alloc] init];
    [WebHistory setOptionalSharedHistory:webHistory];

    [self _updateNewWindowKeyEquivalents];

    if (!_openNewWindowAtStartup)
        return;

    [self newWindow:self];
}

- (BrowserWindowController *)frontmostBrowserWindowController
{
    for (NSWindow *window in [NSApp windows]) {
        id delegate = [window delegate];

        if (![delegate isKindOfClass:[BrowserWindowController class]])
            continue;

        BrowserWindowController *controller = (BrowserWindowController *)delegate;
        assert([_browserWindowControllers containsObject:controller]);
        return controller;
    }

    return nil;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    BrowserWindowController *controller = [self createBrowserWindowController:nil];
    if (!controller)
        return NO;

    [controller.window makeKeyAndOrderFront:self];
    [controller loadURLString:[NSURL fileURLWithPath:filename].absoluteString];
    _openNewWindowAtStartup = false;
    return YES;
}

- (IBAction)openDocument:(id)sender
{
    BrowserWindowController *browserWindowController = [self frontmostBrowserWindowController];

    if (browserWindowController) {
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel beginSheetModalForWindow:browserWindowController.window completionHandler:^(NSInteger result) {
            if (result != NSModalResponseOK)
                return;

            NSURL *url = [openPanel.URLs objectAtIndex:0];
            [browserWindowController loadURLString:[url absoluteString]];
        }];
        return;
    }

    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result != NSModalResponseOK)
            return;

        BrowserWindowController *controller = [self createBrowserWindowController:nil];
        [controller.window makeKeyAndOrderFront:self];

        NSURL *url = [openPanel.URLs objectAtIndex:0];
        [controller loadURLString:[url absoluteString]];
    }];
}

- (void)didChangeSettings
{
    [self _updateNewWindowKeyEquivalents];

    // Let all of the BrowserWindowControllers know that a setting changed, so they can attempt to dynamically update.
    for (BrowserWindowController *browserWindowController in _browserWindowControllers)
        [browserWindowController didChangeSettings];
}

- (void)_updateNewWindowKeyEquivalents
{
    NSEventModifierFlags webKit2Flags = 0;

    NSString *normalWindowEquivalent = @"n";

    _newWebKit2WindowItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | webKit2Flags;
    _newWebKit2WindowItem.keyEquivalent = normalWindowEquivalent;
}

- (IBAction)showExtensionsManager:(id)sender
{
    [_extensionManagerWindowController showWindow:sender];
}

- (WKUserContentController *)userContentContoller
{
    return self.defaultConfiguration.userContentController;
}

- (IBAction)fetchDefaultStoreWebsiteData:(id)sender
{
    [persistentDataStore() fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes] completionHandler:^(NSArray *websiteDataRecords) {
        NSLog(@"did fetch default store website data %@.", websiteDataRecords);
    }];
}

- (IBAction)fetchAndClearDefaultStoreWebsiteData:(id)sender
{
    [persistentDataStore() fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes] completionHandler:^(NSArray *websiteDataRecords) {
        [persistentDataStore() removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes] forDataRecords:websiteDataRecords completionHandler:^{
            [persistentDataStore() fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes] completionHandler:^(NSArray *websiteDataRecords) {
                NSLog(@"did clear default store website data, after clearing data is %@.", websiteDataRecords);
            }];
        }];
    }];
}

- (IBAction)clearDefaultStoreWebsiteData:(id)sender
{
    [persistentDataStore() removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes] modifiedSince:[NSDate distantPast] completionHandler:^{
        NSLog(@"Did clear default store website data.");
    }];
}

@end
