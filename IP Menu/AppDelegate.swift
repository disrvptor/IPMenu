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
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        //print("mbtest: launch\n");
        //self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        //statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength);
        // TODO: There is a linker error that doesn't resolve NSVariableStatusItemLength
        // http://stackoverflow.com/questions/24024723/swift-using-nsstatusbar-statusitemwithlength-and-nsvariablestatusitemlength
        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1);
        
        //print("mbtest: setting default title\n");
        //_statusItem.image = [NSImage imageNamed:@"switchIcon.png"];
        //statusItem!.title = "127.0.0.1";
        updateIPAddress();

        //print("mbtest: initializing update timer\n");
        timer = NSTimer.scheduledTimerWithTimeInterval(1.5, target: self, selector: "updateIPAddress", userInfo: nil, repeats: true);
        timer!.tolerance = 0.5;
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        //print("mbtest: terminate\n");
        timer = nil;
        NSStatusBar.systemStatusBar().removeStatusItem(statusItem!);
        //statusItem?.menu = nil;
        //statusItem?.title = nil;
        statusItem = nil;
    }
    
    func updateIPAddress() {
        //print("mbtest: update\n");
        let addresses = getIFAddresses();
        let menu = NSMenu();

        if ( nil == addresses["en0"] ) {
            statusItem!.title = "127.0.0.1";
        } else {
            statusItem!.title = addresses["en0"];//getWiFiAddress();//NSHost.currentHost().address;
        }

        if ( addresses.count > 0 ) {
            var index: Int = 1;
            for (name,address) in Array(addresses).sorted({$0.0 < $1.0}) {
                //print("\t\(name): \(address)\n");
                menu.addItem(NSMenuItem(title: "\(name): \(address)\n", action: Selector(), keyEquivalent: ""));
                index++;
            }
            menu.addItem(NSMenuItem.separatorItem());
        }

        var state: Int = 0;
        if ( applicationIsInStartUpItems() ) {
            state = 1;
        }

        var item:NSMenuItem = NSMenuItem(title: "Launch at startup", action: Selector("toggleLaunchAtStartup"), keyEquivalent: "");
        item.state = state;
        menu.addItem(item);

        menu.addItem(NSMenuItem(title: "About IP Menu", action: Selector("about"), keyEquivalent: ""));
        menu.addItem(NSMenuItem.separatorItem());
        menu.addItem(NSMenuItem(title: "Quit IP Menu", action: Selector("terminate:"), keyEquivalent: "q"));
        statusItem!.menu = menu;

        //print("\n");
        /*
        for address in NSHost.currentHost().addresses {
            //print("\(_stdlib_getTypeName(address)): \(address)\n");
            print("\(toString(address)): \(address)\n");
        }
        */
    }

    func about() {
        if let checkURL = NSURL(string: "http://www.disrvptor.com") {
            NSWorkspace.sharedWorkspace().openURL(checkURL);
        }
    }

    // http://stackoverflow.com/questions/28084853/how-to-get-the-local-host-ip-address-on-iphone-in-swift
    func getIFAddresses() -> [String: String] {
        var addresses = [String: String]()
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs> = nil
        if getifaddrs(&ifaddr) == 0 {
            
            // For each interface ...
            for (var ptr = ifaddr; ptr != nil; ptr = ptr.memory.ifa_next) {
                let flags = Int32(ptr.memory.ifa_flags)
                var addr = ptr.memory.ifa_addr.memory
                let name = String.fromCString(ptr.memory.ifa_name);
                
                // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                        
                        // Convert interface address to a human readable string:
                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                                if let address = String.fromCString(hostname) {
                                    //addresses.append(address);
                                    addresses[name!] = address;
                                }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return addresses
    }

//    // Return IP address of WiFi interface (en0) as a String, or `nil`
//    func getWiFiAddress() -> String? {
//        var address : String?
//        
//        // Get list of all interfaces on the local machine:
//        var ifaddr : UnsafeMutablePointer<ifaddrs> = nil
//        if getifaddrs(&ifaddr) == 0 {
//            
//            // For each interface ...
//            for (var ptr = ifaddr; ptr != nil; ptr = ptr.memory.ifa_next) {
//                let interface = ptr.memory
//                
//                // Check for IPv4 or IPv6 interface:
//                let addrFamily = interface.ifa_addr.memory.sa_family
//                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
//                    
//                    // Check interface name:
//                    if let name = String.fromCString(interface.ifa_name) where name == "en0" {
//                        
//                        // Convert interface address to a human readable string:
//                        var addr = interface.ifa_addr.memory
//                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
//                        getnameinfo(&addr, socklen_t(interface.ifa_addr.memory.sa_len),
//                            &hostname, socklen_t(hostname.count),
//                            nil, socklen_t(0), NI_NUMERICHOST)
//                        address = String.fromCString(hostname)
//                    }
//                }
//            }
//            freeifaddrs(ifaddr)
//        }
//        
//        return address
//    }

    // http://stackoverflow.com/questions/26475008/swift-getting-a-mac-app-to-launch-on-startup
    func applicationIsInStartUpItems() -> Bool {
        return (itemReferencesInLoginItems().existingReference != nil)
    }
    
    func itemReferencesInLoginItems() -> (existingReference: LSSharedFileListItemRef?, lastReference: LSSharedFileListItemRef?) {
//        var itemUrl : UnsafeMutablePointer<Unmanaged<CFURL>?> = UnsafeMutablePointer<Unmanaged<CFURL>?>.alloc(1)
        if let appUrl : NSURL = NSURL.fileURLWithPath(NSBundle.mainBundle().bundlePath) {
            let loginItemsRef = LSSharedFileListCreate(
                nil,
                kLSSharedFileListSessionLoginItems.takeRetainedValue(),
                nil
                ).takeRetainedValue() as LSSharedFileListRef?
            if loginItemsRef != nil {
                let loginItems: NSArray = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
                println("There are \(loginItems.count) login items")
                let lastItemRef: LSSharedFileListItemRef = loginItems.lastObject as! LSSharedFileListItemRef
                for var i = 0; i < loginItems.count; ++i {
                    let currentItemRef: LSSharedFileListItemRef = loginItems.objectAtIndex(i) as! LSSharedFileListItemRef
                    //if LSSharedFileListItemResolve(currentItemRef, 0, itemUrl, nil) == noErr {
                        //if let urlRef: NSURL =  itemUrl.memory?.takeRetainedValue() {
                    if let urlRef: Unmanaged<CFURL> = LSSharedFileListItemCopyResolvedURL(currentItemRef, 0, nil) {
                        let urlRef:NSURL = urlRef.takeRetainedValue();
                            println("URL Ref: \(urlRef)")
                            println("URL Ref: \(appUrl)")
                            if urlRef.isEqual(appUrl) {
                                return (currentItemRef, lastItemRef)
                            }
                        //}                    } else {
                        println("Unknown login application")
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
                    println("Application was added to login items")
                }
            } else {
                if let itemRef = itemReferences.existingReference {
                    LSSharedFileListItemRemove(loginItemsRef,itemRef);
                    println("Application was removed from login items")
                }
            }
        }
    }

}

