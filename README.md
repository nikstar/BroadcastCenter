
# BroadcastCenter

Type-safe version of NotificationCenter

Use this to broadcast values of different types

```swift
// Post a value
BroadcastCenter.shared.post(Foo(bar: 42))
 
// Elsewhere read values using async sequence:
for await foo in BroadcastCenter.shared.values(ofType: Foo.self) {
    print(foo.bar) // 42
}
```
