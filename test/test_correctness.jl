using .Utils
using .FPGrowth
using .ProjectionFPGrowth
using .AdjacencyFPGrowth

function canonicalize_results(results)
    Dict(Tuple(sort(items)) => support for (items, support) in results)
end

@testset "Toy dataset correctness across algorithms" begin
    toy_cases = [
        ("input1.txt", 0.5),
        ("input2.txt", 0.4),
        ("input3.txt", 0.4),
        ("input4.txt", 0.35),
        ("input5.txt", 0.3),
    ]

    for (filename, minsup) in toy_cases
        path = joinpath(@__DIR__, "..", "dataset", "toy", filename)
        transactions = read_spmf(path)

        classic_results, classic_stats = run_fpgrowth(transactions, minsup)
        projection_results, projection_stats = run_projection_fpgrowth(transactions, minsup)
        adjacency_results, adjacency_stats = run_adjacency_fpgrowth(transactions, minsup)

        expected = canonicalize_results(classic_results)

        @test canonicalize_results(projection_results) == expected
        @test canonicalize_results(adjacency_results) == expected
        @test classic_stats.frequent_itemset_count == length(expected)
        @test projection_stats.frequent_itemset_count == length(expected)
        @test adjacency_stats.frequent_itemset_count == length(expected)
    end
end

@testset "SPMF reader removes duplicates inside a transaction" begin
    path = joinpath(@__DIR__, "..", "dataset", "toy", "input5.txt")
    transactions = read_spmf(path)

    @test transactions[1] == [1, 2, 3, 8]
    @test transactions[3] == [2, 4, 6, 10]
    @test transactions[8] == [3, 6, 11]
    @test all(length(transaction) == length(unique(transaction)) for transaction in transactions)
end
