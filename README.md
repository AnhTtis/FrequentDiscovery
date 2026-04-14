# FrequentDiscovery

FrequentDiscovery là đồ án khai phá frequent itemset bằng Julia cho môn Data Mining. Dự án hiện thực ba hướng tiếp cận:

- `classic`: FP-Growth cổ điển dựa trên FP-tree và conditional FP-tree
- `projection`: FP-Growth theo projected database
- `adjacency`: khai phá dựa trên đồ thị kề đồng xuất hiện và giao cắt tidset

README này dùng để hướng dẫn cài môi trường, chạy chương trình, chạy các thí nghiệm phụ trợ, và kiểm thử tự động.

## 1. Thông tin nhóm

| STT | Họ và tên | MSSV |
| --- | --- | --- |
| 1 | Nguyễn Hữu Anh Trí | 23127160 |
| 2 | Cao Trần Bá Đạt | 23127168 |
| 3 | Tô Trần Hoàng Triệu | 23127133 |
| 4 | Cao Tấn Hoàng Huy | 23127051 |

## 2. Mục tiêu chương trình

Chương trình nhận dữ liệu giao dịch theo định dạng SPMF-style, khai phá frequent itemset theo ngưỡng `minsup`, sau đó:

- ghi kết quả ra file `local_<algorithm>_<dataset>_<minsup>.txt`
- ghi thống kê thực nghiệm ra file `stats_<algorithm>_<dataset>_<minsup>.txt`

Ba thuật toán dùng chung giao diện vào/ra để tiện so sánh tính đúng đắn, thời gian chạy, số lượng itemset, và mức sử dụng bộ nhớ.

## 3. Cài môi trường

### 3.1. Cài Julia

Tải Julia từ trang chính thức:

- `https://julialang.org/downloads/`

Với Windows, có thể dùng một trong hai cách sau:

- Nếu có Microsoft Store:

```powershell
winget install --name Julia --id 9NJNWW8PVKMN -e -s msstore
```

- Nếu không dùng Microsoft Store, cài bằng gói App Installer:

- `https://install.julialang.org/Julia.appinstaller`

Với macOS hoặc Linux, dùng:

```bash
curl -fsSL https://install.julialang.org | sh
```

Sau khi tải xong, chạy file cài đặt và làm theo hướng dẫn của Julia. Sau đó thêm Julia vào biến môi trường `PATH`.

Kiểm tra lại bằng terminal (`CMD`, PowerShell, Terminal):

```powershell
julia --version
```

Nếu terminal trả về `julia version 1.9.x` hoặc cao hơn thì môi trường đã sẵn sàng để chạy project.

### 3.2. Chuẩn bị project

Di chuyển vào thư mục gốc của repo rồi chạy các lệnh CLI trong README này. Project hiện không cần package ngoài standard library để chạy phần lõi, nhưng bạn vẫn có thể khởi tạo environment bằng:

```powershell
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

## 4. Cấu trúc thư mục

```text
FrequentDiscovery/
|-- README.md
|-- Project.toml
|-- dataset/
|   |-- benchmark/
|   |   |-- accidents.txt
|   |   |-- chess.txt
|   |   |-- mushrooms.txt
|   |   |-- retail.txt
|   |   |-- T10I4D100K.txt
|   |-- retail_subsets/
|   |   |-- retail_10pct.txt
|   |   |-- retail_25pct.txt
|   |   |-- retail_50pct.txt
|   |   |-- retail_75pct.txt
|   |   |-- retail_100pct.txt
|   |-- toy/
|   |   |-- input1.txt
|   |   |-- input2.txt
|   |   |-- input3.txt
|   |   |-- input4.txt
|   |   |-- input5.txt
|   |-- toy_benchmark/
|       |-- input1_ans.txt
|       |-- input2_ans.txt
|       |-- input3_ans.txt
|       |-- input4_ans.txt
|       |-- input5_ans.txt
|-- experiment_result/
|   |-- Experiement - Accidents.csv
|   |-- Experiement - Chess.csv
|   |-- Experiement - Mushrooms.csv
|   |-- Experiement - Retail.csv
|   |-- Experiement - Retail_subset.csv
|   |-- Experiement - T10I4D100K.csv
|-- src/
|   |-- main.jl
|   |-- algorithm/
|   |   |-- structures.jl
|   |   |-- utils.jl
|   |   |-- fpgrowth.jl
|   |   |-- projection_fpgrowth.jl
|   |   |-- adjacency_fpgrowth.jl
|   |-- experiment/
|       |-- split_retail_subsets.jl
|       |-- exp_transaction_length.jl
|-- test/
|   |-- runtests.jl
|   |-- test_benchmark.jl
```

Ghi chú:

- Thư mục output không bắt buộc phải có sẵn; chương trình sẽ tự tạo nếu bạn truyền một thư mục output mới.
- Thư mục `dataset/retail_subsets/` chứa các file con được tách từ `retail.txt` theo nhiều tỉ lệ mẫu.
- Thư mục `dataset/toy_benchmark/` chứa output tham chiếu để đối chiếu với kết quả sinh bởi ba thuật toán.
- Thư mục `experiment_result/` chứa các file `.csv` tổng hợp kết quả thực nghiệm để phục vụ báo cáo và so sánh.

## 5. Cách chạy chương trình

Các ví dụ dưới đây giả sử bạn đang đứng ở thư mục gốc của repo, vì vậy entrypoint chính là `src/main.jl`.
Các block log bên dưới giữ đúng format console của chương trình; các con số chỉ mang tính minh họa và sẽ thay đổi theo dataset, `minsup`, và máy chạy.

### 5.1. Chạy một thuật toán trên một file hoặc một thư mục dữ liệu

```powershell
julia src/main.jl -a classic dataset/benchmark/chess.txt output 0.55
julia src/main.jl -a projection dataset/benchmark/chess.txt output 0.55
julia src/main.jl -a adjacency dataset/benchmark/chess.txt output 0.55
```

Nếu `input_path` là thư mục, chương trình sẽ chạy lần lượt trên toàn bộ file trong thư mục đó.

Ví dụ log minh họa cho lệnh `classic`:

```text
========================================
Algorithm: classic
file: dataset/benchmark/chess.txt
Transactions count from database : 3196
Max memory usage: 12.34 MB
Frequent itemsets count : 1234
Total time ~ 87.25 ms
Nodes: 4567
Trees: 120
Conditional trees: 119
Projections: 0
Peak RAM (MB): 12.34
Minimum support: 0.55
========================================
```

File được tạo:

- `output/local_classic_chess_55%.txt`
- `output/stats_classic_chess_55_0.txt`

Định dạng file tạo ra:

- `local_*.txt`: mỗi dòng là một frequent itemset theo dạng `item1 item2 ... #SUP: k`
- `stats_*.txt`: mỗi dòng là một cặp `key=value`

Ví dụ nội dung `local_classic_chess_55%.txt`:

```text
1 #SUP: 1750
1 3 #SUP: 1242
1 3 7 #SUP: 820
```

Ví dụ nội dung `stats_classic_chess_55_0.txt`:

```text
algorithm=classic
input_file=dataset/benchmark/chess.txt
minsup=0.55
transactions=3196
frequent itemsets=1234
runtime_ns=87250000
nodes=4567
trees=120
conditional_trees=119
projections=0
memory_baseline_bytes=7340032
peak_working_set_bytes=12939428
```

### 5.2. So sánh hai thuật toán trên cùng một bộ dữ liệu

```powershell
julia src/main.jl -c classic projection dataset/benchmark/chess.txt output 0.55
```

Lệnh này sẽ chạy hai thuật toán, đọc lại file `stats_*.txt`, rồi in phần so sánh thời gian chạy, số lượng mẫu và bộ nhớ.

Log minh họa:

```text
========================================
Algorithm: classic
file: dataset/benchmark/chess.txt
Transactions count from database : 3196
Max memory usage: 12.34 MB
Frequent itemsets count : 1234
Total time ~ 87.25 ms
Nodes: 4567
Trees: 120
Conditional trees: 119
Projections: 0
Peak RAM (MB): 12.34
Minimum support: 0.55
========================================
========================================
Algorithm: projection
file: dataset/benchmark/chess.txt
Transactions count from database : 3196
Max memory usage: 10.91 MB
Frequent itemsets count : 1234
Total time ~ 74.18 ms
Nodes: 4021
Trees: 97
Conditional trees: 96
Projections: 312
Peak RAM (MB): 10.91
Minimum support: 0.55
========================================
========================================
Comparison file: dataset/benchmark/chess.txt
Minimum support: 0.55
Algorithm 1: classic
  Transactions count from database : 3196
  Max memory usage: 12.34 MB
  Frequent itemsets count : 1234
  Total time ~ 87.25 ms
Algorithm 2: projection
  Transactions count from database : 3196
  Max memory usage: 10.91 MB
  Frequent itemsets count : 1234
  Total time ~ 74.18 ms
========================================
```

File được tạo:

- `output/local_classic_chess_55%.txt`
- `output/stats_classic_chess_55_0.txt`
- `output/local_projection_chess_55%.txt`
- `output/stats_projection_chess_55_0.txt`

Định dạng file tạo ra giống mục `5.1`; điểm khác là màn hình sẽ in thêm block `Comparison file:` để so sánh hai file `stats`.

### 5.3. Chạy cả ba thuật toán trên cùng một bộ dữ liệu

```powershell
julia src/main.jl -ca dataset/benchmark/chess.txt output 0.55
```

Lệnh này chạy lần lượt `classic`, `projection`, và `adjacency` trong ba tiến trình Julia riêng.

Log minh họa:

```text
========================================
Algorithm: classic
...
Minimum support: 0.55
========================================
========================================
Algorithm: projection
...
Minimum support: 0.55
========================================
========================================
Algorithm: adjacency
...
Minimum support: 0.55
========================================
```

File được tạo:

- `output/local_classic_chess_55%.txt`
- `output/stats_classic_chess_55_0.txt`
- `output/local_projection_chess_55%.txt`
- `output/stats_projection_chess_55_0.txt`
- `output/local_adjacency_chess_55%.txt`
- `output/stats_adjacency_chess_55_0.txt`

Định dạng của từng file vẫn giống mục `5.1`; khác biệt là bạn nhận được đủ kết quả của cả ba thuật toán sau một lệnh.

### 5.4. So sánh trực tiếp hai file output

```powershell
julia src/main.jl -b local_classic_chess_50%.txt system_chess_50%.txt output
```

Ý nghĩa:

- `output_file1`: file hiện tại của nhóm
- `output_file2`: file tham chiếu, ví dụ từ SPMF hoặc hệ thống
- `output_folder`: thư mục dùng để tìm hai file nếu bạn chỉ truyền tên file

Lệnh `-b` không ghi thêm file benchmark. Chương trình chỉ in trực tiếp:

- số itemset trong mỗi file
- số itemset khớp hoàn toàn
- tỉ lệ khớp theo phần trăm
- số itemset chỉ xuất hiện ở một phía
- số itemset có cùng tập item nhưng sai support

Log minh họa:

```text
========================================
Output file 1 (current): local_classic_chess_55%.txt
Output file 2 (system): system_chess_55%.txt
Itemsets in file 1: 1234
Itemsets in file 2: 1234
Exact matches (same itemset + same support): 1234
Match rate vs file 1: 100.0%
Match rate vs file 2: 100.0%
Support mismatches on shared itemsets: 0
Only in file 1: 0
Only in file 2: 0
Outputs identical: true
========================================
```

Định dạng hai file đầu vào cần so sánh:

- Mỗi dòng phải có dạng `item1 item2 ... #SUP: k`
- Thứ tự dòng không quan trọng vì chương trình chuẩn hóa tập item trước khi so sánh

Lệnh `-b` không tạo thêm file nào; toàn bộ kết quả được in ra console.

### 5.5. Tách một dataset lớn thành nhiều file con theo tỉ lệ

CLI:

```powershell
julia src/main.jl -s <input_file> <output_folder> [ratios] [seed] [sampling]
```

Hoặc chạy trực tiếp script thí nghiệm:

```powershell
julia src/experiment/split_retail_subsets.jl [input_file] [output_dir] [ratios] [seed] [sampling]
```

Lệnh này tương đương với mode `-s`, nhưng đi thẳng vào script tách subset.

Chức năng: dùng để tách một file giao dịch trong `dataset/benchmark` hoặc một dataset lớn khác thành nhiều file con theo tỉ lệ.

- `input_file`: file giao dịch gốc
- `output_folder`: thư mục ghi các subset
- `ratios` mặc định `0.10,0.25,0.50,0.75,1.00`: danh sách tỉ lệ lấy mẫu
- `seed` mặc định `2026`: seed random để tái lập kết quả
- `sampling` mặc định `independent`: cách lấy mẫu

Hai chế độ lấy mẫu:

- `independent`: mỗi tỉ lệ lấy mẫu độc lập, các file con không nhất thiết lồng nhau
- `prefix`: xáo trộn dữ liệu một lần rồi lấy prefix, nên file nhỏ là tập con của file lớn. Ví dụ tập `10%` là con của `25%`, và `25%` là con của `50%`

Ví dụ:

```powershell
julia src/main.jl -s dataset/benchmark/retail.txt output/retail_subsets
julia src/main.jl -s dataset/benchmark/retail.txt output/retail_subsets 0.10,0.25,0.50 2026 prefix
```

Log minh họa cho ví dụ thứ hai:

```text
Input file: dataset/benchmark/retail.txt
Total transactions: 88162
Output directory: output/retail_subsets
Ratios: 0.1,0.25,0.5
Subset sampling: prefix
Random seed: 2026
Created retail_10pct.txt with 8816 transactions
Created retail_25pct.txt with 22040 transactions
Created retail_50pct.txt with 44081 transactions
```

File được tạo:

- `output/retail_subsets/retail_10pct.txt`
- `output/retail_subsets/retail_25pct.txt`
- `output/retail_subsets/retail_50pct.txt`

Định dạng file tạo ra:

- Mỗi file con vẫn giữ đúng format transaction gốc: mỗi dòng là một transaction, các item cách nhau bằng dấu cách
- Chương trình không chèn thêm `#SUP` hay metadata vào các subset

Ví dụ nội dung một dòng trong subset:

```text
3 17 42 108
```

### 5.6. Sinh bộ dữ liệu giả lập theo độ dài transaction

CLI:

```powershell
julia src/main.jl -tl <output_folder> [num_transactions] [num_items_or_range] [lengths]
```

Chức năng: dùng để sinh bộ dữ liệu giả lập phục vụ thí nghiệm theo độ dài giao dịch.

- `output_folder`: nơi lưu các file sinh ra
- `num_transactions` mặc định `1000`: số transaction trong mỗi file
- `num_items_or_range` mặc định `100`: miền item. Có thể truyền `100` để hiểu là `1..100`, hoặc truyền `50:200` để hiểu là item từ `50` đến `200`
- `lengths` mặc định `5,10,20,30,50`: danh sách độ dài transaction; mỗi độ dài sinh ra một file dạng `data_Lx.txt`

Ví dụ:

```powershell
julia src/main.jl -tl output/transaction_length
julia src/main.jl -tl output/transaction_length 1000 100 5,10,20,30,50
julia src/main.jl -tl output/transaction_length 1000 50:200 5,10,20,30,50
```

Log minh họa cho ví dụ thứ hai:

```text
Output directory: output/transaction_length
Transactions per dataset: 1000
Item range: 1:100
Available items: 100
Transaction lengths: 5,10,20,30,50
Random seed: 2026
Created data_L5.txt with transaction length 5
Created data_L10.txt with transaction length 10
Created data_L20.txt with transaction length 20
Created data_L30.txt with transaction length 30
Created data_L50.txt with transaction length 50
```

File được tạo:

- `output/transaction_length/data_L5.txt`
- `output/transaction_length/data_L10.txt`
- `output/transaction_length/data_L20.txt`
- `output/transaction_length/data_L30.txt`
- `output/transaction_length/data_L50.txt`

Định dạng file tạo ra:

- Mỗi file tương ứng với một độ dài transaction cố định
- Mỗi dòng là một transaction ngẫu nhiên gồm đúng `L` item, được ghi theo thứ tự tăng dần

Ví dụ nội dung `data_L5.txt`:

```text
3 8 21 44 90
1 17 29 63 71
```

### 5.7. Chạy unit test tự động

CLI:

```powershell
julia --project=. test/runtests.jl
```

Log minh họa:

```text
Test Summary:                       | Pass  Total  Time
Toy outputs match benchmark answers |   15     15  0.8s
```

Ý nghĩa:

- Lệnh này chạy toàn bộ test được khai báo trong `test/runtests.jl`
- Hiện tại test tập trung vào việc đối chiếu output của ba thuật toán với benchmark trong `dataset/toy_benchmark/`
- Lệnh test không tạo file kết quả cố định trong repo; file tạm nếu có sẽ được tự dọn sau khi test xong

## 6. Luồng xử lý chung

Mọi thuật toán đều đi theo pipeline tổng quát sau:

1. `src/main.jl` phân tích tham số dòng lệnh bằng `parse_cli_args`.
2. Nếu cần ghi output, chương trình tạo thư mục output bằng `ensure_output_dir`.
3. Dữ liệu giao dịch được đọc bằng `read_spmf`.
4. Tên thuật toán được ánh xạ sang hàm thực thi bằng `resolve_algorithm`.
5. Thuật toán tương ứng được gọi để sinh frequent itemset.
6. Kết quả được ghi theo định dạng SPMF-like bằng `write_output`.
7. Thống kê runtime, memory và cấu trúc trung gian được ghi bằng `write_stats_output`.

## 7. Cấu trúc dữ liệu chính

Ba cấu trúc quan trọng trong `src/algorithm/structures.jl` là:

- `FPNode`: node của FP-tree, gồm `item`, `count`, `parent`, `children`, `nodeLink`
- `FPTree`: gồm `root`, `header` table và bảng `support`
- `MiningStats`: lưu số transaction, số frequent itemset, số node, số cây, số projection, thời gian chạy và bộ nhớ

Thiết kế này giúp ba biến thể chia sẻ cùng cơ chế ghi nhận thống kê và cùng chuẩn đầu ra.

## 8. Tóm tắt cách cài đặt ba thuật toán

### 8.1. `classic`

Biến thể `classic` bám sát FP-Growth truyền thống:

1. đếm hỗ trợ toàn cục của item
2. loại item không đủ `minsup`
3. sắp xếp transaction theo hỗ trợ giảm dần
4. chèn transaction vào FP-tree
5. khai phá đệ quy bằng conditional pattern base và conditional FP-tree

### 8.2. `projection`

Biến thể `projection` không khai phá trực tiếp trên một FP-tree duy nhất, mà:

1. xác định thứ tự toàn cục của item
2. với mỗi item phổ biến, xây projected database
3. dựng FP-tree trên projected database
4. gọi lại cơ chế khai phá của bản `classic`

### 8.3. `adjacency`

Biến thể `adjacency` thay thế phần lớn cơ chế conditional tree bằng:

1. chỉ mục hỗ trợ của item
2. tidset của từng item
3. đồ thị đồng xuất hiện giữa các item

Việc mở rộng mẫu được thực hiện bằng giao cắt tidset và cắt tỉa ứng viên thông qua đồ thị kề.

## 9. Định dạng dữ liệu

### 9.1. Input

- Mỗi dòng là một transaction
- Các item là số nguyên, cách nhau bằng khoảng trắng
- Các item trùng trong cùng một transaction sẽ bị loại bỏ bằng `unique`

Ví dụ:

```text
1 2 5
2 4
1 2 4
1 2 3 5
```

### 9.2. Output frequent itemset

Mỗi dòng có dạng:

```text
item1 item2 ... #SUP: k
```

Quy ước cụ thể:

- Các item trong cùng một itemset được ghi theo thứ tự tăng dần
- Toàn bộ file được sắp theo `(độ dài itemset, itemset)` để dễ so sánh giữa các lần chạy

Ví dụ:

```text
1 #SUP: 3
1 2 #SUP: 3
2 4 #SUP: 2
```

### 9.3. Output thống kê

File `stats_*.txt` hiện lưu các trường:

- `algorithm`
- `input_file`
- `minsup`
- `transactions`
- `frequent itemsets`
- `runtime_ns`
- `nodes`
- `trees`
- `conditional_trees`
- `projections`
- `memory_baseline_bytes`
- `peak_working_set_bytes`

Ví dụ:

```text
algorithm=classic
input_file=dataset/benchmark/chess.txt
minsup=0.55
transactions=3196
frequent itemsets=1234
runtime_ns=87250000
nodes=4567
trees=120
conditional_trees=119
projections=0
memory_baseline_bytes=7340032
peak_working_set_bytes=12939428
```

## 10. Kiểm thử tự động

Project có CLI để chạy toàn bộ unit test tự động trong thư mục `test/`:

```powershell
julia --project=. test/runtests.jl
```

Log thường có dạng:

```text
Test Summary:                       | Pass  Total  Time
Toy outputs match benchmark answers |   15     15  0.8s
```

Hiện tại `test/runtests.jl` nạp `test/test_benchmark.jl`, và testset này kiểm tra:

- output của cả ba thuật toán `classic`, `projection`, và `adjacency`
- dữ liệu toy trong `dataset/toy/`
- benchmark tham chiếu trong `dataset/toy_benchmark/`

Mục tiêu là đảm bảo ba thuật toán sinh ra output đúng theo benchmark đã chuẩn bị sẵn.
Lệnh test không tạo file kết quả cố định trong repo; các file trung gian nếu có sẽ được đặt trong thư mục tạm và tự dọn sau khi test kết thúc.

## 11. Ghi chú thực thi

- Lệnh `-a` chạy một thuật toán trên một file hoặc toàn bộ file trong thư mục input
- Lệnh `-c` chạy hai thuật toán và đọc lại file `stats` để in phần so sánh
- Lệnh `-ca` sinh tiến trình riêng cho cả ba thuật toán
- Lệnh `-b` so sánh trực tiếp hai file output và in tỉ lệ itemset khớp nhau
- Lệnh `-s` tạo các subset theo tỉ lệ để phục vụ benchmark kích thước dữ liệu
- Lệnh `-tl` sinh dataset giả lập theo nhiều độ dài transaction khác nhau
