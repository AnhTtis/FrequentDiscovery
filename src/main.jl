include("algorithm/structures.jl")
include("algorithm/utils.jl")
include("algorithm/fpgrowth.jl")
include("algorithm/projection_fpgrowth.jl")
include("algorithm/adjacency_fpgrowth.jl")

using .Structures
using .Utils
using .FPGrowth
using .ProjectionFPGrowth
using .AdjacencyFPGrowth

function canonical_results(results)
    Dict(Tuple(sort(items)) => support for (items, support) in results)
end

function resolve_algorithm(name::String)
    normalized = lowercase(name)

    if normalized == "classic" || normalized == "fpgrowth"
        return "classic", run_fpgrowth
    elseif normalized == "projection" || normalized == "projected_fpgrowth"
        return "projection", run_projection_fpgrowth
    elseif normalized == "adjacency" || normalized == "adjacency_fpgrowth"
        return "adjacency", run_adjacency_fpgrowth
    end

    println("Unknown algorithm: $name")
    println("Available algorithms: classic, projection, adjacency")
    exit()
end

function run_algorithm(algorithm_name::String, input_file::String, output_dir::String, minsup::Int)
    canonical_name, runner = resolve_algorithm(algorithm_name)
    transactions = read_spmf(input_file)
    results, stats = runner(transactions, minsup)
    base = stem_name(input_file)

    result_path = joinpath(output_dir, "result_$(canonical_name)_$(base)_$(minsup).txt")

    write_output(result_path, results)
    print_algorithm_summary(canonical_name, results, stats, input_file, minsup)

    return canonical_name, results, stats
end

function compare_algorithms(alg1::String, alg2::String, input_file::String, output_dir::String, minsup::Int)
    alg1_name, alg1_results, alg1_stats = run_algorithm(alg1, input_file, output_dir, minsup)
    alg2_name, alg2_results, alg2_stats = run_algorithm(alg2, input_file, output_dir, minsup)

end

args = parse_cli_args(ARGS)
ensure_output_dir(args.output_path)

if args.mode == "-a"
    for input_file in list_input_files(args.input_path)
        run_algorithm(args.algorithm, input_file, args.output_path, args.minsup)
    end
elseif args.mode == "-c"
    compare_algorithms(args.algorithm1, args.algorithm2, args.input_path, args.output_path, args.minsup)
elseif args.mode == "-ca"
    algorithms = ["classic", "projection", "adjacency"]

    for i in 1:length(algorithms)
        run_algorithm(algorithms[i], args.input_path, args.output_path, args.minsup)
    end
end
