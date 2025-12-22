import MLX
import MLXNN

/// Protocol for layers that apply an offset-aware transform (e.g. RoPE).
internal protocol OffsetLayer: Module {
    func callAsFunction(_ x: MLXArray, offset: Int) -> MLXArray
}

extension RoPE: OffsetLayer {}
