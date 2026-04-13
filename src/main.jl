include("algorithm/structures.jl")
include("algorithm/memory_tracking.jl")
include("algorithm/utils.jl")
include("algorithm/fpgrowth.jl")
include("algorithm/projection_fpgrowth.jl")
include("algorithm/adjacency_fpgrowth.jl")
include("experiment/split_retail_subsets.jl")
include("experiment/exp_transaction_length.jl")

using .Structures
using .MemoryTracking
using .Utils
using .FPGrowth
using .ProjectionFPGrowth
using .AdjacencyFPGrowth
using .RetailSubsetSplitter: split_database_subsets
using .TransactionLengthExperiment: generate_transaction_length_datasets

function script_path()
    return abspath(@__FILE__)
end

function project_root()
    return normpath(joinpath(@__DIR__, ".."))
end

function spawn_algorithm_process(algorithm_name::String, input_file::String, output_dir::String, minsup::Float64)
    cmd = `$(Base.julia_cmd()) --project=$(normpath(joinpath(@__DIR__, ".."))) $(abspath(@__FILE__)) -a $algorithm_name $input_file $output_dir $(string(minsup))`
    run(cmd)
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

function run_algorithm(algorithm_name::String, input_file::String, output_dir::String, minsup::Float64)
    canonical_name, runner = resolve_algorithm(algorithm_name)
    transactions = read_spmf(input_file)
    results, stats = runner(transactions, minsup)
    base = stem_name(input_file)
    percent = round(minsup * 100, digits = 2)
    minsup_label = isinteger(percent) ? "$(Int(percent))%" : "$(percent)%"

    result_path = joinpath(output_dir, "local_$(canonical_name)_$(base)_$(minsup_label).txt")
    stats_path = stats_output_path(output_dir, canonical_name, input_file, minsup)

    write_output(result_path, results)
    write_stats_output(stats_path, canonical_name, stats, input_file, minsup)
    print_algorithm_summary(canonical_name, stats, input_file, minsup)
end

function compare_algorithms(alg1::String, alg2::String, input_file::String, output_dir::String, minsup::Float64)
    canonical_alg1, _ = resolve_algorithm(alg1)
    canonical_alg2, _ = resolve_algorithm(alg2)

    spawn_algorithm_process(canonical_alg1, input_file, output_dir, minsup)
    spawn_algorithm_process(canonical_alg2, input_file, output_dir, minsup)

    stats1 = read_stats_output(stats_output_path(output_dir, canonical_alg1, input_file, minsup))
    stats2 = read_stats_output(stats_output_path(output_dir, canonical_alg2, input_file, minsup))
    print_comparison_summary(stats1, stats2)
end

args = parse_cli_args(ARGS)

if args.mode != "-b"
    ensure_output_dir(args.output_path)
end

if args.mode == "-a"
    for input_file in list_input_files(args.input_path)
        run_algorithm(args.algorithm, input_file, args.output_path, args.minsup)
    end
elseif args.mode == "-c"
    compare_algorithms(args.algorithm1, args.algorithm2, args.input_path, args.output_path, args.minsup)
elseif args.mode == "-ca"
    algorithms = ["classic", "projection", "adjacency"]

    for algorithm in algorithms
        spawn_algorithm_process(algorithm, args.input_path, args.output_path, args.minsup)
    end
elseif args.mode == "-b"
    compare_output_files(args.algorithm, args.input_path, args.output_path, args.minsup)
elseif args.mode == "-s"
    split_database_subsets(args.input_path, args.output_path, args.ratios, args.seed, args.sampling)
elseif args.mode == "-tl"
    generate_transaction_length_datasets(
        args.output_path,
        args.transaction_count,
        args.transaction_item_range,
        args.transaction_lengths,
    )
end
