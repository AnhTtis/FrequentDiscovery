module ProjectionFPGrowth

using ..Structures
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
    projection = Vector{Vector{Int}}()
    target_rank = order[target_item]

    for transaction in transactions
        if !(target_item in transaction)
            continue
        end

        ordered = normalize_transaction(transaction, order)
        prefix = [item for item in ordered if order[item] < target_rank]

        if !isempty(prefix)
            push!(projection, prefix)
        end
    end

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

    elapsed = @elapsed begin
        global_support, ordered_items, order = frequent_items(transactions, minsup)

        for (index, item) in enumerate(ordered_items)
            push!(results, ([item], global_support[item]))

            if index == 1
                continue
            end

            projection_db = build_projection_database(transactions, item, order)
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
        end
    end

    stats.runtime_ns = round(Int, elapsed * 1_000_000_000)
    return deduplicate_results(results), stats
end

end
