module TransactionLengthExperiment

using Random

export generate_transaction_length_datasets, run_transaction_length_cli

const DEFAULT_OUTPUT_DIR = normpath(joinpath(@__DIR__, "transaction_length"))
const DEFAULT_TRANSACTION_COUNT = 1000
const DEFAULT_ITEM_COUNT = 100
const DEFAULT_ITEM_RANGE = 1:DEFAULT_ITEM_COUNT
const DEFAULT_TRANSACTION_LENGTHS = [5, 10, 20, 30, 50]

function print_usage()
    println("Usage:")
    println("  julia src/experiment/exp_transaction_length.jl [output_dir] [num_transactions] [num_items_or_range] [lengths]")
    println("")
    println("Defaults:")
    println("  output_dir       : $DEFAULT_OUTPUT_DIR")
    println("  num_transactions : $DEFAULT_TRANSACTION_COUNT")
    println("  num_items/range  : 1:$DEFAULT_ITEM_COUNT")
    println("  lengths          : 5,10,20,30,50")
    println("")
    println("Example:")
    println("  julia src/experiment/exp_transaction_length.jl src/experiment/transaction_length 1000 100 5,10,20,30,50")
    println("  julia src/experiment/exp_transaction_length.jl src/experiment/transaction_length 1000 50:200 5,10,20,30,50")
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

function parse_item_range(text::String)
    if occursin(":", text)
        bounds = split(text, ":", limit = 2)
        length(bounds) == 2 || error("Invalid item range: $text. Use start:end.")

        start_item = parse(Int, strip(bounds[1]))
        end_item = parse(Int, strip(bounds[2]))

        if start_item > end_item
            error("Invalid item range: $text. Start must be <= end.")
        end

        return start_item:end_item
    end

    item_count = parse(Int, text)
    item_count > 0 || error("Number of items must be positive.")
    return 1:item_count
end

function format_item_range(item_range::UnitRange{Int})
    return "$(first(item_range)):$(last(item_range))"
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
    item_range = length(args) >= 3 ? parse_item_range(args[3]) : DEFAULT_ITEM_RANGE
    lengths = length(args) >= 4 ? parse_lengths(args[4]) : DEFAULT_TRANSACTION_LENGTHS

    if num_transactions <= 0
        error("Number of transactions must be positive.")
    end

    if maximum(lengths) > length(item_range)
        error("Maximum transaction length $(maximum(lengths)) exceeds available items $(length(item_range)) in range $(format_item_range(item_range)).")
    end

    return (
        output_dir = normpath(output_dir),
        num_transactions = num_transactions,
        item_range = item_range,
        lengths = lengths,
    )
end

function random_transaction(rng, item_values::Vector{Int}, transaction_len::Int)
    selected_indices = sort(randperm(rng, length(item_values))[1:transaction_len])
    return item_values[selected_indices]
end

function generate_dataset(path::String, num_transactions::Int, item_range::UnitRange{Int}, transaction_len::Int)
    rng = Random.default_rng()
    item_values = collect(item_range)

    open(path, "w") do io
        for _ in 1:num_transactions
            items = random_transaction(rng, item_values, transaction_len)
            println(io, join(items, " "))
        end
    end
end

function generate_transaction_length_datasets(
    output_dir::String,
    num_transactions::Int = DEFAULT_TRANSACTION_COUNT,
    item_range::UnitRange{Int} = DEFAULT_ITEM_RANGE,
    lengths::Vector{Int} = DEFAULT_TRANSACTION_LENGTHS,
)
    if num_transactions <= 0
        error("Number of transactions must be positive.")
    end

    if isempty(lengths)
        error("Lengths must not be empty.")
    end

    if maximum(lengths) > length(item_range)
        error("Maximum transaction length $(maximum(lengths)) exceeds available items $(length(item_range)) in range $(format_item_range(item_range)).")
    end

    mkpath(output_dir)

    println("Output directory: $output_dir")
    println("Transactions per dataset: $num_transactions")
    println("Item range: $(format_item_range(item_range))")
    println("Available items: $(length(item_range))")
    println("Transaction lengths: $(join(lengths, ","))")

    for transaction_len in lengths
        output_file = joinpath(output_dir, "data_L$(transaction_len).txt")
        generate_dataset(output_file, num_transactions, item_range, transaction_len)
        println("Created $(basename(output_file)) with transaction length $transaction_len")
    end
end

function run_transaction_length_cli(args = ARGS)
    config = parse_cli_args(args)
    generate_transaction_length_datasets(
        config.output_dir,
        config.num_transactions,
        config.item_range,
        config.lengths,
    )
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    run_transaction_length_cli(ARGS)
end

end
