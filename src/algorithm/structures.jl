module Structures

export FPNode, FPTree, MiningStats

"""
Node trong FP-tree.
"""
mutable struct FPNode
    item::Union{Int,Nothing}
    count::Int
    parent::Union{FPNode,Nothing}
    children::Dict{Int,FPNode}
    nodeLink::Union{FPNode,Nothing}

    function FPNode(item, parent)
        new(item, 1, parent, Dict{Int,FPNode}(), nothing)
    end
end

"""
FP-tree.
"""
mutable struct FPTree
    root::FPNode
    header::Dict{Int,FPNode}
    support::Dict{Int,Int}

    function FPTree()
        root = FPNode(nothing, nothing)
        root.count = 0
        new(root, Dict{Int,FPNode}(), Dict{Int,Int}())
    end
end

"""
Statistics during mining.
"""
mutable struct MiningStats
    transaction_count::Int
    frequent_itemset_count::Int
    node_count::Int
    tree_count::Int
    projection_count::Int
    conditional_tree_count::Int
    runtime_ns::Int64
    memory_baseline_bytes::Int64
    peak_working_set_bytes::Int64

    function MiningStats()
        new(0, 0, 0, 0, 0, 0, 0, 0, 0)
    end
end

end
