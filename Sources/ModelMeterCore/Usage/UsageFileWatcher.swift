import Foundation

public final class UsageFileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

    public init() {}

    public func start(url: URL, onChange: @escaping @Sendable () -> Void) {
        stop()
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }

        let queue = DispatchQueue(label: "modelmeter.file.watcher")
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )
        source?.setEventHandler { onChange() }
        source?.setCancelHandler { [fd = fileDescriptor] in
            close(fd)
        }
        source?.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    deinit {
        stop()
    }
}
