import Foundation

protocol GlobalOptionsAccessing {
    var global: GlobalOptions { get }
    var parentGlobal: GlobalOptions? { get }
}

extension GlobalOptionsAccessing {
    var resolvedGlobal: GlobalOptions {
        global.merged(with: parentGlobal)
    }
}
