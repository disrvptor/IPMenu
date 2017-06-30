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
    
    internal var timer: Timer?;

    internal var addresses: [String:[sa_family_t:[String]]]?;
    internal var defaultIF: String?;

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength);

        // TODO: Figure out ho to modify this for dev/test vs production
        ConsoleLog.setCurrentLevel(ConsoleLog.Level.Info);

        updateIPAddress();

        timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(AppDelegate.updateIPAddress), userInfo: nil, repeats: true);
        timer!.tolerance = 0.5;
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        timer = nil;
        NSStatusBar.system().removeStatusItem(statusItem!);
        statusItem = nil;
    }

    func updateIPAddress() {
        let _addresses = NetworkUtils.getIFAddresses();
        // Disable this for now because it looks like it may be causing the OS to deadlock
        //var _defaultIF: String? = "en0";
        var _defaultIF: String? = NetworkUtils.getDefaultGatewayInterface();
        //var _defaultIF: String? = NetworkUtils.getDefaultGatewayInterfaceShell();

        let equal = compareAddresses(self.addresses, newA: _addresses);

        if ( !equal ) {
            ConsoleLog.info("Detected new addresses \(String(describing: addresses)) -> \(_addresses)");

            addresses = _addresses;

            // Regenerate menu
            let menu = NSMenu();
            if ( addresses!.count > 0 ) {
                var index: Int = 1;
                for (name,protoMap) in Array(addresses!).sorted(by: {$0.0 < $1.0}) {
                    for (_,addressArray) in protoMap {
                        for address in addressArray {
                            menu.addItem(NSMenuItem(title: "\(name): \(address)\n", action: nil, keyEquivalent: ""));
                            index += 1;
                        }
                    }
                }
                menu.addItem(NSMenuItem.separator());
            }

            var state: Int = 0;
            if ( applicationIsInStartUpItems() ) {
                state = 1;
            }

            menu.addItem(NSMenuItem(title: "Refresh", action: #selector(AppDelegate.updateIPAddress), keyEquivalent: ""));

            let item:NSMenuItem = NSMenuItem(title: "Launch at startup", action: #selector(AppDelegate.toggleLaunchAtStartup), keyEquivalent: "");
            item.state = state;
            menu.addItem(item);

            menu.addItem(NSMenuItem(title: "About IP Menu", action: #selector(AppDelegate.about), keyEquivalent: ""));
            menu.addItem(NSMenuItem.separator());
            //menu.addItem(NSMenuItem(title: "Quit IP Menu", action: #selector(NSInputServiceProvider.Quit), keyEquivalent: "q"));
            menu.addItem(NSMenuItem(title: "Quit IP Menu", action: #selector(NSApplication.shared().terminate), keyEquivalent: "q"));
            statusItem!.menu = menu;
        }

        if ( nil == _defaultIF ) {
            _defaultIF = "en0";
        }

        // Debug
        if ( nil == defaultIF || ComparisonResult.orderedSame != _defaultIF!.compare(defaultIF!) ) {
            ConsoleLog.info("Detected new default interface (\(String(describing: defaultIF)) -> \(String(describing: _defaultIF)))");
        }

        // Pick the default address as the title
        var addr = "127.0.0.1"
        if ( nil == defaultIF || ComparisonResult.orderedSame != _defaultIF!.compare(defaultIF!) || !equal ) {
            defaultIF = _defaultIF;

            if ( nil != addresses && nil != addresses![defaultIF!] ) {
                // Prefer ipv4 over ipv6
                let defaultProtoMap = addresses![defaultIF!];
                let ipv4 = defaultProtoMap![UInt8(AF_INET)];
                let ipv6 = defaultProtoMap![UInt8(AF_INET6)];
                if ( nil != ipv4 && ipv4!.count > 0 ) {
                    addr = ipv4![0];
                } else if ( nil != ipv6 && ipv6!.count > 0 ) {
                    addr = ipv6![0];
                } else {
                    print("No ipv4 or ipv6 addresses detected");
                    addr = "127.0.0.1";
                }
            }
            statusItem!.title = addr;
        } else {
            print("No Changes \(String(describing: defaultIF)), \(String(describing: _defaultIF)), \(equal)");
        }
    }

    func compareAddresses(_ oldA:[String:[sa_family_t:[String]]]?, newA:[String:[sa_family_t:[String]]]) -> Bool {
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
                            if ( ComparisonResult.orderedSame == newAddr.compare(oldAddr) ) {
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
        let alert = NSAlert();
        alert.messageText = "IP Menu v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)";
        alert.informativeText = "Developed by @disrvptor (https://github.com/disrvptor/IPMenu)";
        alert.alertStyle = .informational;
        alert.runModal();
    }

    // http://stackoverflow.com/questions/26475008/swift-getting-a-mac-app-to-launch-on-startup
    func applicationIsInStartUpItems() -> Bool {
        return (itemReferencesInLoginItems().existingReference != nil)
    }

    func itemReferencesInLoginItems() -> (existingReference: LSSharedFileListItem?, lastReference: LSSharedFileListItem?) {
        let appUrl : URL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
            ).takeRetainedValue() as LSSharedFileList?
        if loginItemsRef != nil {
            let loginItems: NSArray = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
            if ( loginItems.count > 0 ) {
                let lastItemRef: LSSharedFileListItem = loginItems.lastObject as! LSSharedFileListItem
                for i in 0 ..< loginItems.count {
                    let currentItemRef: LSSharedFileListItem = loginItems.object(at: i) as! LSSharedFileListItem
                    if let urlRef: Unmanaged<CFURL> = LSSharedFileListItemCopyResolvedURL(currentItemRef, 0, nil) {
                        let urlRef:URL = urlRef.takeRetainedValue() as URL;
                        if urlRef == appUrl {
                            return (currentItemRef, lastItemRef)
                        }
                    } else {
                        print("Unknown login application");
                    }
                }
                //The application was not found in the startup list
                return (nil, lastItemRef)
            } else {
                let addatstart: LSSharedFileListItem = kLSSharedFileListItemBeforeFirst.takeRetainedValue()
                return(nil,addatstart)
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
            ).takeRetainedValue() as LSSharedFileList?
        if loginItemsRef != nil {
            if shouldBeToggled {
                let appUrl = URL(fileURLWithPath: Bundle.main.bundlePath) as CFURL?;
                if (nil != appUrl) {
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

