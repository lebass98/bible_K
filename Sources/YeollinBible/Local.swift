import SwiftUI

/// @Local 대신 쓰는 화면 상태 (Command Line Tools에는 @Local 매크로 처리기가 없음)
final class Box<T>: ObservableObject {
    @Published var value: T
    init(_ value: T) { self.value = value }
}

@propertyWrapper
struct Local<T>: DynamicProperty {
    @StateObject private var box: Box<T>

    init(wrappedValue: T) {
        _box = StateObject(wrappedValue: Box(wrappedValue))
    }

    var wrappedValue: T {
        get { box.value }
        nonmutating set { box.value = newValue }
    }

    var projectedValue: Binding<T> { $box.value }
}
