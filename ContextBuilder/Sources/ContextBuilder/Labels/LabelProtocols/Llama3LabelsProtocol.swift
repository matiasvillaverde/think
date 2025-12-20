import Foundation

/// Composite protocol for Llama 3 models
/// Includes core labels, tools, and Python environment support
internal protocol Llama3LabelsProtocol: CoreRoleLabels,
    InformationLabels,
    ToolCallingLabels,
    PythonEnvironmentLabels,
    StopSequenceLabels {}
