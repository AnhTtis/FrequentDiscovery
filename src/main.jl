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

function format_minsup_label(minsup::Float64)
    percent = round(minsup * 100, digits = 2)
    if isinteger(percent)
        return "$(Int(percent))%"
    end
    return "$(percent)%"
end

function compare_output_files(algorithm_name::String, input_file::String, output_dir::String, minsup::Float64)
    canonical_name, _ = resolve_algorithm(algorithm_name)
    base = stem_name(input_file)
    minsup_label = format_minsup_label(minsup)

    system_file = joinpath(output_dir, "system_$(base)_$(minsup_label).txt")
    local_file = joinpath(output_dir, "local_$(canonical_name)_$(base)_$(minsup_label).txt")
    benchmark_file = joinpath(output_dir, "benchmark_system_$(canonical_name)_$(base)_$(minsup_label).txt")

    if !isfile(system_file)
        println("System output not found: $system_file")
        exit()
    end

    if !isfile(local_file)
        println("Local output not found: $local_file")
        exit()
    end

    system_results = read_output(system_file)
    local_results = read_output(local_file)
    patterns_equal = canonical_results(system_results) == canonical_results(local_results)

    write_benchmark_output(
        benchmark_file,
        basename(system_file),
        system_results,
        basename(local_file),
        local_results,
        patterns_equal,
        input_file,
        minsup_label,
    )

    print_benchmark_summary(
        basename(system_file),
        system_results,
        basename(local_file),
        local_results,
        patterns_equal,
        input_file,
        minsup_label,
    )
end

function run_algorithm(algorithm_name::String, input_file::String, output_dir::String, minsup::Float64)
    canonical_name, runner = resolve_algorithm(algorithm_name)
    transactions = read_spmf(input_file)
    results, stats = runner(transactions, minsup)
    base = stem_name(input_file)
    minsup_label = format_minsup_label(minsup)

    result_path = joinpath(output_dir, "local_$(canonical_name)_$(base)_$(minsup_label).txt")

    write_output(result_path, results)
    print_algorithm_summary(canonical_name, results, stats, input_file, minsup)

    return canonical_name, results, stats
end

function compare_algorithms(alg1::String, alg2::String, input_file::String, output_dir::String, minsup::Float64)
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
elseif args.mode == "-b"
    compare_output_files(args.algorithm, args.input_path, args.output_path, args.minsup)
end
