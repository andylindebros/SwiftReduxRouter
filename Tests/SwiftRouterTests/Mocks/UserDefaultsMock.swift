import Foundation
import SwiftRouter

final class UserDefaultsMock: UserDefaultsProvider {
    let events = EventActor()

    @discardableResult func reset() -> Self {
        Task { [weak events] in
            await events?.reset()
        }
        return self
    }

    private var dataResponse: Data?

    @discardableResult func setDataResponse(to newValue: Data?) -> Self {
        dataResponse = newValue
        return self
    }

    func set(_ value: Any?, forKey: String) {
        let value = value as? String
        Task { [weak events] in
            await events?.add(.set(value: value, forKey: forKey))
        }
    }

    func data(forKey: String) -> Data? {
        Task { [weak events] in
            await events?.add(.data(forKey: forKey))
        }
        return dataResponse
    }

    func removeObject(forKey: String) {
        Task { [weak events] in
            await events?.add(.removeObject(forKey: forKey))
        }
    }

    enum Event: Equatable {
        case set(value: String?, forKey: String)
        case data(forKey: String)
        case removeObject(forKey: String)
    }

    final actor EventActor: Sendable {
        private var events: [Event] = []

        func add(_ event: Event) async {
            events.append(event)
        }

        func get() async -> [Event] {
            events
        }

        func reset() async {
            events = []
        }
    }
}
