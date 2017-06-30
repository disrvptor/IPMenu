//
//  NetworkUtils.swift
//  IP Menu
//
//  Created by Guy Pascarella on 9/16/15.
//
//

import Foundation

class NetworkUtils {

    // http://stackoverflow.com/questions/28084853/how-to-get-the-local-host-ip-address-on-iphone-in-swift
    static func getIFAddresses() -> [String: [sa_family_t: [String]]] {
        var addresses = [String: [sa_family_t: [String]]]();

        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {

            // For each interface ...
            var ptr = ifaddr;
            while ( ptr != nil ) {
            //for (var ptr = ifaddr; ptr != nil; ptr = ptr?.pointee.ifa_next) {
                let flags = Int32((ptr?.pointee.ifa_flags)!)
                var addr = ptr?.pointee.ifa_addr.pointee
                let name = String(cString: (ptr?.pointee.ifa_name)!);

                // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr?.sa_family == UInt8(AF_INET) || addr?.sa_family == UInt8(AF_INET6) {

                        // Convert interface address to a human readable string:
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if (getnameinfo(&addr!, socklen_t((addr?.sa_len)!), &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                                guard let address = String(validatingUTF8: hostname) else {
                                    continue;
                                }

                                // Note: If there are multiple addresses (eg ipv4 and ipv6)
                                // associated with the same interface then whatever the last
                                // one in is wins.
                                ConsoleLog.debug("Saving \(name) with \(address) and flags \(flags)");

                                if ( nil == addresses[name] ) {
                                    addresses[name] = [sa_family_t:[String]]();
                                }

                                if ( nil == addresses[name]![(addr?.sa_family)!] ) {
                                    addresses[name]![(addr?.sa_family)!] = [String]();
                                }
                                addresses[name]![(addr?.sa_family)!]?.append(address);
                        }
                    }
                }
                ptr = ptr?.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }

        return addresses
    }

    // Retrieve the default interface name that requests are routed through
    // using shell commands, which are more stable than converted code
    // For example, "en0" or "utun0"
    static func getDefaultGatewayInterfaceShell() -> String? {
        // http://practicalswift.com/2014/06/25/how-to-execute-shell-commands-from-swift/
        let task = Process()
        task.launchPath = "/sbin/route"
        task.arguments = ["get", "0.0.0.0"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue)

        // Scan output for "^\s*interface:\s+(ifX)\s*$"
        let lines = output?.components(separatedBy: "\n");
        for line in lines! {
            //let line2 = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet());
            if let range = line.range(of: "interface: ") {
                return line.substring(from: range.upperBound);
            }
        }

        return nil;
    }

    // Retrieve the default interface name that requests are routed through
    // For example, "en0" or "utun0"
    static func getDefaultGatewayInterface() -> String? {
        let s = socket(PF_ROUTE, SOCK_RAW, 0);
        if ( s < 0 ) {
            print("An error occurred creating a socket");
        }

        // TODO: Don't assume default == "0.0.0.0"
        //var dest = "0.0.0.0";

        var defaultIF = "";

        let pid = getpid();
        var seq: Int32 = 0;
        var rtm: UnsafeMutablePointer<rt_msghdr>? = nil;
        var cp: UnsafeMutableRawPointer? = nil;

        let buffer_length = MemoryLayout<rt_msghdr>.size+512;
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: buffer_length);

        // Use sockaddr_storage because it's large enough for whatever
        let so_dst = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1);
        let so_gate = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1);
        let so_mask = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1);
        let so_genmask = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1);
        let so_ifp = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1);
        let so_ifa = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1);

//        let so_dst_sa = unsafeDowncast(so_dst as AnyObject, to: UnsafeMutablePointer<sockaddr>); // = unsafeBitCast(so_dst, to: UnsafeMutablePointer<sockaddr>.self);
//        let so_gate_sa: UnsafeMutablePointer<sockaddr> = unsafeBitCast(so_gate, to: UnsafeMutablePointer<sockaddr>.self);
//        let so_mask_sa: UnsafeMutablePointer<sockaddr> = unsafeBitCast(so_mask, to: UnsafeMutablePointer<sockaddr>.self);
//        let so_genmask_sa: UnsafeMutablePointer<sockaddr> = unsafeBitCast(so_genmask, to: UnsafeMutablePointer<sockaddr>.self);
//        let so_ifp_sa: UnsafeMutablePointer<sockaddr_dl> = unsafeBitCast(so_ifp, to: UnsafeMutablePointer<sockaddr_dl>.self);
//        let so_ifa_sa: UnsafeMutablePointer<sockaddr> = unsafeBitCast(so_ifa, to: UnsafeMutablePointer<sockaddr>.self);
        
        bzero(buffer, buffer_length);
        
        cp = UnsafeMutableRawPointer(buffer.advanced(by: MemoryLayout<rt_msghdr>.size));
        rtm = UnsafeMutableRawPointer(buffer).assumingMemoryBound(to: rt_msghdr.self);

        so_dst.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            $0.pointee.sa_family = sa_family_t(AF_INET);
            $0.pointee.sa_len = __uint8_t(MemoryLayout<sockaddr_in>.size);
        };
        so_ifp.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
            $0.pointee.sdl_family = sa_family_t(AF_LINK);
            $0.pointee.sdl_len = __uint8_t(MemoryLayout<sockaddr_dl>.size);
        };
//        dest.withCString { cstr in
//            link_addr(cstr, so_ifp_sa);
//        }

        rtm?.pointee.rtm_type = u_char(RTM_GET);
        rtm?.pointee.rtm_flags = 2051;                    // 0x803 = RTF_UP|RTF_GATEWAY|RTF_STATIC
        rtm?.pointee.rtm_version = u_char(RTM_VERSION);
        seq = seq+1;
        rtm?.pointee.rtm_seq = seq;
        rtm?.pointee.rtm_addrs = 21;                      // 0x15 = RTA_DST|RTA_NETMASK|RTA_IFP
        rtm?.pointee.rtm_rmx = rt_metrics();
        rtm?.pointee.rtm_inits = 0;
        rtm?.pointee.rtm_index = 0;

        var index = MemoryLayout<rt_msghdr>.size;
        var index_n = 0;

        so_dst.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            index_n = NEXTADDR(Int(RTA_DST), u: $0, rtm_addrs: Int((rtm?.pointee.rtm_addrs)!), cp: cp!);
        };
        cp = cp?.advanced(by: index_n);
        index += index_n;

        so_gate.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            index_n = NEXTADDR(Int(RTA_GATEWAY), u: $0, rtm_addrs: Int((rtm?.pointee.rtm_addrs)!), cp: cp!);
        };
        cp = cp?.advanced(by: index_n);
        index += index_n;

        so_mask.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            index_n = NEXTADDR(Int(RTA_NETMASK), u: $0, rtm_addrs: Int((rtm?.pointee.rtm_addrs)!), cp: cp!);
        };
        cp = cp?.advanced(by: index_n);
        index += index_n;
        
        so_genmask.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            index_n = NEXTADDR(Int(RTA_GENMASK), u: $0, rtm_addrs: Int((rtm?.pointee.rtm_addrs)!), cp: cp!);
        };
        cp = cp?.advanced(by: index_n);
        index += index_n;

        so_ifp.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
            index_n = NEXTADDR_dl(Int(RTA_IFP), u: $0, rtm_addrs: Int((rtm?.pointee.rtm_addrs)!), cp: cp!);
        };
        cp = cp?.advanced(by: index_n);
        index += index_n;
        
        so_ifa.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            index_n = NEXTADDR(Int(RTA_IFA), u: $0, rtm_addrs: Int((rtm?.pointee.rtm_addrs)!), cp: cp!);
        };
        cp = cp?.advanced(by: index_n);
        index += index_n;

        rtm?.pointee.rtm_msglen = u_short(index);

        let rlen = write(s, buffer, index);
        if (rlen < 0) {
            print("[WARNING] writing to routing socket");
        }

        var l = 0;
        repeat {
            l = read(s, buffer, buffer_length);
        } while (l > 0 && (rtm?.pointee.rtm_seq != seq || rtm?.pointee.rtm_pid != pid));
        if (l < 0) {
            print("[WARNING] read from routing socket");
        } else {
            // Check version
            if ( rtm?.pointee.rtm_version != u_char(RTM_VERSION) ) {
                print("Version mismatch");
            }

            // Check message length
            if ( rtm?.pointee.rtm_msglen != u_short(l) ) {
                print("Message length mismatch");
            }

            // Check for errors
            if ( (rtm?.pointee.rtm_errno)! > 0 ) {
                print("Message indicates error \(String(describing: rtm?.pointee.rtm_errno))");
            }

            // Scan through the addrs looking for an RTA_IFP message
            if ( (rtm?.pointee.rtm_addrs)! > 0 ) {
                var sa_tmp = buffer.advanced(by: MemoryLayout<rt_msghdr>.size);
                var sa: UnsafeMutablePointer<sockaddr>? = nil;

                var sa_tab = [Int32 : UnsafeMutablePointer<sockaddr>]();

                //var i : Int32;
                for i in 0 ..< RTAX_MAX {
                    if ( ((rtm?.pointee.rtm_addrs)! & (1 << i)) != 0 ) {
                        //sa = unsafeBitCast(sa_tmp, to: UnsafePointer<sockaddr>.self);
                        sa = UnsafeMutableRawPointer(sa_tmp).assumingMemoryBound(to: sockaddr.self);
                        sa_tab[1 << i] = sa;
                        sa_tmp = sa_tmp.advanced(by: ROUNDUP(Int(sa!.pointee.sa_len)));
                    } else {
                        sa_tab[1 << i] = nil;
                    }
                }

                if ( nil != sa_tab[RTA_IFP] ) {
                    // Finally!
                    //let ifp = unsafeBitCast(sa_tab[RTA_IFP]!, to: UnsafeMutablePointer<sockaddr_dl>.self);
                    let ifp = UnsafeMutableRawPointer(sa_tab[RTA_IFP]!).assumingMemoryBound(to: sockaddr_dl.self);

                    // Create a buffer that can hold all the characters and a null-termination character
                    let ll = Int(ifp.pointee.sdl_nlen)+1;
                    let sdl_data = UnsafeMutablePointer<CChar>.allocate(capacity: ll);

                    // Save the characters in sdl_data
                    memcpy(sdl_data, &ifp.pointee.sdl_data, ll);
                    // Null-terminate the C-string
                    sdl_data[ll-1] = 0;

                    defaultIF = String(cString: sdl_data);

                    sdl_data.deallocate(capacity: 11);
                }
            }
        }

        // Cleanup
        so_dst.deallocate(capacity: 1);
        so_gate.deallocate(capacity: 1);
        so_mask.deallocate(capacity: 1);
        so_genmask.deallocate(capacity: 1);
        so_ifp.deallocate(capacity: 1);
        so_ifa.deallocate(capacity: 1);

        buffer.deallocate(capacity: buffer_length);

        return defaultIF;
    }

    // Utility method for debugging
    static fileprivate func rtaConstant(_ c:Int32) -> String {
        switch(c) {
        case RTA_AUTHOR: return "RTA_AUTHOR";
        case RTA_BRD: return "RTA_BRD";
        case RTA_DST: return "RTA_DST";
        case RTA_GATEWAY: return "RTA_GATEWAY";
        case RTA_GENMASK: return "RTA_GENMASK";
        case RTA_IFA: return "RTA_IFA";
        case RTA_IFP: return "RTA_IFP";
        case RTA_NETMASK: return "RTA_NETMASK";
        default: return "unknown";
        }
    }

    // Utility method for debugging
    static fileprivate func afConstant(_ c:Int32) -> String {
        switch(c) {
        case AF_UNSPEC: return "AF_UNSPEC";
        case AF_UNIX: return "AF_UNIX";
        case AF_INET: return "AF_INET";
        case AF_INET6: return "AF_INET6";
        case AF_LINK: return "AF_LINK";
        case AF_SYSTEM: return "AF_SYSTEM";
        case AF_ROUTE: return "AF_ROUTE";
        default: return "unknown";
        }
    }

    // Utility method from route.c
    static fileprivate func ROUNDUP(_ a:Int) -> Int {
        return ((a) > 0 ? (1 + (((a) - 1) | (MemoryLayout<__uint32_t>.size - Int(1)))) : MemoryLayout<__uint32_t>.size);
    }

    // Utility method from route.c
    static fileprivate func NEXTADDR(_ w: Int, u: UnsafePointer<sockaddr>, rtm_addrs: Int, cp: UnsafeMutableRawPointer) -> Int {
        if ((rtm_addrs & w) != 0) {
            let l = ROUNDUP(Int(u.pointee.sa_len));
            bcopy(u, cp, Int(l));
            return l;
        }
        return 0;
    }

    // Utility method from route.c
    static fileprivate func NEXTADDR_dl(_ w: Int, u: UnsafePointer<sockaddr_dl>, rtm_addrs: Int, cp: UnsafeMutableRawPointer) -> Int {
        if ((rtm_addrs & w) != 0) {
            let l = ROUNDUP(Int(u.pointee.sdl_len));
            bcopy(u, cp, Int(l)); //cp += l;
            return l;
        }
        return 0;
    }
    

    // Utility method for debugging pointers
    static private func memDump<T>(_ v: T, length:Int = 0, sep:Int = 8, wrap:Int = 2) {
        var v = v
        memDumpPtr(&v, length: length, sep: sep, wrap: wrap);
    }

    // Utility method for debugging pointers
    static private func memDumpPtr<T>(_ ptr: UnsafePointer<T>, length:Int = 0, sep:Int = 8, wrap:Int = 2) {
        var length = length
        if ( 0 == length ) {
            length = MemoryLayout<T>.size;
        }
        // Swift 3 disabled this
        //let buf = UnsafeBufferPointer(start: UnsafePointer<UInt8>(ptr), count: length)
        ptr.withMemoryRebound(to: UInt8.self, capacity: length) {
            for i in 0 ..< length {
                if i != 0 && i % (sep * wrap) == 0 {
                    print("\n", terminator:"")
                }
                print(String(format: "%02x ", $0[i]), terminator:"")
                if i % sep == 7 {
                    print(" ", terminator:"")
                }
            }
        }

        print("\n")
    }

}

