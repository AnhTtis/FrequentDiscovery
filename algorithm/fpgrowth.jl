module FPGrowth

using ..Structures

export build_fptree, mine_tree

############################
# Build FP-tree
############################
function build_fptree(transactions, minsup)

    freq = Dict{Int,Int}()

    # count support
    for t in transactions
        for i in t
            freq[i] = get(freq,i,0) + 1
        end
    end

    # lọc minsup
    freq = Dict(k=>v for (k,v) in freq if v >= minsup)

    if isempty(freq)
        return nothing
    end

    tree = FPTree()
    tree.support = freq

    for t in transactions

        items = [i for i in t if haskey(freq,i)]
        sort!(items, by=x->-freq[x])

        insert_tree!(tree.root, items, tree)
    end

    return tree
end


function insert_tree!(node, items, tree)

    if isempty(items)
        return
    end

    item = first(items)

    if haskey(node.children,item)

        child = node.children[item]
        child.count += 1

    else

        child = FPNode(item,node)
        node.children[item] = child

        # cập nhật nodeLink
        if !haskey(tree.header,item)
            tree.header[item] = child
        else
            cur = tree.header[item]
            while cur.nodeLink != nothing
                cur = cur.nodeLink
            end
            cur.nodeLink = child
        end
    end

    insert_tree!(child, items[2:end], tree)
end


############################
# Conditional pattern base
############################
function conditional_pattern_base(tree, item)

    base = []

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

    transactions = []

    for (path,count) in pattern_base
        for _ in 1:count
            push!(transactions, path)
        end
    end

    if isempty(transactions)
        return nothing
    end

    return build_fptree(transactions, minsup)
end


############################
# Mining
############################
function mine_tree(tree, prefix, results, minsup)

    items = sort(collect(keys(tree.header)), by=x->tree.support[x])

    for item in items

        new_pattern = vcat(prefix,item)

        # support = tổng count nodeLink
        support = 0
        node = tree.header[item]

        while node != nothing
            support += node.count
            node = node.nodeLink
        end

        push!(results,(new_pattern,support))

        cond_base = conditional_pattern_base(tree,item)

        cond_tree = build_cond_tree(cond_base, minsup)

        if cond_tree != nothing
            mine_tree(cond_tree,new_pattern,results,minsup)
        end
    end
end

end