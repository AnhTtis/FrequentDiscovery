##################################################
# EXPERIMENT: TRANSACTION LENGTH DATA GENERATION
##################################################

using Random

##################################################
# 1. GENERATE DATASET
##################################################
"""
Generate synthetic transaction dataset (SPMF format)

num_trans  : number of transactions
num_items  : number of unique items
avg_len    : average transaction length
path       : output file path
"""
function generate_dataset(num_trans, num_items, avg_len, path)

    open(path, "w") do io

        for _ in 1:num_trans

            # random length quanh avg_len
            len = max(1, rand(avg_len ÷ 2 : avg_len * 2))

            # sinh item và loại duplicate
            items = unique(rand(1:num_items, len))

            # sort để đúng chuẩn SPMF
            sort!(items)

            println(io, join(items, " "))
        end

    end
end


##################################################
# 2. GENERATE MULTIPLE DATASETS
##################################################
function generate_all_datasets()

    num_trans = 10000
    num_items = 20

    # các mức độ dài transaction
    lengths = [5, 10, 20, 30, 50]

    println("Generating datasets...")

    for L in lengths

        base_dir = @__DIR__
        filename = joinpath(base_dir, "data_L$(L).txt")

        println("Creating $filename (avg length = $L)")

        generate_dataset(num_trans, num_items, L, filename)
    end

    println("\nDone! All datasets generated.")

end


##################################################
# RUN
##################################################
generate_all_datasets()