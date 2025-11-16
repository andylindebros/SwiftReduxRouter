import Foundation

extension SwiftRouter {
    public protocol Logger: Sendable {
        func debug(_ values: Any?..., file: StaticString, line: UInt)
        func info(_ values: Any?..., file: StaticString, line: UInt)
        func warning(_ values: Any?..., file: StaticString, line: UInt)
        func error(_ values: Any?..., file: StaticString, line: UInt)
    }
}

extension SwiftRouter.Logger {
    func debug(_ values: Any?..., file: StaticString = #file, line: UInt = #line) {
        debug(values, file: file, line: line)
    }
    func info(_ values: Any?..., file: StaticString = #file, line: UInt = #line) {
        info(values, file: file, line: line)
    }
    func warning(_ values: Any?..., file: StaticString = #file, line: UInt = #line) {
        warning(values, file: file, line: line)
    }
    func error(_ values: Any?..., file: StaticString = #file, line: UInt = #line) {
        error(values, file: file, line: line)
    }
}


