import Foundation
import MLX
import MLXNN

// swiftlint:disable shorthand_operator

internal class LSTM: Module {
    let inputSize: Int
    let hiddenSize: Int
    let hasBias: Bool
    let batchFirst: Bool

    // Forward direction weights and biases
    var wxForward: MLXArray
    var whForward: MLXArray
    var biasIhForward: MLXArray?
    var biasHhForward: MLXArray?

    // Backward direction weights and biases
    var wxBackward: MLXArray
    var whBackward: MLXArray
    var biasIhBackward: MLXArray?
    var biasHhBackward: MLXArray?

    init(
        inputSize: Int,
        hiddenSize: Int,
        bias: Bool = true,
        batchFirst: Bool = true,
        wxForward: MLXArray,
        whForward: MLXArray,
        biasIhForward: MLXArray? = nil,
        biasHhForward: MLXArray? = nil,
        wxBackward: MLXArray,
        whBackward: MLXArray,
        biasIhBackward: MLXArray? = nil,
        biasHhBackward: MLXArray? = nil
    ) {
        self.inputSize = inputSize
        self.hiddenSize = hiddenSize
        hasBias = bias
        self.batchFirst = batchFirst

        // Forward direction weights and biases
        self.wxForward = wxForward
        self.whForward = whForward
        self.biasIhForward = biasIhForward
        self.biasHhForward = biasHhForward

        // Backward direction weights and biases
        self.wxBackward = wxBackward
        self.whBackward = whBackward
        self.biasIhBackward = biasIhBackward
        self.biasHhBackward = biasHhBackward

        super.init()
    }

    /// Process sequence in forward direction
    private func forwardDirection(
        _ input: MLXArray,
        hidden: MLXArray? = nil,
        cell: MLXArray? = nil
    ) -> (MLXArray, MLXArray) {
        // Pre-compute input projections
        let inputProjection: MLXArray
        if let biasIhForward, let biasHhForward {
            inputProjection = MLX.addMM(
                biasIhForward + biasHhForward,
                input,
                wxForward.transposed()
            )
        } else {
            inputProjection = MLX.matmul(input, wxForward.transposed())
        }

        var allHidden: [MLXArray] = []
        var allCell: [MLXArray] = []

        let sequenceLength: Int = input.shape[input.shape.count - 2]

        var currentHidden: MLXArray = hidden ?? MLXArray.zeros([input.shape[0], hiddenSize])
        var currentCell: MLXArray = cell ?? MLXArray.zeros([input.shape[0], hiddenSize])

        // Process sequence in forward direction (0 to sequenceLength-1)
        for timeStep in 0 ..< sequenceLength {
            var gateInputs: MLXArray = inputProjection[0..., timeStep, 0...]
            gateInputs = gateInputs + MLX.matmul(currentHidden, whForward.transposed())

            // Split gates
            let gates: [MLXArray] = MLX.split(gateInputs, parts: 4, axis: -1)
            let inputGate: MLXArray = MLX.sigmoid(gates[0])
            let forgetGate: MLXArray = MLX.sigmoid(gates[1])
            let candidateGate: MLXArray = MLX.tanh(gates[2])
            let outputGate: MLXArray = MLX.sigmoid(gates[3])

            // Update cell and hidden states
            currentCell = forgetGate * currentCell + inputGate * candidateGate
            currentHidden = outputGate * MLX.tanh(currentCell)

            allCell.append(currentCell)
            allHidden.append(currentHidden)
        }

        return (MLX.stacked(allHidden, axis: -2), MLX.stacked(allCell, axis: -2))
    }

    /// Process sequence in backward direction
    private func backwardDirection(
        _ input: MLXArray,
        hidden: MLXArray? = nil,
        cell: MLXArray? = nil
    ) -> (MLXArray, MLXArray) {
        let inputProjection: MLXArray
        if let biasIhBackward, let biasHhBackward {
            inputProjection = MLX.addMM(
                biasIhBackward + biasHhBackward,
                input,
                wxBackward.transposed()
            )
        } else {
            inputProjection = MLX.matmul(input, wxBackward.transposed())
        }

        var allHidden: [MLXArray] = []
        var allCell: [MLXArray] = []

        let sequenceLength: Int = input.shape[input.shape.count - 2]

        var currentHidden: MLXArray = hidden ?? MLXArray.zeros([input.shape[0], hiddenSize])
        var currentCell: MLXArray = cell ?? MLXArray.zeros([input.shape[0], hiddenSize])

        // Process sequence in backward direction (sequenceLength-1 to 0)
        for timeStep in stride(from: sequenceLength - 1, through: 0, by: -1) {
            var gateInputs: MLXArray = inputProjection[0..., timeStep, 0...]
            gateInputs = gateInputs + MLX.matmul(currentHidden, whBackward.transposed())

            // Split gates
            let gates: [MLXArray] = MLX.split(gateInputs, parts: 4, axis: -1)
            let inputGate: MLXArray = MLX.sigmoid(gates[0])
            let forgetGate: MLXArray = MLX.sigmoid(gates[1])
            let candidateGate: MLXArray = MLX.tanh(gates[2])
            let outputGate: MLXArray = MLX.sigmoid(gates[3])

            // Update cell and hidden states
            currentCell = forgetGate * currentCell + inputGate * candidateGate
            currentHidden = outputGate * MLX.tanh(currentCell)

            // Insert at beginning to maintain original sequence order
            allCell.insert(currentCell, at: 0)
            allHidden.insert(currentHidden, at: 0)
        }

        return (MLX.stacked(allHidden, axis: -2), MLX.stacked(allCell, axis: -2))
    }

    func callAsFunction(
        _ input: MLXArray,
        hiddenForward: MLXArray? = nil,
        cellForward: MLXArray? = nil,
        hiddenBackward: MLXArray? = nil,
        cellBackward: MLXArray? = nil
    ) -> (MLXArray, ((MLXArray, MLXArray), (MLXArray, MLXArray))) {
        let processedInput: MLXArray
        if input.ndim == 2 {
            // (1, seq_len, input_size)
            processedInput = input.expandedDimensions(axis: 0)
        } else {
            processedInput = input
        }

        let (forwardHidden, forwardCell): (MLXArray, MLXArray) = forwardDirection(
            processedInput,
            hidden: hiddenForward,
            cell: cellForward
        )

        let (backwardHidden, backwardCell): (MLXArray, MLXArray) = backwardDirection(
            processedInput,
            hidden: hiddenBackward,
            cell: cellBackward
        )

        let output: MLXArray = MLX.concatenated([forwardHidden, backwardHidden], axis: -1)

        return (
            output,
            (
                (forwardHidden[0..., -1, 0...], forwardCell[0..., -1, 0...]),
                (backwardHidden[0..., 0, 0...], backwardCell[0..., 0, 0...])
            )
        )
    }

    deinit {
        // MLX neural network module - no explicit cleanup needed
    }
}
// swiftlint:enable shorthand_operator
