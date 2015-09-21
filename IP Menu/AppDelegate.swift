//
//  AppDelegate.swift
//  IP Menu
//
//  Created by Guy Pascarella on 9/2/15.
//
//

import Cocoa
import AppKit
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    //@IBOutlet weak var window: NSWindow!
    
    // https://nsrover.wordpress.com/2014/10/10/creating-a-os-x-menubar-only-app/
    
    //@property (strong, nonatomic) NSStatusItem *statusItem;
    internal var statusItem: NSStatusItem?;
    
    //@property (assign, nonatomic) BOOL darkModeOn;
    internal var darkModeOn: Bool = false;
    
    internal var timer: NSTimer?;

    internal var addresses: [String:String]?;
    internal var defaultIF: String?;

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength);

        updateIPAddress();

        timer = NSTimer.scheduledTimerWithTimeInterval(1.5, target: self, selector: "updateIPAddress", userInfo: nil, repeats: true);
        timer!.tolerance = 0.5;
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        timer = nil;
        NSStatusBar.systemStatusBar().removeStatusItem(statusItem!);
        statusItem = nil;
    }
    
    func updateIPAddress() {
        let _addresses = NetworkUtils.getIFAddresses();
        var _defaultIF = NetworkUtils.getDefaultGatewayInterface();

        var equal:Bool = true;

        // Compare addresses
        if ( nil == addresses || _addresses.count != addresses!.count ) {
            equal = false;
        } else {
            // count is equal, but contents may be different
            for (name,address) in _addresses {
                let addr = addresses![name];
                // Note: IPv6 addresses on utun0 keep on regenerating their lower half...need to figure out why
                if ( NSComparisonResult.OrderedSame != address.compare(addr!) ) {
                    equal = false;
                    break;
                }
            }
        }

        if ( !equal ) {
            addresses = _addresses;

            print("Detected new addresses... Regenerating menu");

            // Regenerate menu
            let menu = NSMenu();
            if ( addresses!.count > 0 ) {
                var index: Int = 1;
                for (name,address) in Array(addresses!).sort({$0.0 < $1.0}) {
                    menu.addItem(NSMenuItem(title: "\(name): \(address)\n", action: Selector(), keyEquivalent: ""));
                    index++;
                }
                menu.addItem(NSMenuItem.separatorItem());
            }

            var state: Int = 0;
            if ( applicationIsInStartUpItems() ) {
                state = 1;
            }

            let item:NSMenuItem = NSMenuItem(title: "Launch at startup", action: Selector("toggleLaunchAtStartup"), keyEquivalent: "");
            item.state = state;
            menu.addItem(item);

            menu.addItem(NSMenuItem(title: "About IP Menu", action: Selector("about"), keyEquivalent: ""));
            menu.addItem(NSMenuItem.separatorItem());
            menu.addItem(NSMenuItem(title: "Quit IP Menu", action: Selector("terminate:"), keyEquivalent: "q"));
            statusItem!.menu = menu;
        }

        if ( nil == _defaultIF ) {
            _defaultIF = "en0";
        }

        if ( nil == defaultIF || NSComparisonResult.OrderedSame != _defaultIF!.compare(defaultIF!) || !equal ) {
            defaultIF = _defaultIF;

            print("Detected new default interface or addresses... Regenerating menu title");

            if ( nil == addresses || nil == addresses![defaultIF!] ) {
                statusItem!.title = "127.0.0.1";
            } else {
                statusItem!.title = addresses![defaultIF!];
            }
        }

    }

    func about() {
        if let checkURL = NSURL(string: "http://www.disrvptor.com") {
            NSWorkspace.sharedWorkspace().openURL(checkURL);
        }
    }

    // http://stackoverflow.com/questions/26475008/swift-getting-a-mac-app-to-launch-on-startup
    func applicationIsInStartUpItems() -> Bool {
        return (itemReferencesInLoginItems().existingReference != nil)
    }
    
    func itemReferencesInLoginItems() -> (existingReference: LSSharedFileListItemRef?, lastReference: LSSharedFileListItemRef?) {
        if let appUrl : NSURL = NSURL.fileURLWithPath(NSBundle.mainBundle().bundlePath) {
            let loginItemsRef = LSSharedFileListCreate(
                nil,
                kLSSharedFileListSessionLoginItems.takeRetainedValue(),
                nil
                ).takeRetainedValue() as LSSharedFileListRef?
            if loginItemsRef != nil {
                let loginItems: NSArray = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
                let lastItemRef: LSSharedFileListItemRef = loginItems.lastObject as! LSSharedFileListItemRef
                for var i = 0; i < loginItems.count; ++i {
                    let currentItemRef: LSSharedFileListItemRef = loginItems.objectAtIndex(i) as! LSSharedFileListItemRef
                    if let urlRef: Unmanaged<CFURL> = LSSharedFileListItemCopyResolvedURL(currentItemRef, 0, nil) {
                        let urlRef:NSURL = urlRef.takeRetainedValue();
                        if urlRef.isEqual(appUrl) {
                            return (currentItemRef, lastItemRef)
                        }
                    }
                }
                //The application was not found in the startup list
                return (nil, lastItemRef)
            }
        }
        return (nil, nil)
    }

    func toggleLaunchAtStartup() {
        let itemReferences = itemReferencesInLoginItems()
        let shouldBeToggled = (itemReferences.existingReference == nil)
        let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
            ).takeRetainedValue() as LSSharedFileListRef?
        if loginItemsRef != nil {
            if shouldBeToggled {
                if let appUrl : CFURLRef = NSURL.fileURLWithPath(NSBundle.mainBundle().bundlePath) {
                    LSSharedFileListInsertItemURL(
                        loginItemsRef,
                        itemReferences.lastReference,
                        nil,
                        nil,
                        appUrl,
                        nil,
                        nil
                    )
                    print("Application was added to login items")
                }
            } else {
                if let itemRef = itemReferences.existingReference {
                    LSSharedFileListItemRemove(loginItemsRef,itemRef);
                    print("Application was removed from login items")
                }
            }
        }
    }

}

