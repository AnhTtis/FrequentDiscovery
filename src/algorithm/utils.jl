module Utils

using ..Structures: MiningStats

export ensure_output_dir, list_input_files, parse_cli_args, read_spmf, read_output, read_stats_output, stem_name, stats_output_path, write_benchmark_output, write_output, write_stats_output, print_algorithm_summary, print_benchmark_summary, print_comparison_summary, reset_memory_tracking!, sample_memory!, memory_tracking_supported

const DEFAULT_SUBSET_RATIOS = [0.10, 0.25, 0.50, 0.75, 1.00]
const DEFAULT_SUBSET_SEED = 2026
const DEFAULT_SUBSET_SAMPLING = "independent"
const DEFAULT_TRANSACTION_LENGTH_COUNT = 1000
const DEFAULT_TRANSACTION_LENGTH_ITEMS = 100
const DEFAULT_TRANSACTION_LENGTHS = [5, 10, 20, 30, 50]

function format_memory(bytes::Integer)
    units = ["bytes", "KB", "MB", "GB", "TB"]
    value = Float64(bytes)
    unit_index = 1

    while value >= 1024 && unit_index < length(units)
        value /= 1024
        unit_index += 1
    end

    if unit_index == 1
        return "$(bytes) $(units[unit_index])"
    end

    return "$(round(value, digits = 2)) $(units[unit_index])"
end

function format_runtime_ms(runtime_ns::Integer)
    return round(runtime_ns / 1_000_000, digits = 2)
end

memory_tracking_supported() = isdefined(Base, :gc_live_bytes)

function read_process_memory()
    if !memory_tracking_supported()
        return nothing
    end

    try
        return Int64(Base.gc_live_bytes())
    catch err
        if err isa InexactError
            return nothing
        end
        rethrow()
    end
end

function reset_memory_tracking!(stats::MiningStats)
    GC.gc()
    stats.peak_working_set_bytes = 0
    stats.memory_baseline_bytes = 0

    sample = read_process_memory()
    if sample === nothing
        return stats
    end

    stats.memory_baseline_bytes = sample
    return stats
end

function sample_memory!(stats::Nothing)
    return nothing
end

function sample_memory!(stats::MiningStats)
    sample = read_process_memory()
    if sample === nothing
        return nothing
    end

    stats.peak_working_set_bytes = max(stats.peak_working_set_bytes, sample)
    return nothing
end

function format_memory_mb(bytes::Int)
    return round(bytes / 1024^2, digits = 2)
end

"""
Read SPMF-style transaction data and remove duplicates inside each transaction.
"""
function read_spmf(path::String)
    transactions = Vector{Vector{Int}}()

    for line in eachline(path)
        items = unique(parse.(Int, split(strip(line))))
        push!(transactions, items)
    end

    return transactions
end

"""
Read mined frequent itemsets from SPMF-like output format.
"""
function read_output(path::String)
    results = Vector{Tuple{Vector{Int},Int}}()

    for line in eachline(path)
        stripped = strip(line)
        isempty(stripped) && continue

        parts = split(stripped, "#SUP:")
        if length(parts) != 2
            println("Invalid output format: $path")
            exit()
        end

        items_part = strip(parts[1])
        support_part = strip(parts[2])
        items = isempty(items_part) ? Int[] : parse.(Int, split(items_part))
        support = parse(Int, support_part)
        push!(results, (items, support))
    end

    return results
end

"""
Write frequent itemsets in SPMF-like output format.
"""
function write_output(path::String, results)
    sort!(results, by = entry -> (length(entry[1]), entry[1]))

    open(path, "w") do io
        for (items, sup) in results
            println(io, "$(join(sort(items), " ")) #SUP: $sup")
        end
    end
end

function ensure_output_dir(path::String)
    isdir(path) || mkpath(path)
    return path
end

function list_input_files(path::String)
    if isfile(path)
        return [path]
    elseif isdir(path)
        files = [joinpath(path, name) for name in readdir(path) if isfile(joinpath(path, name))]
        sort!(files)
        return files
    end

    println("Input path not found: $path")
    exit()
end

function stem_name(path::String)
    return splitext(basename(path))[1]
end

function stats_output_path(output_dir::String, algorithm_name::String, input_file::String, minsup::Float64)
    base = stem_name(input_file)
    minsup_label = replace(string(round(minsup * 100, digits = 2)), "." => "_")
    return joinpath(output_dir, "stats_$(algorithm_name)_$(base)_$(minsup_label).txt")
end

function parse_subset_ratios(text::String)
    ratios = parse.(Float64, split(text, ","))
    isempty(ratios) && error("Subset ratios must not be empty.")

    for ratio in ratios
        if ratio <= 0 || ratio > 1
            error("Invalid subset ratio $ratio. Ratios must be in (0, 1].")
        end
    end

    return ratios
end

function parse_transaction_lengths(text::String)
    lengths = parse.(Int, split(text, ","))
    isempty(lengths) && error("Transaction lengths must not be empty.")

    for length_value in lengths
        if length_value <= 0
            error("Invalid transaction length $length_value. Lengths must be positive.")
        end
    end

    return lengths
end

function parse_cli_args(args)
    if isempty(args)
        println("Usage:")
        println(" Algorithm: classic/fpgrowth, projection/projected_fpgrowth, adjacency/adjacency_fpgrowth")
        println("  julia main.jl -a <algorithm> <input_path> <output_folder> <minsup>")
        println("  julia main.jl -c <alg1> <alg2> <input_file> <output_folder> <minsup>")
        println("  julia main.jl -ca <input_file> <output_folder> <minsup>")
        println("  julia main.jl -b <algorithm> <input_file> <output_folder> <minsup>")
        println("  julia main.jl -s <input_file> <output_folder> [ratios] [seed] [sampling]")
        println("  julia main.jl -tl <output_folder> [num_transactions] [num_items] [lengths]")
        exit()
    end

    mode = args[1]

    if mode == "-a" && length(args) == 5
        return (mode = mode, algorithm = args[2], input_path = args[3], output_path = args[4], minsup = parse(Float64, args[5]))
    elseif mode == "-c" && length(args) == 6
        return (mode = mode, algorithm1 = args[2], algorithm2 = args[3], input_path = args[4], output_path = args[5], minsup = parse(Float64, args[6]))
    elseif mode == "-ca" && length(args) == 4
        return (mode = mode, input_path = args[2], output_path = args[3], minsup = parse(Float64, args[4]))
    elseif mode == "-b" && length(args) == 5
        return (mode = mode, algorithm = args[2], input_path = args[3], output_path = args[4], minsup = parse(Float64, args[5]))
    elseif mode == "-s" && 3 <= length(args) <= 6
        ratios = length(args) >= 4 ? parse_subset_ratios(args[4]) : DEFAULT_SUBSET_RATIOS
        seed = length(args) >= 5 ? parse(Int, args[5]) : DEFAULT_SUBSET_SEED
        sampling = length(args) >= 6 ? lowercase(args[6]) : DEFAULT_SUBSET_SAMPLING

        if !(sampling in ("independent", "prefix"))
            println("Invalid sampling mode: $sampling")
            println("Available sampling modes: independent, prefix")
            exit()
        end

        return (mode = mode, input_path = args[2], output_path = args[3], ratios = ratios, seed = seed, sampling = sampling)
    elseif mode == "-tl" && 2 <= length(args) <= 5
        transaction_count = length(args) >= 3 ? parse(Int, args[3]) : DEFAULT_TRANSACTION_LENGTH_COUNT
        item_count = length(args) >= 4 ? parse(Int, args[4]) : DEFAULT_TRANSACTION_LENGTH_ITEMS
        lengths = length(args) >= 5 ? parse_transaction_lengths(args[5]) : DEFAULT_TRANSACTION_LENGTHS

        if transaction_count <= 0
            println("Invalid number of transactions: $transaction_count")
            exit()
        end

        if item_count <= 0
            println("Invalid number of items: $item_count")
            exit()
        end

        if maximum(lengths) > item_count
            println("Maximum transaction length must be <= number of items.")
            exit()
        end

        return (
            mode = mode,
            output_path = args[2],
            transaction_count = transaction_count,
            item_count = item_count,
            transaction_lengths = lengths,
        )
    end

    println("Invalid arguments.")
    println("Usage:")
    println("  julia main.jl -a <algorithm> <input_path> <output_folder> <minsup>")
    println("  julia main.jl -c <alg1> <alg2> <input_file> <output_folder> <minsup>")
    println("  julia main.jl -ca <input_file> <output_folder> <minsup>")
    println("  julia main.jl -b <algorithm> <input_file> <output_folder> <minsup>")
    println("  julia main.jl -s <input_file> <output_folder> [ratios] [seed] [sampling]")
    println("  julia main.jl -tl <output_folder> [num_transactions] [num_items] [lengths]")
    exit()
end

function write_benchmark_output(
    path::String,
    system_name::String,
    system_results,
    local_name::String,
    local_results,
    patterns_equal::Bool,
    input_file::String,
    minsup_label::String,
)
    open(path, "w") do io
        println(io, "input_file=$input_file")
        println(io, "minsup=$minsup_label")
        println(io, "system_output=$system_name")
        println(io, "system_patterns=$(length(system_results))")
        println(io, "local_output=$local_name")
        println(io, "local_patterns=$(length(local_results))")
        println(io, "patterns_equal=$patterns_equal")
    end
end

function write_stats_output(path::String, algorithm_name::String, stats::MiningStats, input_file::String, minsup::Float64)
    open(path, "w") do io
        println(io, "algorithm=$algorithm_name")
        println(io, "input_file=$input_file")
        println(io, "minsup=$minsup")
        println(io, "transactions=$(stats.transaction_count)")
        println(io, "patterns=$(stats.frequent_itemset_count)")
        println(io, "runtime_ns=$(stats.runtime_ns)")
        println(io, "nodes=$(stats.node_count)")
        println(io, "trees=$(stats.tree_count)")
        println(io, "conditional_trees=$(stats.conditional_tree_count)")
        println(io, "projections=$(stats.projection_count)")
        println(io, "memory_baseline_bytes=$(stats.memory_baseline_bytes)")
        println(io, "peak_working_set_bytes=$(stats.peak_working_set_bytes)")
    end
end

function read_stats_output(path::String)
    stats = Dict{String,String}()

    for line in eachline(path)
        stripped = strip(line)
        isempty(stripped) && continue
        parts = split(stripped, "=", limit = 2)
        length(parts) == 2 || continue
        stats[parts[1]] = parts[2]
    end

    return stats
end

function print_benchmark_summary(
    system_name::String,
    system_results,
    local_name::String,
    local_results,
    patterns_equal::Bool,
    input_file::String,
    minsup_label::String,
)
    println(repeat("=", 40))
    println("Benchmark file: $input_file")
    println("Minimum support: $minsup_label")
    println("System output: $system_name")
    println("System patterns: $(length(system_results))")
    println("Local output: $local_name")
    println("Local patterns: $(length(local_results))")
    println("Patterns equal: $patterns_equal")
    println(repeat("=", 40))
end

function print_comparison_summary(left::Dict{String,String}, right::Dict{String,String})
    println(repeat("=", 40))
    println("Comparison file: $(left["input_file"])")
    println("Minimum support: $(left["minsup"])")
    println("Algorithm 1: $(left["algorithm"])")
    println("  Transactions count from database : $(left["transactions"])")
    println("  Max memory usage: $(format_memory(parse(Int64, left["peak_working_set_bytes"])))")
    println("  Frequent itemsets count : $(left["patterns"])")
    println("  Total time ~ $(format_runtime_ms(parse(Int64, left["runtime_ns"]))) ms")
    println("Algorithm 2: $(right["algorithm"])")
    println("  Transactions count from database : $(right["transactions"])")
    println("  Max memory usage: $(format_memory(parse(Int64, right["peak_working_set_bytes"])))")
    println("  Frequent itemsets count : $(right["patterns"])")
    println("  Total time ~ $(format_runtime_ms(parse(Int64, right["runtime_ns"]))) ms")
    println(repeat("=", 40))
end

function print_algorithm_summary(algorithm_name::String, results, stats, input_file::String, minsup)
    println(repeat("=", 40))
    println("Algorithm: $algorithm_name")
    println("file: $input_file")
    println("Transactions count from database : $(stats.transaction_count)")
    if stats.peak_working_set_bytes > 0
        println("Max memory usage: $(format_memory(stats.peak_working_set_bytes))")
    else
        println("Max memory usage: n/a")
    end
    println("Frequent itemsets count : $(stats.frequent_itemset_count)")
    println("Total time ~ $(format_runtime_ms(stats.runtime_ns)) ms")
    println("Nodes: $(stats.node_count)")
    println("Trees: $(stats.tree_count)")
    println("Conditional trees: $(stats.conditional_tree_count)")
    println("Projections: $(stats.projection_count)")
    if stats.peak_working_set_bytes > 0
        println("Peak RAM (MB): $(format_memory_mb(stats.peak_working_set_bytes))")
    else
        println("Peak RAM (MB): n/a")
    end
    println("Minimum support: $minsup")
    println(repeat("=", 40))
end

end
