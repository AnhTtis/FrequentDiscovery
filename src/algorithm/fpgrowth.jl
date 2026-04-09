module FPGrowth

using ..Structures
using ..Utils: reset_memory_tracking!, sample_memory!

export build_fptree, mine_tree, run_fpgrowth

############################
# Build FP-tree
############################
function build_fptree(transactions, minsup)
    build_fptree(transactions, minsup, nothing)
end

function build_fptree(transactions, minsup, stats::Union{MiningStats,Nothing})
    sample_memory!(stats)
    freq = Dict{Int,Int}()

    for (index, transaction) in enumerate(transactions)
        for item in transaction
            freq[item] = get(freq, item, 0) + 1
        end

        if stats !== nothing && index % 256 == 0
            sample_memory!(stats)
        end
    end

    freq = Dict(item => support for (item, support) in freq if support >= minsup)
    if isempty(freq)
        return nothing
    end

    tree = FPTree()
    tree.support = freq

    if stats !== nothing
        stats.tree_count += 1
    end

    for (index, transaction) in enumerate(transactions)
        items = [item for item in transaction if haskey(freq, item)]
        sort!(items, by = item -> (-freq[item], item))
        insert_tree!(tree.root, items, tree, stats)

        if stats !== nothing && index % 256 == 0
            sample_memory!(stats)
        end
    end

    sample_memory!(stats)
    return tree
end

function insert_tree!(node, items, tree, stats::Union{MiningStats,Nothing}=nothing)
    if isempty(items)
        return
    end

    item = first(items)

    if haskey(node.children, item)
        child = node.children[item]
        child.count += 1
    else
        child = FPNode(item, node)
        node.children[item] = child

        if stats !== nothing
            stats.node_count += 1
        end

        if !haskey(tree.header, item)
            tree.header[item] = child
        else
            current = tree.header[item]
            while current.nodeLink != nothing
                current = current.nodeLink
            end
            current.nodeLink = child
        end
    end

    insert_tree!(child, items[2:end], tree, stats)
end

############################
# Conditional pattern base
############################
function conditional_pattern_base(tree, item)
    base = Vector{Tuple{Vector{Int},Int}}()
    node = tree.header[item]

    while node != nothing
        count = node.count
        path = Int[]
        parent = node.parent

        while parent != nothing && parent.item != nothing
            push!(path, parent.item)
            parent = parent.parent
        end

        if !isempty(path)
            push!(base, (reverse(path), count))
        end

        node = node.nodeLink
    end

    return base
end

############################
# Build conditional tree
############################
function build_cond_tree(pattern_base, minsup)
    build_cond_tree(pattern_base, minsup, nothing)
end

function build_cond_tree(pattern_base, minsup, stats::Union{MiningStats,Nothing})
    sample_memory!(stats)
    transactions = Vector{Vector{Int}}()

    for (index, (path, count)) in enumerate(pattern_base)
        for _ in 1:count
            push!(transactions, path)
        end

        if stats !== nothing && index % 128 == 0
            sample_memory!(stats)
        end
    end

    if isempty(transactions)
        return nothing
    end

    if stats !== nothing
        stats.conditional_tree_count += 1
    end

    tree = build_fptree(transactions, minsup, stats)
    sample_memory!(stats)
    return tree
end

############################
# Mining
############################
function mine_tree(tree, prefix, results, minsup)
    mine_tree(tree, prefix, results, minsup, nothing)
end

function mine_tree(tree, prefix, results, minsup, stats::Union{MiningStats,Nothing})
    sample_memory!(stats)
    items = sort(collect(keys(tree.header)), by = item -> (tree.support[item], item))

    for (index, item) in enumerate(items)
        new_pattern = vcat(prefix, item)

        support = 0
        node = tree.header[item]
        while node != nothing
            support += node.count
            node = node.nodeLink
        end

        push!(results, (new_pattern, support))
        if stats !== nothing
            stats.frequent_itemset_count += 1
        end

        cond_base = conditional_pattern_base(tree, item)
        cond_tree = build_cond_tree(cond_base, minsup, stats)

        if cond_tree != nothing
            mine_tree(cond_tree, new_pattern, results, minsup, stats)
        end

        if stats !== nothing && index % 32 == 0
            sample_memory!(stats)
        end
    end
end

function run_fpgrowth(transactions, minsup)
    stats = MiningStats()
    results = Vector{Tuple{Vector{Int},Int}}()
    stats.transaction_count = length(transactions)
    minsup = max(1, round(Int, minsup * length(transactions)))
    reset_memory_tracking!(stats)

    elapsed = @elapsed begin
        sample_memory!(stats)
        tree = build_fptree(transactions, minsup, stats)
        if tree != nothing
            mine_tree(tree, Int[], results, minsup, stats)
        end
        sample_memory!(stats)
    end

    stats.runtime_ns = round(Int64, elapsed * 1_000_000_000)
    sort!(results, by = entry -> (length(entry[1]), entry[1]))
    stats.frequent_itemset_count = length(results)
    return results, stats
end

end
