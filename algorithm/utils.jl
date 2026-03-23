module Utils

export read_spmf, write_output

"""
Đọc file SPMF
- loại duplicate trong transaction
"""
function read_spmf(path::String)

    transactions = Vector{Vector{Int}}()

    for line in eachline(path)

        items = unique(parse.(Int, split(strip(line))))

        push!(transactions, items)
    end

    return transactions
end


"""
Ghi output chuẩn SPMF
"""
function write_output(path, results)

    # sort toàn bộ (match SPMF)
    sort!(results, by = x -> (length(x[1]), x[1]))

    open(path,"w") do io

        for (items,sup) in results

            items = sort(items)

            println(io, "$(join(items," ")) #SUP: $sup")

        end

    end

end

end