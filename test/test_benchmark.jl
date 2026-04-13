using .Utils

@testset "CLI output-file comparison" begin
    mktempdir() do tempdir
        identical_results = [
            ([1], 3),
            ([1, 2], 2),
            ([2, 3], 2),
        ]

        write_output(joinpath(tempdir, "current.txt"), copy(identical_results))
        write_output(joinpath(tempdir, "system.txt"), reverse(copy(identical_results)))

        identical_comparison = compare_output_results("current.txt", "system.txt", tempdir)

        identical_buffer = IOBuffer()
        print_output_comparison_summary(identical_buffer, identical_comparison)
        identical_output = String(take!(identical_buffer))

        @test occursin("Match rate vs file 1: 100.0%", identical_output)
        @test occursin("Match rate vs file 2: 100.0%", identical_output)
        @test occursin("Outputs identical: true", identical_output)

        write_output(joinpath(tempdir, "system_mismatch.txt"), [([1], 4), ([2, 3], 2), ([4], 1)])

        mismatch_comparison = compare_output_results("current.txt", "system_mismatch.txt", tempdir)

        mismatch_buffer = IOBuffer()
        print_output_comparison_summary(mismatch_buffer, mismatch_comparison)
        mismatch_output = String(take!(mismatch_buffer))

        @test occursin("Outputs identical: false", mismatch_output)
        @test occursin("Support mismatches on shared itemsets: 1", mismatch_output)
        @test occursin("Only in file 1: 1", mismatch_output)
        @test occursin("Only in file 2: 1", mismatch_output)
    end
end
