import Foundation

/// Available scheduler algorithms for the diffusion process
public enum Scheduler: String, Sendable, CaseIterable {
    /// PNDM (Pseudo Numerical Diffusion Model) scheduler
    case pndmScheduler = "PNDM"

    /// DPM-Solver multistep scheduler (faster convergence)
    case dpmSolverMultistepScheduler = "DPMSolverMultistep"

    /// Discrete flow scheduler
    case discreteFlowScheduler = "DiscreteFlow"
}
