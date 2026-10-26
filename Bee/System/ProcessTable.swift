import Darwin
import Foundation

/// Facts about the user's own running processes, read from the kernel.
enum ProcessTable {
    /// When `pid` started, or `nil` if no such process is running.
    static func startTime(of pid: pid_t) -> Date? {
        guard let info = kernelInfo(pid) else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000)
    }

    static func parent(of pid: pid_t) -> pid_t? {
        kernelInfo(pid).map(\.kp_eproc.e_ppid)
    }

    /// The bundle identifier of the app whose bundle holds `pid`'s executable, including helpers and
    /// CLIs that run the app's own binary.
    static func appBundleIdentifier(of pid: pid_t) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        guard let path = string(fromNulTerminated: buffer) else { return nil }
        var url = URL(filePath: path)
        while url.pathComponents.count > 1 {
            if url.pathExtension == "app" { return Bundle(url: url)?.bundleIdentifier }
            url.deleteLastPathComponent()
        }
        return nil
    }

    /// Every running process whose name is `name`.
    static func pids(named name: String) -> [pid_t] {
        let capacity = proc_listallpids(nil, 0) + 64
        guard capacity > 64 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(capacity))
        let count = proc_listallpids(&pids, capacity * Int32(MemoryLayout<pid_t>.size))
        return pids.prefix(Int(max(count, 0))).filter { pid in
            // `proc_name` fails outright on a buffer smaller than the kernel's 2 * MAXCOMLEN name field.
            var buffer = [UInt8](repeating: 0, count: 2 * Int(MAXCOMLEN) + 1)
            return proc_name(pid, &buffer, UInt32(buffer.count)) > 0 && string(fromNulTerminated: buffer) == name
        }
    }

    /// Paths of the regular files `pid` has open.
    static func openFiles(of pid: pid_t) -> [String] {
        let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard size > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(size) / stride)
        let used = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, size)
        return fds.prefix(Int(max(used, 0)) / stride)
            .filter { $0.proc_fdtype == UInt32(PROX_FDTYPE_VNODE) }
            .compactMap { path(ofFile: $0.proc_fd, in: pid) }
    }

    private static func path(ofFile fd: Int32, in pid: pid_t) -> String? {
        var info = vnode_fdinfowithpath()
        let size = Int32(MemoryLayout<vnode_fdinfowithpath>.stride)
        guard proc_pidfdinfo(pid, fd, PROC_PIDFDVNODEPATHINFO, &info, size) == size else { return nil }
        return withUnsafeBytes(of: info.pvip.vip_path) { string(fromNulTerminated: $0) }
    }

    private static func string(fromNulTerminated bytes: some Collection<UInt8>) -> String? {
        String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8)
    }

    private static func kernelInfo(_ pid: pid_t) -> kinfo_proc? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info
    }
}
