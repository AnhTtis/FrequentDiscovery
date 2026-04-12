module Utils

using ..Structures: MiningStats

export ensure_output_dir, list_input_files, parse_cli_args, read_spmf, read_output, read_stats_output, resolve_existing_file, stem_name, stats_output_path, compare_output_results, write_output, write_stats_output, print_algorithm_summary, print_output_comparison_summary, print_comparison_summary, reset_memory_tracking!, sample_memory!, memory_tracking_supported

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

function resolve_existing_file(path::String, base_dir::String="")
    if isfile(path)
        return path
    end

    if !isempty(base_dir)
        candidate = joinpath(base_dir, path)
        if isfile(candidate)
            return candidate
        end
    end

    println("File not found: $path")
    if !isempty(base_dir)
        println("Checked in output folder: $(joinpath(base_dir, path))")
    end
    exit()
end

function stats_output_path(output_dir::String, algorithm_name::String, input_file::String, minsup::Float64)
    base = stem_name(input_file)
    minsup_label = replace(string(round(minsup * 100, digits = 2)), "." => "_")
    return joinpath(output_dir, "stats_$(algorithm_name)_$(base)_$(minsup_label).txt")
end

function print_usage()
    println("Usage:")
    println(" Algorithm: classic/fpgrowth, projection/projected_fpgrowth, adjacency/adjacency_fpgrowth")
    println("  julia main.jl -a <algorithm> <input_path> <output_folder> <minsup>")
    println("  julia main.jl -c <alg1> <alg2> <input_file> <output_folder> <minsup>")
    println("  julia main.jl -ca <input_file> <output_folder> <minsup>")
    println("  julia main.jl -b <output_file1> <output_file2> <output_folder>")
end

function parse_cli_args(args)
    if isempty(args)
        print_usage()
        exit()
    end

    mode = args[1]

    if mode == "-a" && length(args) == 5
        return (mode = mode, algorithm = args[2], input_path = args[3], output_path = args[4], minsup = parse(Float64, args[5]))
    elseif mode == "-c" && length(args) == 6
        return (mode = mode, algorithm1 = args[2], algorithm2 = args[3], input_path = args[4], output_path = args[5], minsup = parse(Float64, args[6]))
    elseif mode == "-ca" && length(args) == 4
        return (mode = mode, input_path = args[2], output_path = args[3], minsup = parse(Float64, args[4]))
    elseif mode == "-b" && length(args) == 4
        return (mode = mode, output_file1 = args[2], output_file2 = args[3], output_path = args[4])
    end

    println("Invalid arguments.")
    print_usage()
    exit()
end

function write_stats_output(path::String, algorithm_name::String, stats::MiningStats, input_file::String, minsup::Float64)
    open(path, "w") do io
        println(io, "algorithm=$algorithm_name")
        println(io, "input_file=$input_file")
        println(io, "minsup=$minsup")
        println(io, "transactions=$(stats.transaction_count)")
        println(io, "frequent itemsets=$(stats.frequent_itemset_count)")
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

function compare_output_results(output_file1::String, output_file2::String, base_dir::String="")
    resolved_file1 = resolve_existing_file(output_file1, base_dir)
    resolved_file2 = resolve_existing_file(output_file2, base_dir)

    canonical_file1 = Dict(Tuple(sort(items)) => support for (items, support) in read_output(resolved_file1))
    canonical_file2 = Dict(Tuple(sort(items)) => support for (items, support) in read_output(resolved_file2))

    keys1 = Set(keys(canonical_file1))
    keys2 = Set(keys(canonical_file2))
    shared_keys = intersect(keys1, keys2)

    exact_match_count = count(key -> canonical_file1[key] == canonical_file2[key], shared_keys)

    return (
        output_file1 = resolved_file1,
        output_file2 = resolved_file2,
        output_file1_count = length(canonical_file1),
        output_file2_count = length(canonical_file2),
        exact_match_count = exact_match_count,
        support_mismatch_count = length(shared_keys) - exact_match_count,
        only_file1_count = length(setdiff(keys1, keys2)),
        only_file2_count = length(setdiff(keys2, keys1)),
    )
end

function format_percentage(numerator::Integer, denominator::Integer)
    if denominator == 0
        return "100.0%"
    end

    return "$(round(numerator / denominator * 100, digits = 2))%"
end

function print_output_comparison_summary(comparison)
    print_output_comparison_summary(stdout, comparison)
end

function print_output_comparison_summary(io::IO, comparison)
    patterns_equal =
        comparison.support_mismatch_count == 0 &&
        comparison.only_file1_count == 0 &&
        comparison.only_file2_count == 0 &&
        comparison.output_file1_count == comparison.output_file2_count

    println(io, repeat("=", 40))
    println(io, "Output file 1 (current): $(basename(comparison.output_file1))")
    println(io, "Output file 2 (system): $(basename(comparison.output_file2))")
    println(io, "Itemsets in file 1: $(comparison.output_file1_count)")
    println(io, "Itemsets in file 2: $(comparison.output_file2_count)")
    println(io, "Exact matches (same itemset + same support): $(comparison.exact_match_count)")
    println(io, "Match rate vs file 1: $(format_percentage(comparison.exact_match_count, comparison.output_file1_count))")
    println(io, "Match rate vs file 2: $(format_percentage(comparison.exact_match_count, comparison.output_file2_count))")
    println(io, "Support mismatches on shared itemsets: $(comparison.support_mismatch_count)")
    println(io, "Only in file 1: $(comparison.only_file1_count)")
    println(io, "Only in file 2: $(comparison.only_file2_count)")
    println(io, "Outputs identical: $patterns_equal")
    println(io, repeat("=", 40))
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

function print_algorithm_summary(algorithm_name::String, stats, input_file::String, minsup)
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
    println("Minimum support: $minsup")
    println(repeat("=", 40))
end

end
