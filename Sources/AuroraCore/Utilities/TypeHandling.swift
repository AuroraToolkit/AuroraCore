//
//  TypeHandling.swift
//  AuroraToolkit
//
//  Created by Dan Murrell Jr on 1/17/25.
//

protocol OptionalProtocol {
    static var wrappedType: Any.Type { get }
}

extension Optional: OptionalProtocol {
    static var wrappedType: Any.Type {
        return Wrapped.self
    }
}

func asArray<T>(_ value: Any, of _: T.Type) -> [T]? {
    if let array = value as? [T] {
        return array
    }
    if let arraySlice = value as? ArraySlice<T> {
        return Array(arraySlice)
    }
    return nil
}

func unwrapOptionalType<T>(_ type: T.Type) -> Any.Type {
    if let optionalType = type as? OptionalProtocol.Type {
        return optionalType.wrappedType
    }
    return type
}
