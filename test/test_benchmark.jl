using .Utils
using .FPGrowth
using .ProjectionFPGrowth
using .AdjacencyFPGrowth

function outputs_identical(comparison)
    comparison.support_mismatch_count == 0 &&
    comparison.only_file1_count == 0 &&
    comparison.only_file2_count == 0 &&
    comparison.output_file1_count == comparison.output_file2_count
end

@testset "Toy outputs match benchmark answers" begin
    minsup = 0.5
    toy_files = [
        "input1.txt",
        "input2.txt",
        "input3.txt",
        "input4.txt",
        "input5.txt",
    ]
    algorithms = [
        ("classic", run_fpgrowth),
        ("projection", run_projection_fpgrowth),
        ("adjacency", run_adjacency_fpgrowth),
    ]

    mktempdir() do tempdir
        for filename in toy_files
            input_path = joinpath(@__DIR__, "..", "dataset", "toy", filename)
            benchmark_path = joinpath(@__DIR__, "..", "dataset", "toy_benchmark", replace(filename, ".txt" => "_ans.txt"))
            transactions = read_spmf(input_path)

            for (algorithm_name, runner) in algorithms
                results, _ = runner(transactions, minsup)
                generated_path = joinpath(tempdir, "$(algorithm_name)_$(replace(filename, ".txt" => ""))_generated.txt")
                write_output(generated_path, results)

                comparison = compare_output_results(generated_path, benchmark_path)
                @test outputs_identical(comparison)
            end
        end
    end
end
