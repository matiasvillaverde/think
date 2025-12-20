import Foundation
import MLX
import MLXNN

internal class ReflectionPad1d: Module {
    let padding: IntOrPair

    init(padding: (Int, Int)) {
        self.padding = IntOrPair([padding.0, padding.1])
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        MLX.padded(x, widths: [IntOrPair([0, 0]), IntOrPair([0, 0]), padding])
    }

    deinit {
        // MLX neural network module - no explicit cleanup needed
    }
}
