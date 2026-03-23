module Structures

export FPNode, FPTree

"""
Node trong FP-tree
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
FP-tree
"""
mutable struct FPTree
    root::FPNode
    header::Dict{Int,FPNode}   # nodeLink head
    support::Dict{Int,Int}

    function FPTree()
        root = FPNode(nothing, nothing)
        root.count = 0
        new(root, Dict{Int,FPNode}(), Dict{Int,Int}())
    end
end

end