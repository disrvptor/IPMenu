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
    static func getIFAddresses() -> [String: String] {
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
                        
                        //println(ifaddrsToString(ptr));
                        
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
        var rtm: UnsafeMutablePointer<rt_msghdr> = nil;
        var cp: UnsafeMutablePointer<Void> = nil;

        let buffer_length = sizeof(rt_msghdr)+512;
        let buffer = UnsafeMutablePointer<UInt8>.alloc(buffer_length);

        // Use sockaddr_storage because it's large enough for whatever
        let so_dst = UnsafeMutablePointer<sockaddr_storage>.alloc(1);
        let so_gate = UnsafeMutablePointer<sockaddr_storage>.alloc(1);
        let so_mask = UnsafeMutablePointer<sockaddr_storage>.alloc(1);
        let so_genmask = UnsafeMutablePointer<sockaddr_storage>.alloc(1);
        let so_ifp = UnsafeMutablePointer<sockaddr_storage>.alloc(1);
        let so_ifa = UnsafeMutablePointer<sockaddr_storage>.alloc(1);
        
        let so_dst_sa: UnsafeMutablePointer<sockaddr> = unsafeBitCast(so_dst, UnsafeMutablePointer<sockaddr>.self);
        let so_gate_sa: UnsafeMutablePointer<sockaddr> = unsafeBitCast(so_gate, UnsafeMutablePointer<sockaddr>.self);
        let so_mask_sa: UnsafeMutablePointer<sockaddr> = unsafeBitCast(so_mask, UnsafeMutablePointer<sockaddr>.self);
        let so_genmask_sa: UnsafeMutablePointer<sockaddr> = unsafeBitCast(so_genmask, UnsafeMutablePointer<sockaddr>.self);
        let so_ifp_sa: UnsafeMutablePointer<sockaddr_dl> = unsafeBitCast(so_ifp, UnsafeMutablePointer<sockaddr_dl>.self);
        let so_ifa_sa: UnsafeMutablePointer<sockaddr> = unsafeBitCast(so_ifa, UnsafeMutablePointer<sockaddr>.self);
        
        bzero(buffer, buffer_length);
        
        cp = unsafeBitCast(buffer.advancedBy(sizeof(rt_msghdr)), UnsafeMutablePointer<Void>.self);
        rtm = unsafeBitCast(buffer, UnsafeMutablePointer<rt_msghdr>.self);

        so_dst_sa.memory.sa_family = sa_family_t(AF_INET);
        so_dst_sa.memory.sa_len = __uint8_t(sizeof(sockaddr_in));
        so_ifp_sa.memory.sdl_family = sa_family_t(AF_LINK);
        so_ifp_sa.memory.sdl_len = __uint8_t(sizeof(sockaddr_dl));
//        dest.withCString { cstr in
//            link_addr(cstr, so_ifp_sa);
//        }

        rtm.memory.rtm_type = u_char(RTM_GET);
        rtm.memory.rtm_flags = 2051;                    // 0x803 = RTF_UP|RTF_GATEWAY|RTF_STATIC
        rtm.memory.rtm_version = u_char(RTM_VERSION);
        rtm.memory.rtm_seq = ++seq;
        rtm.memory.rtm_addrs = 21;                      // 0x15 = RTA_DST|RTA_NETMASK|RTA_IFP
        rtm.memory.rtm_rmx = rt_metrics();
        rtm.memory.rtm_inits = 0;
        rtm.memory.rtm_index = 0;

        var index = sizeof(rt_msghdr);
        var index_n = 0;
        
        index_n = NEXTADDR(Int(RTA_DST), u: so_dst_sa, rtm_addrs: Int(rtm.memory.rtm_addrs), cp: cp);
        cp = cp.advancedBy(index_n);
        index += index_n;

        index_n = NEXTADDR(Int(RTA_GATEWAY), u: so_gate_sa, rtm_addrs: Int(rtm.memory.rtm_addrs), cp: cp);
        cp = cp.advancedBy(index_n);
        index += index_n;

        index_n = NEXTADDR(Int(RTA_NETMASK), u: so_mask_sa, rtm_addrs: Int(rtm.memory.rtm_addrs), cp: cp);
        cp = cp.advancedBy(index_n);
        index += index_n;
        
        index_n = NEXTADDR(Int(RTA_GENMASK), u: so_genmask_sa, rtm_addrs: Int(rtm.memory.rtm_addrs), cp: cp);
        cp = cp.advancedBy(index_n);
        index += index_n;

        index_n = NEXTADDR_dl(Int(RTA_IFP), u: so_ifp_sa, rtm_addrs: Int(rtm.memory.rtm_addrs), cp: cp);
        cp = cp.advancedBy(index_n);
        index += index_n;
        
        index_n = NEXTADDR(Int(RTA_IFA), u: so_ifa_sa, rtm_addrs: Int(rtm.memory.rtm_addrs), cp: cp);
        cp = cp.advancedBy(index_n);
        index += index_n;

        rtm.memory.rtm_msglen = u_short(index);

        let rlen = write(s, buffer, index);
        if (rlen < 0) {
            print("[WARNING] writing to routing socket");
        }

        var l = 0;
        repeat {
            l = read(s, buffer, buffer_length);
        } while (l > 0 && (rtm.memory.rtm_seq != seq || rtm.memory.rtm_pid != pid));
        if (l < 0) {
            print("[WARNING] read from routing socket");
        } else {
            // Check version
            if ( rtm.memory.rtm_version != u_char(RTM_VERSION) ) {
                print("Version mismatch");
            }

            // Check message length
            if ( rtm.memory.rtm_msglen != u_short(l) ) {
                print("Message length mismatch");
            }

            // Check for errors
            if ( rtm.memory.rtm_errno > 0 ) {
                print("Message indicates error \(rtm.memory.rtm_errno)");
            }

            // Scan through the addrs looking for an RTA_IFP message
            if ( rtm.memory.rtm_addrs > 0 ) {
                var sa_tmp = buffer.advancedBy(sizeof(rt_msghdr));
                var sa: UnsafePointer<sockaddr> = nil;

                var sa_tab = [Int32 : UnsafePointer<sockaddr>]();

                for ( var i:Int32 = 0; i < RTAX_MAX; i++ ) {
                    if ( (rtm.memory.rtm_addrs & (1 << i)) != 0 ) {
                        sa = unsafeBitCast(sa_tmp, UnsafePointer<sockaddr>.self);
                        sa_tab[1 << i] = sa;
                        sa_tmp = sa_tmp.advancedBy(ROUNDUP(Int(sa.memory.sa_len)));
                    } else {
                        sa_tab[1 << i] = nil;
                    }
                }

                if ( nil != sa_tab[RTA_IFP] ) {
                    // Finally!
                    let ifp = unsafeBitCast(sa_tab[RTA_IFP]!, UnsafeMutablePointer<sockaddr_dl>.self);

                    // Create a buffer that can hold all the characters and a null-termination character
                    let ll = Int(ifp.memory.sdl_nlen)+1;
                    let sdl_data = UnsafeMutablePointer<CChar>.alloc(ll);

                    // Save the characters in sdl_data
                    memcpy(sdl_data, &ifp.memory.sdl_data, ll);
                    // Null-terminate the C-string
                    sdl_data[ll-1] = 0;

                    defaultIF = String.fromCString(sdl_data)!;

                    sdl_data.destroy(ll);
                }
            }
        }

        // Cleanup
        so_dst.destroy(1);
        so_gate.destroy(1);
        so_mask.destroy(1);
        so_genmask.destroy(1);
        so_ifp.destroy(1);
        so_ifa.destroy(1);

        buffer.destroy(buffer_length);

        return defaultIF;
    }

    // Utility method for debugging
    static private func rtaConstant(c:Int32) -> String {
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
    static private func afConstant(c:Int32) -> String {
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
    static private func ROUNDUP(a:Int) -> Int {
        return ((a) > 0 ? (1 + (((a) - 1) | (sizeof(__uint32_t) - Int(1)))) : sizeof(__uint32_t));
    }

    // Utility method from route.c
    static private func NEXTADDR(w: Int, u: UnsafePointer<sockaddr>, rtm_addrs: Int, cp: UnsafeMutablePointer<Void>) -> Int {
        if ((rtm_addrs & w) != 0) {
            let l = ROUNDUP(Int(u.memory.sa_len));
            bcopy(u, cp, Int(l));
            return l;
        }
        return 0;
    }

    // Utility method from route.c
    static private func NEXTADDR_dl(w: Int, u: UnsafePointer<sockaddr_dl>, rtm_addrs: Int, cp: UnsafeMutablePointer<Void>) -> Int {
        if ((rtm_addrs & w) != 0) {
            let l = ROUNDUP(Int(u.memory.sdl_len));
            bcopy(u, cp, Int(l)); //cp += l;
            return l;
        }
        return 0;
    }
    

    // Utility method for debugging pointers
    static private func memDump<T>(var v: T, let length:Int = 0, sep:Int = 8, wrap:Int = 2) {
        memDumpPtr(&v, length: length, sep: sep, wrap: wrap);
    }

    // Utility method for debugging pointers
    static private func memDumpPtr<T>(let ptr: UnsafePointer<T>, var length:Int = 0, sep:Int = 8, wrap:Int = 2) {
        if ( 0 == length ) {
            length = sizeof(T);
        }
        let buf = UnsafeBufferPointer(start: UnsafePointer<UInt8>(ptr), count: length)
        for i in 0 ..< buf.count {
            if i != 0 && i % (sep * wrap) == 0 {
                print("\n", terminator:"")
            }
            print(String(format: "%02x ", buf[i]), terminator:"")
            if i % sep == 7 {
                print(" ", terminator:"")
            }
        }

        print("\n")
    }

}

