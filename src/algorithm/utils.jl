module Utils

export ensure_output_dir, list_input_files, parse_cli_args, read_spmf, stem_name, write_compare_output, write_output, print_algorithm_summary, print_compare_summary

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

function parse_cli_args(args)
    if isempty(args)
        println("Usage:")
        println(" Algorithm: classic/fpgrowth, projection/projected_fpgrowth, adjacency/adjacency_fpgrowth")
        println("  julia main.jl -a <algorithm> <input_path> <output_folder> <minsup>")
        println("  julia main.jl -c <alg1> <alg2> <input_file> <output_folder> <minsup>")
        println("  julia main.jl -ca <input_file> <output_folder> <minsup>")
        exit()
    end

    mode = args[1]

    if mode == "-a" && length(args) == 5
        return (mode = mode, algorithm = args[2], input_path = args[3], output_path = args[4], minsup = parse(Int, args[5]))
    elseif mode == "-c" && length(args) == 6
        return (mode = mode, algorithm1 = args[2], algorithm2 = args[3], input_path = args[4], output_path = args[5], minsup = parse(Int, args[6]))
    elseif mode == "-ca" && length(args) == 4
        return (mode = mode, input_path = args[2], output_path = args[3], minsup = parse(Int, args[4]))
    end

    println("Invalid arguments.")
    println("Usage:")
    println("  julia main.jl -a <algorithm> <input_path> <output_folder> <minsup>")
    println("  julia main.jl -c <alg1> <alg2> <input_file> <output_folder> <minsup>")
    println("  julia main.jl -ca <input_file> <output_folder> <minsup>")
    exit()
end

# function write_compare_output(
#     path::String,
#     alg1_name::String,
#     alg1_results,
#     alg1_stats,
#     alg2_name::String,
#     alg2_results,
#     alg2_stats,
#     patterns_equal::Bool,
#     minsup::Int,
#     input_file::String,
# )
#     open(path, "w") do io
#         println(io, "input_file=$input_file")
#         println(io, "minsup=$minsup")
#         println(io, "$(alg1_name)_patterns=$(length(alg1_results))")
#         println(io, "$(alg1_name)_runtime_ns=$(alg1_stats.runtime_ns)")
#         println(io, "$(alg1_name)_nodes=$(alg1_stats.node_count)")
#         println(io, "$(alg1_name)_trees=$(alg1_stats.tree_count)")
#         println(io, "$(alg1_name)_conditional_trees=$(alg1_stats.conditional_tree_count)")
#         println(io, "$(alg1_name)_projections=$(alg1_stats.projection_count)")
#         println(io, "$(alg2_name)_patterns=$(length(alg2_results))")
#         println(io, "$(alg2_name)_runtime_ns=$(alg2_stats.runtime_ns)")
#         println(io, "$(alg2_name)_nodes=$(alg2_stats.node_count)")
#         println(io, "$(alg2_name)_trees=$(alg2_stats.tree_count)")
#         println(io, "$(alg2_name)_conditional_trees=$(alg2_stats.conditional_tree_count)")
#         println(io, "$(alg2_name)_projections=$(alg2_stats.projection_count)")
#         println(io, "patterns_equal=$patterns_equal")
#     end
# end

# function print_compare_summary(
#     alg1_name::String,
#     alg1_results,
#     alg1_stats,
#     alg2_name::String,
#     alg2_results,
#     alg2_stats,
#     patterns_equal::Bool,
#     minsup::Int,
#     input_file::String,
# )
#     println("Input file: $input_file")
#     println("Minimum support: $minsup")
#     println(repeat("=", 40))
#     println("Algorithm: $alg1_name")
#     println("Patterns: $(length(alg1_results))")
#     println("Runtime (ns): $(alg1_stats.runtime_ns)")
#     println("Nodes: $(alg1_stats.node_count)")
#     println("Trees: $(alg1_stats.tree_count)")
#     println("Conditional trees: $(alg1_stats.conditional_tree_count)")
#     println("Projections: $(alg1_stats.projection_count)")
#     println(repeat("=", 40))
#     println("Algorithm: $alg2_name")
#     println("Patterns: $(length(alg2_results))")
#     println("Runtime (ns): $(alg2_stats.runtime_ns)")
#     println("Nodes: $(alg2_stats.node_count)")
#     println("Trees: $(alg2_stats.tree_count)")
#     println("Conditional trees: $(alg2_stats.conditional_tree_count)")
#     println("Projections: $(alg2_stats.projection_count)")
#     println("Patterns equal: $patterns_equal")
# end

function print_algorithm_summary(algorithm_name::String, results, stats, input_file::String, minsup::Int)
    println(repeat("=", 40))
    println("Algorithm: $algorithm_name")
    println("file: $input_file")
    println("Patterns: $(length(results))")
    println("Runtime (ns): $(stats.runtime_ns)")
    println("Nodes: $(stats.node_count)")
    println("Trees: $(stats.tree_count)")
    println("Conditional trees: $(stats.conditional_tree_count)")
    println("Projections: $(stats.projection_count)")
    println("Minimum support: $minsup")
    println(repeat("=", 40))
end

end
