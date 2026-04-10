module RetailSubsetSplitter

using Random

export split_database_subsets, run_split_cli

const DEFAULT_INPUT_FILE = normpath(joinpath(@__DIR__, "..", "dataset", "retail.txt"))
const DEFAULT_OUTPUT_DIR = normpath(joinpath(@__DIR__, "..", "dataset", "retail_subsets"))
const DEFAULT_RATIOS = [0.10, 0.25, 0.50, 0.75, 1.00]
const DEFAULT_RANDOM_SEED = 2026
const DEFAULT_SAMPLING = "independent"

function print_usage()
    println("Usage:")
    println("  julia src/experiment/split_retail_subsets.jl [input_file] [output_dir] [ratios] [seed] [sampling]")
    println("")
    println("Defaults:")
    println("  input_file : $DEFAULT_INPUT_FILE")
    println("  output_dir : $DEFAULT_OUTPUT_DIR")
    println("  ratios     : 0.10,0.25,0.50,0.75,1.00")
    println("  seed       : $DEFAULT_RANDOM_SEED")
    println("  sampling   : $DEFAULT_SAMPLING")
    println("")
    println("Sampling modes:")
    println("  independent : each subset is sampled independently, so files are not nested")
    println("  prefix      : subsets are nested prefixes after one deterministic shuffle")
end

function parse_ratios(text::String)
    ratios = parse.(Float64, split(text, ","))
    isempty(ratios) && error("Ratios must not be empty.")

    for ratio in ratios
        if ratio <= 0 || ratio > 1
            error("Invalid ratio $ratio. Ratios must be in (0, 1].")
        end
    end

    return ratios
end

function parse_split_cli_args(args)
    if !isempty(args) && (args[1] == "-h" || args[1] == "--help")
        print_usage()
        exit()
    end

    if length(args) > 5
        print_usage()
        error("Too many arguments.")
    end

    input_file = length(args) >= 1 ? args[1] : DEFAULT_INPUT_FILE
    output_dir = length(args) >= 2 ? args[2] : DEFAULT_OUTPUT_DIR
    ratios = length(args) >= 3 ? parse_ratios(args[3]) : DEFAULT_RATIOS
    seed = length(args) >= 4 ? parse(Int, args[4]) : DEFAULT_RANDOM_SEED
    sampling = length(args) >= 5 ? lowercase(args[5]) : DEFAULT_SAMPLING

    if !(sampling in ("independent", "prefix"))
        error("Invalid sampling mode: $sampling. Use independent or prefix.")
    end

    return (
        input_file = normpath(input_file),
        output_dir = normpath(output_dir),
        ratios = ratios,
        seed = seed,
        sampling = sampling,
    )
end

function read_transaction_lines(path::String)
    transactions = String[]

    open(path, "r") do io
        for line in eachline(io)
            stripped = strip(line)
            isempty(stripped) && continue
            push!(transactions, stripped)
        end
    end

    return transactions
end

function subset_size(total_transactions::Int, ratio::Float64)
    ratio == 1.0 && return total_transactions
    return max(1, floor(Int, total_transactions * ratio))
end

function ratio_label(ratio::Float64)
    return "$(round(Int, ratio * 100))pct"
end

function sample_independent_subset(transactions::Vector{String}, count::Int, seed::Int)
    count == length(transactions) && return copy(transactions)

    rng = MersenneTwister(seed)
    selected_indices = sort(randperm(rng, length(transactions))[1:count])
    return transactions[selected_indices]
end

function shuffled_transactions(transactions::Vector{String}, seed::Int)
    rng = MersenneTwister(seed)
    shuffled = copy(transactions)
    shuffle!(rng, shuffled)
    return shuffled
end

function write_subset(path::String, transactions::Vector{String})
    open(path, "w") do io
        for transaction in transactions
            println(io, transaction)
        end
    end
end

function split_database_subsets(
    input_file::String,
    output_dir::String,
    ratios::Vector{Float64},
    seed::Int,
    sampling::String,
)
    if !isfile(input_file)
        error("Input file not found: $input_file")
    end

    if !(sampling in ("independent", "prefix"))
        error("Invalid sampling mode: $sampling. Use independent or prefix.")
    end

    mkpath(output_dir)

    transactions = read_transaction_lines(input_file)
    total_transactions = length(transactions)
    prefix_transactions = sampling == "prefix" ? shuffled_transactions(transactions, seed) : String[]
    base = splitext(basename(input_file))[1]

    println("Input file: $input_file")
    println("Total transactions: $total_transactions")
    println("Output directory: $output_dir")
    println("Ratios: $(join(ratios, ","))")
    println("Subset sampling: $sampling")
    println("Random seed: $seed")

    for (ratio_index, ratio) in enumerate(ratios)
        count = subset_size(total_transactions, ratio)
        label = ratio_label(ratio)
        filename = "$(base)_$(label).txt"
        output_path = joinpath(output_dir, filename)

        subset = if sampling == "independent"
            sample_independent_subset(transactions, count, seed + ratio_index)
        else
            prefix_transactions[1:count]
        end

        write_subset(output_path, subset)
        println("Created $filename with $count transactions")
    end
end

function run_split_cli(args = ARGS)
    config = parse_split_cli_args(args)
    split_database_subsets(
        config.input_file,
        config.output_dir,
        config.ratios,
        config.seed,
        config.sampling,
    )
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    run_split_cli(ARGS)
end

end
