# FrequentDiscovery

FP-Growth implementation in Julia for the CSC14004 frequent itemset mining project.

## Project Layout

```text
FrequentDiscovery/
|-- Project.toml
|-- src/
|   |-- FrequentDiscovery.jl
|   |-- main.jl
|   |-- algorithm/
|       |-- structures.jl
|       |-- utils.jl
|       |-- fpgrowth.jl
|-- tests/
|   |-- runtests.jl
|   |-- test_correctness.jl
|   |-- test_benchmark.jl
|-- data/
|   |-- toy/
|   |-- reference/
```

## Run

```powershell
julia --project src/main.jl data/toy/basic.txt output.txt 3
julia --project src/main.jl data/toy/basic.txt output.txt 3 --variant optimized
```

Supported variants:

- `baseline`: direct FP-Growth implementation
- `weighted`: weighted conditional FP-tree construction
- `singlepath`: single-path shortcut during mining
- `optimized`: weighted conditional trees + single-path shortcut

## Test

```powershell
julia --project tests/runtests.jl
```

The correctness suite checks 5 toy databases and compares all variants against stored
reference outputs in SPMF-compatible format.

## Notes

- Input format: one transaction per line, space-separated integer items
- Comment lines starting with `#`, `%`, or `@` are ignored
- Output format: `item1 item2 ... #SUP: k`
