
/// Type-safe version of NotificationCenter
///
/// Use this to broadcast values of different types
///
/// ```swift
/// // Post a value
/// BroadcastCenter.shared.post(Foo(bar: 42))
/// 
/// // Elsewhere read values using async sequence:
/// for await foo in BroadcastCenter.shared.values(ofType: Foo.self) {
///     print(foo.bar) // 42
/// }
/// ```
public actor BroadcastCenter: Sendable {

    /// Shared instance of BroadcastCenter
    public static let shared = BroadcastCenter()
    
    /// Type-safe version of NotificationCenter.
    ///
    /// - Tip:  See also ``BroadcastCenter/BroadcastCenter/shared`` instance
    public init() {
    }
    
    private typealias BroadcastValueTypeKey = ObjectIdentifier

    private final class SubscriptionID: Hashable, Sendable {
        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }
        static func == (lhs: SubscriptionID, rhs: SubscriptionID) -> Bool {
            return lhs === rhs
        }
    }

    private var subscribers: [BroadcastValueTypeKey: [SubscriptionID: @Sendable (Any) -> ()]] = [:]

    /// Post a value to subscribers
    ///
    /// ```swift
    /// // Post a value
    /// BroadcastCenter.shared.post(Foo(bar: 42))
    /// 
    /// // Elsewhere read values using async sequence:
    /// for await foo in BroadcastCenter.shared.values(ofType: Foo.self) {
    ///     print(foo.bar) // 42
    /// }
    /// ```
    public nonisolated func post<T: Sendable>(_ value: T) {
        Task {
            let typeKey = ObjectIdentifier(T.self)
            guard let typeSubscribers = await subscribers[typeKey] else { return }
            for handler in typeSubscribers.values {
                handler(value)
            }
        }
    }
    
    /// Subscribe to values of the given type
    ///
    /// ```swift
    /// for await foo in BroadcastCenter.shared.values(ofType: Foo.self) {
    ///     print(foo.bar) // 42
    /// }
    /// ```
    /// 
    /// > Note: Subscription is cancelled automatically when surrounding Task is cancelled or when iteration is stopped
    public nonisolated func values<T: Sendable>(ofType type: T.Type) -> AsyncStream<T> {
        let key = ObjectIdentifier(T.self)
        let id = SubscriptionID()
        let (stream, continuation) = AsyncStream.makeStream(of: T.self, bufferingPolicy: .unbounded)
        continuation.onTermination = { _ in
            Task {
                await self.removeSubscription(typeKey: key, id: id)
            }
        }
        Task {
            await addSubscription(typeKey: key, id: id, continuation: continuation)
        }
        return stream
    }

    private func addSubscription<T: Sendable>(typeKey: BroadcastValueTypeKey, id: SubscriptionID, continuation: AsyncStream<T>.Continuation) {
        if subscribers[typeKey] == nil {
            subscribers[typeKey] = [:]
        }
        subscribers[typeKey]?[id] = { anyValue in
            if let value = anyValue as? T {
                continuation.yield(value)
            }
        }
    }

    private func removeSubscription(typeKey: BroadcastValueTypeKey, id: SubscriptionID) {
        subscribers[typeKey]?[id] = nil
    }
}
