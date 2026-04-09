module ProjectionFPGrowth

using ..Structures
using ..Utils: reset_memory_tracking!, sample_memory!
using ..FPGrowth: build_fptree, mine_tree

export run_projection_fpgrowth, frequent_items, build_projection_database

function frequent_items(transactions, minsup)
    freq = Dict{Int,Int}()

    for transaction in transactions
        for item in transaction
            freq[item] = get(freq, item, 0) + 1
        end
    end

    freq = Dict(item => support for (item, support) in freq if support >= minsup)
    ordered_items = sort(collect(keys(freq)), by = item -> (-freq[item], item))
    order = Dict(item => index for (index, item) in enumerate(ordered_items))

    return freq, ordered_items, order
end

function normalize_transaction(transaction, order)
    items = [item for item in transaction if haskey(order, item)]
    sort!(items, by = item -> order[item])
    return items
end

function build_projection_database(transactions, target_item, order)
    build_projection_database(transactions, target_item, order, nothing)
end

function build_projection_database(transactions, target_item, order, stats::Union{MiningStats,Nothing})
    sample_memory!(stats)
    projection = Vector{Vector{Int}}()
    target_rank = order[target_item]

    for (index, transaction) in enumerate(transactions)
        if !(target_item in transaction)
            continue
        end

        ordered = normalize_transaction(transaction, order)
        prefix = [item for item in ordered if order[item] < target_rank]

        if !isempty(prefix)
            push!(projection, prefix)
        end

        if stats !== nothing && index % 256 == 0
            sample_memory!(stats)
        end
    end

    sample_memory!(stats)
    return projection
end

function deduplicate_results(results)
    merged = Dict{Tuple{Vararg{Int}},Int}()

    for (items, support) in results
        key = Tuple(sort(items))
        merged[key] = max(get(merged, key, 0), support)
    end

    normalized = [(collect(items), support) for (items, support) in merged]
    sort!(normalized, by = entry -> (length(entry[1]), entry[1]))
    return normalized
end

function run_projection_fpgrowth(transactions, minsup)
    stats = MiningStats()
    results = Vector{Tuple{Vector{Int},Int}}()
    stats.transaction_count = length(transactions)
    minsup = max(1, round(Int, minsup * length(transactions)))
    reset_memory_tracking!(stats)

    elapsed = @elapsed begin
        sample_memory!(stats)
        global_support, ordered_items, order = frequent_items(transactions, minsup)
        sample_memory!(stats)

        for (index, item) in enumerate(ordered_items)
            push!(results, ([item], global_support[item]))
            stats.frequent_itemset_count += 1

            if index == 1
                continue
            end

            projection_db = build_projection_database(transactions, item, order, stats)
            stats.projection_count += 1

            if isempty(projection_db)
                continue
            end

            tree = build_fptree(projection_db, minsup, stats)
            if tree == nothing
                continue
            end

            stats.conditional_tree_count += 1
            mine_tree(tree, [item], results, minsup, stats)
            sample_memory!(stats)
        end

        sample_memory!(stats)
    end

    stats.runtime_ns = round(Int64, elapsed * 1_000_000_000)
    results = deduplicate_results(results)
    stats.frequent_itemset_count = length(results)
    return results, stats
end

end
