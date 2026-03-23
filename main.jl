include("algorithm/structures.jl")
include("algorithm/utils.jl")
include("algorithm/fpgrowth.jl")

using .Structures
using .Utils
using .FPGrowth

if length(ARGS) < 3
    println("Usage: julia main.jl input.txt output.txt minsup")
    exit()
end

input = ARGS[1]
output = ARGS[2]
minsup = parse(Int,ARGS[3])

transactions = read_spmf(input)

tree = build_fptree(transactions, minsup)

results = []

if tree != nothing
    mine_tree(tree, Int[], results, minsup)
end

write_output(output, results)

println("Done!")