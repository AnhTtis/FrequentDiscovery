module AdjacencyFPGrowth

using ..Structures
using ..Utils: reset_memory_tracking!, sample_memory!

export run_adjacency_fpgrowth

function add_edge!(adjacency::Dict{Int,Dict{Int,Int}}, left::Int, right::Int)
    neighbors = get!(adjacency, left, Dict{Int,Int}())
    neighbors[right] = get(neighbors, right, 0) + 1
end

function build_adjacency_index(transactions, minsup, stats::MiningStats)
    sample_memory!(stats)
    item_support = Dict{Int,Int}()
    item_tidsets = Dict{Int,BitSet}()
    adjacency = Dict{Int,Dict{Int,Int}}()

    for (tid, transaction) in enumerate(transactions)
        items = sort!(unique(transaction))

        for item in items
            item_support[item] = get(item_support, item, 0) + 1
            push!(get!(item_tidsets, item, BitSet()), tid)
        end

        if length(items) > 1
            for i in 1:(length(items) - 1)
                left = items[i]
                for j in (i + 1):length(items)
                    right = items[j]
                    add_edge!(adjacency, left, right)
                    add_edge!(adjacency, right, left)
                end
            end
        end

        if tid % 128 == 0
            sample_memory!(stats)
        end
    end

    frequent_support = Dict(item => support for (item, support) in item_support if support >= minsup)
    frequent_items = sort(collect(keys(frequent_support)))

    filtered_tidsets = Dict(item => item_tidsets[item] for item in frequent_items)
    filtered_adjacency = Dict{Int,Dict{Int,Int}}()

    for item in frequent_items
        neighbors = get(adjacency, item, Dict{Int,Int}())
        kept = Dict{Int,Int}()

        for (neighbor, support) in neighbors
            if haskey(frequent_support, neighbor) && support >= minsup
                kept[neighbor] = support
            end
        end

        filtered_adjacency[item] = kept
        stats.node_count += length(kept)
    end

    sample_memory!(stats)
    return frequent_support, filtered_tidsets, filtered_adjacency
end

function extend_patterns!(
    prefix::Vector{Int},
    prefix_tidset::BitSet,
    candidates::Vector{Int},
    item_tidsets::Dict{Int,BitSet},
    adjacency::Dict{Int,Dict{Int,Int}},
    minsup::Int,
    results::Vector{Tuple{Vector{Int},Int}},
    stats::MiningStats,
)
    sample_memory!(stats)
    for (index, item) in enumerate(candidates)
        support_tidset = intersect(prefix_tidset, item_tidsets[item])
        support = length(support_tidset)

        if support < minsup
            continue
        end

        pattern = vcat(prefix, item)
        push!(results, (pattern, support))
        stats.frequent_itemset_count += 1

        remaining = candidates[index + 1:end]
        next_candidates = Int[]
        item_neighbors = get(adjacency, item, Dict{Int,Int}())

        for candidate in remaining
            if haskey(item_neighbors, candidate)
                push!(next_candidates, candidate)
            end
        end

        if !isempty(next_candidates)
            extend_patterns!(pattern, support_tidset, next_candidates, item_tidsets, adjacency, minsup, results, stats)
        end

        if index % 32 == 0
            sample_memory!(stats)
        end
    end
end

function run_adjacency_fpgrowth(transactions, minsup)
    stats = MiningStats()
    results = Vector{Tuple{Vector{Int},Int}}()
    stats.transaction_count = length(transactions)
    minsup = max(1, round(Int, minsup * length(transactions)))
    reset_memory_tracking!(stats)

    elapsed = @elapsed begin
        sample_memory!(stats)
        support, item_tidsets, adjacency = build_adjacency_index(transactions, minsup, stats)

        for item in sort(collect(keys(support)))
            push!(results, ([item], support[item]))
            stats.frequent_itemset_count += 1

            neighbors = get(adjacency, item, Dict{Int,Int}())
            candidates = sort([neighbor for neighbor in keys(neighbors) if neighbor > item])

            if !isempty(candidates)
                extend_patterns!([item], item_tidsets[item], candidates, item_tidsets, adjacency, minsup, results, stats)
            end

            sample_memory!(stats)
        end

        sample_memory!(stats)
    end

    stats.runtime_ns = round(Int64, elapsed * 1_000_000_000)
    sort!(results, by = entry -> (length(entry[1]), entry[1]))
    stats.frequent_itemset_count = length(results)
    return results, stats
end

end
