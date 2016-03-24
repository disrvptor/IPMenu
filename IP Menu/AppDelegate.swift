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
    //internal var darkModeOn: Bool = false;
    
    internal var timer: NSTimer?;

    internal var addresses: [String:[sa_family_t:[String]]]?;
    internal var defaultIF: String?;

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength);

        // TODO: Figure out ho to modify this for dev/test vs production
        ConsoleLog.setCurrentLevel(ConsoleLog.Level.Debug);

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
        // Disable this for now because it looks like it may be causing the OS to deadlock
        //var _defaultIF: String? = "en0"; //NetworkUtils.getDefaultGatewayInterface();
        var _defaultIF: String? = NetworkUtils.getDefaultGatewayInterfaceShell();

        let equal = compareAddresses(self.addresses, newA: _addresses);

        if ( !equal ) {
            ConsoleLog.debug("Detected new addresses \(addresses) -> \(_addresses)");

            addresses = _addresses;

            // Regenerate menu
            let menu = NSMenu();
            if ( addresses!.count > 0 ) {
                var index: Int = 1;
                for (name,protoMap) in Array(addresses!).sort({$0.0 < $1.0}) {
                    for (_,addressArray) in protoMap {
                        for address in addressArray {
                            menu.addItem(NSMenuItem(title: "\(name): \(address)\n", action: Selector(), keyEquivalent: ""));
                            index++;
                        }
                    }
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

        // Debug
        if ( nil == defaultIF || NSComparisonResult.OrderedSame != _defaultIF!.compare(defaultIF!) ) {
            ConsoleLog.debug("Detected new default interface (\(defaultIF) -> \(_defaultIF))");
        }

        // Pick the default address as the title
        var addr = "127.0.0.1"
        if ( nil == defaultIF || NSComparisonResult.OrderedSame != _defaultIF!.compare(defaultIF!) || !equal ) {
            defaultIF = _defaultIF;

            if ( nil != addresses && nil != addresses![defaultIF!] ) {
                // Prefer ipv4 over ipv6
                let defaultProtoMap = addresses![defaultIF!];
                let ipv4 = defaultProtoMap![UInt8(AF_INET)];
                let ipv6 = defaultProtoMap![UInt8(AF_INET6)];
                if ( nil != ipv4 && ipv4?.count > 0 ) {
                    addr = ipv4![0];
                } else if ( nil != ipv6 && ipv6?.count > 0 ) {
                    addr = ipv6![0];
                }
            }
        }
        statusItem!.title = addr;
    }

    func compareAddresses(oldA:[String:[sa_family_t:[String]]]?, newA:[String:[sa_family_t:[String]]]) -> Bool {
        if ( nil == oldA || newA.count != oldA!.count ) {
            return false;
        } else {
            // count is equal, but contents may be different, so
            // iterate over the new addresses
            for (name,newProtoMap) in newA {
                
                // Check to see if this interface is previously seen
                guard let oldProtoMap = oldA![name] else {
                    return false;
                }
                
                for (newProto,newAddresses) in newProtoMap {
                    guard let oldAddresses = oldProtoMap[newProto] else {
                        return false;
                    }
                    
                    // Check the actual addresses
                    var found = false;
                    for newAddr in newAddresses {
                        for oldAddr in oldAddresses {
                            // Now check if there are the same addresses as previous
                            if ( NSComparisonResult.OrderedSame == newAddr.compare(oldAddr) ) {
                                found = true;
                                break;
                            }
                        }
                        if ( !found ) {
                            return false;
                        }
                    }
                }
            }
        }

        return true;
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
                if ( loginItems.count > 0 ) {
                    let lastItemRef: LSSharedFileListItemRef = loginItems.lastObject as! LSSharedFileListItemRef
                    for var i = 0; i < loginItems.count; ++i {
                        let currentItemRef: LSSharedFileListItemRef = loginItems.objectAtIndex(i) as! LSSharedFileListItemRef
                        if let urlRef: Unmanaged<CFURL> = LSSharedFileListItemCopyResolvedURL(currentItemRef, 0, nil) {
                            let urlRef:NSURL = urlRef.takeRetainedValue();
                            if urlRef.isEqual(appUrl) {
                                return (currentItemRef, lastItemRef)
                            }
                        } else {
                            print("Unknown login application");
                        }
                    }
                    //The application was not found in the startup list
                    return (nil, lastItemRef)
                } else {
                    let addatstart: LSSharedFileListItemRef = kLSSharedFileListItemBeforeFirst.takeRetainedValue()
                    return(nil,addatstart)
                }
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

