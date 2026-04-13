using Test

include(joinpath(@__DIR__, "..", "src", "algorithm", "structures.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "utils.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "fpgrowth.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "projection_fpgrowth.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "adjacency_fpgrowth.jl"))

include(joinpath(@__DIR__, "test_correctness.jl"))
include(joinpath(@__DIR__, "test_benchmark.jl"))
