import Foundation

/// Labels for Python environment support (Llama 3.1 specific)
internal protocol PythonEnvironmentLabels {
    /// Label for Python code sections
    var pythonTagLabel: String? { get }

    /// Label marking end of message
    var endOfMessageLabel: String? { get }

    /// Label for IPython environment
    var ipythonLabel: String? { get }
}
