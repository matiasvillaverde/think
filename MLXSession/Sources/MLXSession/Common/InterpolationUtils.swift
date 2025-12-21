import Foundation
import MLX
import MLXFast

private func makeBicubicInterpolationKernel() -> MLXFast.MLXFastKernel {
    let header = """
        float cubic_kernel(float x) {
            float absx = fabs(x);
            float absx2 = absx * absx;
            float absx3 = absx2 * absx;

            const float a = -0.5f;

            if (absx <= 1.0f) {
                return (a + 2.0f) * absx3 - (a + 3.0f) * absx2 + 1.0f;
            } else if (absx < 2.0f) {
                return a * absx3 - 5.0f * a * absx2 + 8.0f * a * absx - 4.0f * a;
            }
            return 0.0f;
        }

        float cubic_kernel_antialias(float x, float scale) {
            return cubic_kernel(x / scale);
        }
        """

    let source = """
        uint x_out = thread_position_in_grid.x;
        uint y_out = thread_position_in_grid.y;
        uint bc_idx = thread_position_in_grid.z;

        int batch_size = dims[0];
        int channels = dims[1];
        int in_h = dims[2];
        int in_w = dims[3];
        int out_h = dims[4];
        int out_w = dims[5];

        float scale_h = params[0];
        float scale_w = params[1];
        bool align_corners = params[2] > 0.5f;
        bool use_antialias = params[3] > 0.5f;
        float filter_scale_h = params[4];
        float filter_scale_w = params[5];
        float support = params[6];

        if (x_out >= (uint)out_w || y_out >= (uint)out_h || bc_idx >= (uint)(batch_size * channels))
            return;

        int c = bc_idx % channels;
        int b = bc_idx / channels;

        float x_in, y_in;

        if (align_corners && out_w > 1 && out_h > 1) {
            x_in = float(x_out) * (in_w - 1) / (out_w - 1);
            y_in = float(y_out) * (in_h - 1) / (out_h - 1);
        } else {
            x_in = ((float(x_out) + 0.5f) / float(out_w)) * float(in_w) - 0.5f;
            y_in = ((float(y_out) + 0.5f) / float(out_h)) * float(in_h) - 0.5f;
        }

        float support_h = use_antialias ? support * filter_scale_h : support;
        float support_w = use_antialias ? support * filter_scale_w : support;

        int y_start = int(floor(y_in - support_h)) + 1;
        int y_end = int(floor(y_in + support_h)) + 1;
        int x_start = int(floor(x_in - support_w)) + 1;
        int x_end = int(floor(x_in + support_w)) + 1;

        y_start = max(0, y_start);
        y_end = min(in_h, y_end);
        x_start = max(0, x_start);
        x_end = min(in_w, x_end);

        float result = 0.0f;
        float weight_sum = 0.0f;

        for (int y_pos = y_start; y_pos < y_end; y_pos++) {
            float dy = float(y_pos) - y_in;
            float wy = use_antialias ?
                cubic_kernel_antialias(dy, filter_scale_h) :
                cubic_kernel(dy);

            for (int x_pos = x_start; x_pos < x_end; x_pos++) {
                float dx = float(x_pos) - x_in;
                float wx = use_antialias ?
                    cubic_kernel_antialias(dx, filter_scale_w) :
                    cubic_kernel(dx);

                float weight = wy * wx;

                int input_offset = ((b * channels + c) * in_h + y_pos) * in_w + x_pos;

                result += input[input_offset] * weight;
                weight_sum += weight;
            }
        }

        if (weight_sum > 1e-8f) {
            result /= weight_sum;
        }

        int output_offset = ((b * channels + c) * out_h + y_out) * out_w + x_out;

        output[output_offset] = result;
        """

    return MLXFast.metalKernel(
        name: "bicubic_interpolation_antialias",
        inputNames: ["input", "dims", "params"],
        outputNames: ["output"],
        source: source,
        header: header
    )
}

private func makeNearestInterpolationKernel() -> MLXFast.MLXFastKernel {
    let source = """
        uint x_out = thread_position_in_grid.x;
        uint y_out = thread_position_in_grid.y;
        uint bc_idx = thread_position_in_grid.z;

        int batch_size = dims[0];
        int channels = dims[1];
        int in_h = dims[2];
        int in_w = dims[3];
        int out_h = dims[4];
        int out_w = dims[5];

        if (x_out >= (uint)out_w || y_out >= (uint)out_h || bc_idx >= (uint)(batch_size * channels))
            return;

        int c = bc_idx % channels;
        int b = bc_idx / channels;

        float scale_h = float(in_h) / float(out_h);
        float scale_w = float(in_w) / float(out_w);

        int y_in = int(floor(float(y_out) * scale_h));
        int x_in = int(floor(float(x_out) * scale_w));

        y_in = max(0, min(y_in, in_h - 1));
        x_in = max(0, min(x_in, in_w - 1));

        int input_offset = ((b * channels + c) * in_h + y_in) * in_w + x_in;
        int output_offset = ((b * channels + c) * out_h + y_out) * out_w + x_out;

        output[output_offset] = input[input_offset];
        """

    return MLXFast.metalKernel(
        name: "nearest_interpolation",
        inputNames: ["input", "dims"],
        outputNames: ["output"],
        source: source
    )
}

private final class InterpolationKernelManager: Sendable {
    static let shared = InterpolationKernelManager()

    let bicubicKernel: MLXFast.MLXFastKernel
    let nearestKernel: MLXFast.MLXFastKernel

    private init() {
        bicubicKernel = makeBicubicInterpolationKernel()
        nearestKernel = makeNearestInterpolationKernel()
    }
}

private func getOptimalThreadgroup(outW: Int, outH: Int) -> (Int, Int, Int) {
    let maxThreadsPerGroup = 1024
    let maxThreadsPerDim = 1024

    let defaultThreadgroup = (32, 32, 1)

    let maxWidth = min(maxThreadsPerDim, outW)
    let maxHeight = min(maxThreadsPerDim, outH)

    guard maxWidth > 0 && maxHeight > 0 else {
        return defaultThreadgroup
    }

    var width = 1 << (Int.bitWidth - maxWidth.leadingZeroBitCount - 1)
    if width > maxWidth {
        width = width / 2
    }

    var height = 1 << (Int.bitWidth - maxHeight.leadingZeroBitCount - 1)
    if height > maxHeight {
        height = height / 2
    }

    while width * height > maxThreadsPerGroup {
        if width >= height {
            width /= 2
        } else {
            height /= 2
        }
    }

    if width == 0 { width = 1 }
    if height == 0 { height = 1 }

    return (width, height, 1)
}

internal enum InterpolationMode: String {
    case nearest
    case bicubic
}

private func interpolateImpl(
    _ input: MLXArray,
    size: (Int, Int)? = nil,
    scaleFactor: (Float, Float)? = nil,
    mode: InterpolationMode = .nearest,
    alignCorners: Bool = false,
    antialias: Bool = false
) -> MLXArray {
    let shape = input.shape
    guard shape.count == 4 else {
        fatalError("Input must be 4D [B, C, H, W]")
    }

    let (batchSize, channels, inH, inW) = (shape[0], shape[1], shape[2], shape[3])

    let outH: Int
    let outW: Int
    let scaleH: Float
    let scaleW: Float

    if let size {
        outH = size.0
        outW = size.1
        scaleH = Float(outH) / Float(inH)
        scaleW = Float(outW) / Float(inW)
    } else if let scaleFactor {
        scaleH = scaleFactor.0
        scaleW = scaleFactor.1
        outH = Int(Float(inH) * scaleH)
        outW = Int(Float(inW) * scaleW)
    } else {
        fatalError("Either size or scaleFactor must be specified")
    }

    let dims = MLXArray([batchSize, channels, inH, inW, outH, outW])

    let inputFlat = input.reshaped(-1)
    let inputDType = input.dtype
    let castInput = inputDType == .float32 ? inputFlat : inputFlat.asType(.float32)

    switch mode {
    case .nearest:
        let kernel = InterpolationKernelManager.shared.nearestKernel
        let threadgroup = getOptimalThreadgroup(outW: outW, outH: outH)
        let output = kernel(
            [castInput, dims],
            grid: (outW, outH, batchSize * channels),
            threadGroup: threadgroup,
            outputShapes: [[batchSize * channels * outH * outW]],
            outputDTypes: [.float32]
        )[0]
        var result = output.reshaped(batchSize, channels, outH, outW)
        if inputDType != .float32 {
            result = result.asType(inputDType)
        }
        return result

    case .bicubic:
        let kernel = InterpolationKernelManager.shared.bicubicKernel

        let support: Float = 2.0
        let antialiasFlag: Float = antialias && (scaleH < 1.0 || scaleW < 1.0) ? 1.0 : 0.0
        let filterScaleH: Float = antialias && scaleH < 1.0 ? 1.0 / scaleH : 1.0
        let filterScaleW: Float = antialias && scaleW < 1.0 ? 1.0 / scaleW : 1.0

        let alignCornersValue: Float = alignCorners ? 1.0 : 0.0
        let params = MLXArray(
            [scaleH, scaleW, alignCornersValue, antialiasFlag, filterScaleH, filterScaleW, support]
        )

        let threadgroup = getOptimalThreadgroup(outW: outW, outH: outH)
        let output = kernel(
            [castInput, dims, params],
            grid: (outW, outH, batchSize * channels),
            threadGroup: threadgroup,
            outputShapes: [[batchSize * channels * outH * outW]],
            outputDTypes: [.float32]
        )[0]
        var result = output.reshaped(batchSize, channels, outH, outW)
        if inputDType != .float32 {
            result = result.asType(inputDType)
        }
        return result
    }
}

internal func interpolate(
    _ input: MLXArray,
    size: (Int, Int)? = nil,
    scaleFactor: (Float, Float)? = nil,
    mode: InterpolationMode = .nearest,
    alignCorners: Bool = false,
    antialias: Bool = false
) -> MLXArray {
    interpolateImpl(
        input,
        size: size,
        scaleFactor: scaleFactor,
        mode: mode,
        alignCorners: alignCorners,
        antialias: antialias
    )
}

internal enum InterpolationUtils {
    internal static func interpolate(
        _ input: MLXArray,
        size: (Int, Int)? = nil,
        scaleFactor: (Float, Float)? = nil,
        mode: InterpolationMode = .nearest,
        alignCorners: Bool = false,
        antialias: Bool = false
    ) -> MLXArray {
        interpolateImpl(
            input,
            size: size,
            scaleFactor: scaleFactor,
            mode: mode,
            alignCorners: alignCorners,
            antialias: antialias
        )
    }
}
