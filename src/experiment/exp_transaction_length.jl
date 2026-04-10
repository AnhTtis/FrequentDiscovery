module TransactionLengthExperiment

using Random

export generate_transaction_length_datasets, run_transaction_length_cli

const DEFAULT_OUTPUT_DIR = normpath(joinpath(@__DIR__, "transaction_length"))
const DEFAULT_TRANSACTION_COUNT = 1000
const DEFAULT_ITEM_COUNT = 100
const DEFAULT_AVG_LENGTHS = [5, 10, 20, 30, 50]

function print_usage()
    println("Usage:")
    println("  julia src/experiment/exp_transaction_length.jl [output_dir] [num_transactions] [num_items] [lengths]")
    println("")
    println("Defaults:")
    println("  output_dir       : $DEFAULT_OUTPUT_DIR")
    println("  num_transactions : $DEFAULT_TRANSACTION_COUNT")
    println("  num_items        : $DEFAULT_ITEM_COUNT")
    println("  lengths          : 5,10,20,30,50")
    println("")
    println("Example:")
    println("  julia src/experiment/exp_transaction_length.jl src/experiment/transaction_length 1000 100 5,10,20,30,50")
end

function parse_lengths(text::String)
    lengths = parse.(Int, split(text, ","))
    isempty(lengths) && error("Lengths must not be empty.")

    for length_value in lengths
        if length_value <= 0
            error("Invalid transaction length $length_value. Lengths must be positive.")
        end
    end

    return lengths
end

function parse_cli_args(args)
    if !isempty(args) && (args[1] == "-h" || args[1] == "--help")
        print_usage()
        exit()
    end

    if length(args) > 4
        print_usage()
        error("Too many arguments.")
    end

    output_dir = length(args) >= 1 ? args[1] : DEFAULT_OUTPUT_DIR
    num_transactions = length(args) >= 2 ? parse(Int, args[2]) : DEFAULT_TRANSACTION_COUNT
    num_items = length(args) >= 3 ? parse(Int, args[3]) : DEFAULT_ITEM_COUNT
    lengths = length(args) >= 4 ? parse_lengths(args[4]) : DEFAULT_AVG_LENGTHS

    if num_transactions <= 0
        error("Number of transactions must be positive.")
    end

    if num_items <= 0
        error("Number of items must be positive.")
    end

    if maximum(lengths) > num_items
        error("Maximum transaction length must be <= number of items to keep each transaction unique.")
    end

    return (
        output_dir = normpath(output_dir),
        num_transactions = num_transactions,
        num_items = num_items,
        lengths = lengths,
    )
end

function random_transaction(rng, num_items::Int, avg_len::Int)
    min_len = max(1, div(avg_len, 2))
    max_len = min(num_items, avg_len * 2)
    len = rand(rng, min_len:max_len)
    items = sort(randperm(rng, num_items)[1:len])
    return items
end

function generate_dataset(path::String, num_transactions::Int, num_items::Int, avg_len::Int)
    open(path, "w") do io
        for _ in 1:num_transactions
            items = random_transaction(Random.default_rng(), num_items, avg_len)
            println(io, join(items, " "))
        end
    end
end

function generate_transaction_length_datasets(
    output_dir::String,
    num_transactions::Int = DEFAULT_TRANSACTION_COUNT,
    num_items::Int = DEFAULT_ITEM_COUNT,
    lengths::Vector{Int} = DEFAULT_AVG_LENGTHS,
)
    if num_transactions <= 0
        error("Number of transactions must be positive.")
    end

    if num_items <= 0
        error("Number of items must be positive.")
    end

    if isempty(lengths)
        error("Lengths must not be empty.")
    end

    if maximum(lengths) > num_items
        error("Maximum transaction length must be <= number of items to keep each transaction unique.")
    end

    mkpath(output_dir)

    println("Output directory: $output_dir")
    println("Transactions per dataset: $num_transactions")
    println("Items: $num_items")
    println("Average lengths: $(join(lengths, ","))")

    for avg_len in lengths
        output_file = joinpath(output_dir, "data_L$(avg_len).txt")
        generate_dataset(output_file, num_transactions, num_items, avg_len)
        println("Created $(basename(output_file)) with avg length $avg_len")
    end
end

function run_transaction_length_cli(args = ARGS)
    config = parse_cli_args(args)
    generate_transaction_length_datasets(
        config.output_dir,
        config.num_transactions,
        config.num_items,
        config.lengths,
    )
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    run_transaction_length_cli(ARGS)
end

end
