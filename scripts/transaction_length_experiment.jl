project_root = normpath(joinpath(@__DIR__, ".."))

include(joinpath(project_root, "src", "algorithm", "structures.jl"))
include(joinpath(project_root, "src", "algorithm", "memory_tracking.jl"))
include(joinpath(project_root, "src", "algorithm", "utils.jl"))
include(joinpath(project_root, "src", "algorithm", "fpgrowth.jl"))
include(joinpath(project_root, "src", "algorithm", "projection_fpgrowth.jl"))
include(joinpath(project_root, "src", "algorithm", "adjacency_fpgrowth.jl"))

using Statistics
using .Structures
using .Utils
using .FPGrowth
using .ProjectionFPGrowth
using .AdjacencyFPGrowth

function usage()
    println("Synthetic transaction-length experiment")
    println("Usage:")
    println("  julia scripts/transaction_length_experiment.jl [options]")
    println("")
    println("Options:")
    println("  --algorithm <classic|projection|adjacency|all>   default: all")
    println("  --transactions <count>                           default: 2000")
    println("  --lengths <comma-separated lengths>              default: 6,12,18,24,30")
    println("  --minsup <ratio>                                 default: 0.2")
    println("  --repetitions <count>                            default: 3")
    println("  --dataset-dir <path>                             default: synthetic/transaction_length")
    println("  --output-dir <path>                              default: output/transaction_length_experiment")
    println("")
    println("Example:")
    println("  julia scripts/transaction_length_experiment.jl --algorithm all --transactions 3000 --lengths 6,12,18,24,30 --minsup 0.2 --repetitions 5")
end

function parse_lengths(text::String)
    lengths = sort(unique(parse.(Int, split(text, ","))))
    isempty(lengths) && error("Lengths must not be empty.")
    any(length -> length <= 0, lengths) && error("Lengths must be positive integers.")
    return lengths
end

function parse_experiment_args(args)
    config = Dict{String,Any}(
        "algorithm" => "all",
        "transactions" => 2000,
        "lengths" => [6, 12, 18, 24, 30],
        "minsup" => 0.2,
        "repetitions" => 3,
        "dataset_dir" => joinpath(project_root, "synthetic", "transaction_length"),
        "output_dir" => joinpath(project_root, "output", "transaction_length_experiment"),
    )

    index = 1
    while index <= length(args)
        arg = args[index]

        if arg == "--algorithm"
            index += 1
            config["algorithm"] = lowercase(args[index])
        elseif arg == "--transactions"
            index += 1
            config["transactions"] = parse(Int, args[index])
        elseif arg == "--lengths"
            index += 1
            config["lengths"] = parse_lengths(args[index])
        elseif arg == "--minsup"
            index += 1
            config["minsup"] = parse(Float64, args[index])
        elseif arg == "--repetitions"
            index += 1
            config["repetitions"] = parse(Int, args[index])
        elseif arg == "--dataset-dir"
            index += 1
            config["dataset_dir"] = args[index]
        elseif arg == "--output-dir"
            index += 1
            config["output_dir"] = args[index]
        elseif arg == "--help" || arg == "-h"
            usage()
            exit()
        else
            error("Unknown argument: $arg")
        end

        index += 1
    end

    config["transactions"] <= 0 && error("Transactions must be positive.")
    config["repetitions"] <= 0 && error("Repetitions must be positive.")
    (config["minsup"] <= 0 || config["minsup"] > 1) && error("Minimum support must be in (0, 1].")

    return (
        algorithm = config["algorithm"],
        transactions = config["transactions"],
        lengths = config["lengths"],
        minsup = config["minsup"],
        repetitions = config["repetitions"],
        dataset_dir = config["dataset_dir"],
        output_dir = config["output_dir"],
    )
end

function selected_algorithms(name::String)
    if name == "all"
        return ["classic", "projection", "adjacency"]
    elseif name in ("classic", "projection", "adjacency")
        return [name]
    end

    error("Unsupported algorithm: $name")
end

function resolve_algorithm_runner(name::String)
    if name == "classic"
        return run_fpgrowth
    elseif name == "projection"
        return run_projection_fpgrowth
    elseif name == "adjacency"
        return run_adjacency_fpgrowth
    end

    error("Unsupported algorithm: $name")
end

function core_items_for_transaction(tid::Int)
    items = Int[1, 2, 3]

    if tid % 2 == 0
        push!(items, 4)
    end

    if tid % 3 == 0
        push!(items, 5)
    end

    if tid % 5 == 0
        push!(items, 6)
    end

    return items
end

function synthetic_transaction(tid::Int, target_length::Int)
    items = core_items_for_transaction(tid)
    if length(items) > target_length
        error("Target transaction length $target_length is too small. Use a value of at least 6.")
    end

    filler_count = target_length - length(items)
    filler_base = 10_000 + (tid - 1) * target_length

    for offset in 1:filler_count
        push!(items, filler_base + offset)
    end

    return items
end

function generate_synthetic_transactions(transaction_count::Int, target_length::Int)
    transactions = Vector{Vector{Int}}(undef, transaction_count)

    for tid in 1:transaction_count
        transactions[tid] = synthetic_transaction(tid, target_length)
    end

    return transactions
end

function write_transactions(path::String, transactions)
    open(path, "w") do io
        for transaction in transactions
            println(io, join(transaction, " "))
        end
    end
end

function dataset_filename(length_value::Int, transaction_count::Int)
    return "txlen_$(lpad(length_value, 3, '0'))_n$(transaction_count).txt"
end

function write_csv(path::String, rows)
    isempty(rows) && return

    headers = collect(keys(first(rows)))
    open(path, "w") do io
        println(io, join(headers, ","))
        for row in rows
            values = [string(getproperty(row, header)) for header in headers]
            println(io, join(values, ","))
        end
    end
end

function write_experiment_design(path::String, config)
    open(path, "w") do io
        println(io, "# Transaction-Length Experiment")
        println(io, "")
        println(io, "- Transactions per dataset: $(config.transactions)")
        println(io, "- Transaction lengths: $(join(config.lengths, ", "))")
        println(io, "- Minimum support: $(config.minsup)")
        println(io, "- Repetitions per setting: $(config.repetitions)")
        println(io, "")
        println(io, "Synthetic data design:")
        println(io, "- Every transaction always contains items `1 2 3`.")
        println(io, "- Even-index transactions also contain item `4`.")
        println(io, "- Transactions whose index is divisible by `3` also contain item `5`.")
        println(io, "- Transactions whose index is divisible by `5` also contain item `6`.")
        println(io, "- The remaining positions are filled with unique noise items so the total length matches the target exactly.")
        println(io, "")
        println(io, "This keeps a stable frequent-pattern core while increasing transaction length through extra noise items.")
        println(io, "If runtime or peak RAM rises as length grows, that is evidence the algorithm is sensitive to transaction length.")
    end
end

function generate_datasets(config)
    ensure_output_dir(config.dataset_dir)
    metadata_rows = NamedTuple[]
    dataset_specs = NamedTuple[]

    for length_value in config.lengths
        transactions = generate_synthetic_transactions(config.transactions, length_value)
        path = joinpath(config.dataset_dir, dataset_filename(length_value, config.transactions))
        write_transactions(path, transactions)

        push!(dataset_specs, (
            path = path,
            transaction_length = length_value,
            transaction_count = config.transactions,
        ))

        push!(metadata_rows, (
            dataset = basename(path),
            transaction_count = config.transactions,
            target_length = length_value,
            average_length = length_value,
            minsup = config.minsup,
        ))
    end

    metadata_path = joinpath(config.output_dir, "datasets.csv")
    write_csv(metadata_path, metadata_rows)
    return dataset_specs
end

function peak_ram_mb(stats)
    if stats.peak_working_set_bytes <= 0
        return "n/a"
    end

    return string(round(stats.peak_working_set_bytes / 1024^2, digits = 2))
end

function numeric_peak_ram_mb(row)
    row.peak_ram_mb == "n/a" && return NaN
    return parse(Float64, row.peak_ram_mb)
end

function warmup_runner!(runner)
    warmup_transactions = generate_synthetic_transactions(200, 6)
    GC.gc()
    GC.gc()
    runner(warmup_transactions, 0.2)
    GC.gc()
    GC.gc()
    return nothing
end

function benchmark_algorithm(algorithm_name::String, dataset_specs, config)
    runner = resolve_algorithm_runner(algorithm_name)
    warmup_runner!(runner)
    measurement_rows = NamedTuple[]

    for dataset in dataset_specs
        transactions = read_spmf(dataset.path)

        for repetition in 1:config.repetitions
            GC.gc()
            GC.gc()
            results, stats = runner(transactions, config.minsup)

            push!(measurement_rows, (
                algorithm = algorithm_name,
                dataset = basename(dataset.path),
                transaction_count = dataset.transaction_count,
                transaction_length = dataset.transaction_length,
                repetition = repetition,
                minsup = config.minsup,
                runtime_ns = stats.runtime_ns,
                runtime_ms = round(stats.runtime_ns / 1_000_000, digits = 3),
                peak_ram_mb = peak_ram_mb(stats),
                pattern_count = length(results),
                node_count = stats.node_count,
                tree_count = stats.tree_count,
                conditional_tree_count = stats.conditional_tree_count,
                projection_count = stats.projection_count,
            ))
        end
    end

    return measurement_rows
end

function summarize_measurements(rows)
    grouped = Dict{Tuple{String,Int},Vector{typeof(first(rows))}}()

    for row in rows
        key = (row.algorithm, row.transaction_length)
        push!(get!(grouped, key, typeof(row)[]), row)
    end

    summary_rows = NamedTuple[]
    for key in sort(collect(keys(grouped)), by = entry -> (entry[1], entry[2]))
        group_rows = grouped[key]
        runtime_values = [row.runtime_ms for row in group_rows]
        peak_values = [numeric_peak_ram_mb(row) for row in group_rows if !isnan(numeric_peak_ram_mb(row))]
        reference = first(group_rows)

        push!(summary_rows, (
            algorithm = key[1],
            transaction_length = key[2],
            repetitions = length(group_rows),
            median_runtime_ms = round(median(runtime_values), digits = 3),
            average_runtime_ms = round(mean(runtime_values), digits = 3),
            max_peak_ram_mb = isempty(peak_values) ? "n/a" : string(round(maximum(peak_values), digits = 2)),
            average_peak_ram_mb = isempty(peak_values) ? "n/a" : string(round(mean(peak_values), digits = 2)),
            pattern_count = reference.pattern_count,
        ))
    end

    return summary_rows
end

function print_summary(summary_rows)
    println(repeat("=", 60))
    println("Synthetic transaction-length experiment")
    println(repeat("=", 60))

    current_algorithm = ""
    for row in summary_rows
        if row.algorithm != current_algorithm
            current_algorithm = row.algorithm
            println("")
            println("Algorithm: $(row.algorithm)")
        end

        println(
            "  length=$(row.transaction_length), median_runtime_ms=$(row.median_runtime_ms), max_peak_ram_mb=$(row.max_peak_ram_mb), patterns=$(row.pattern_count)"
        )
    end

    println(repeat("=", 60))
end

function main(args)
    config = parse_experiment_args(args)
    ensure_output_dir(config.output_dir)

    design_path = joinpath(config.output_dir, "design.md")
    write_experiment_design(design_path, config)

    dataset_specs = generate_datasets(config)
    algorithms = selected_algorithms(config.algorithm)
    measurement_rows = NamedTuple[]

    for algorithm_name in algorithms
        append!(measurement_rows, benchmark_algorithm(algorithm_name, dataset_specs, config))
    end

    measurement_path = joinpath(config.output_dir, "measurements.csv")
    summary_path = joinpath(config.output_dir, "summary.csv")

    write_csv(measurement_path, measurement_rows)
    summary_rows = summarize_measurements(measurement_rows)
    write_csv(summary_path, summary_rows)
    print_summary(summary_rows)

    println("Dataset directory: $(config.dataset_dir)")
    println("Measurements: $measurement_path")
    println("Summary: $summary_path")
    println("Design note: $design_path")
end

main(ARGS)
