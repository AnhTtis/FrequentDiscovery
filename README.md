# FrequentDiscovery

FrequentDiscovery là đồ án khai phá frequent itemset bằng Julia cho môn Data Mining. Dự án hiện thực ba hướng tiếp cận:

- `classic`: FP-Growth cổ điển dựa trên FP-tree và conditional FP-tree
- `projection`: FP-Growth theo projected database
- `adjacency`: khai phá dựa trên đồ thị kề đồng xuất hiện và giao cắt tidset

README này được viết để vừa hướng dẫn chạy chương trình, vừa mô tả ngắn gọn cấu trúc mã nguồn và cách kiểm thử tự động của dự án.

## 1. Thông tin nhóm

| STT | Họ và tên | MSSV |
| --- | --- | --- |
| 1 | Nguyễn Hữu Anh Trí | 23127160 |
| 2 | Cao Trần Bá Đạt | 23127168 |
| 3 | Tô Trần Hoàng Triệu | 23127xxx |
| 4 | Cao Tấn Hoàng Huy | 23127051 |

## 2. Mục tiêu chương trình

Chương trình nhận dữ liệu giao dịch theo định dạng SPMF-style, khai phá frequent itemset theo ngưỡng `minsup`, sau đó:

- ghi kết quả ra file `local_<algorithm>_<dataset>_<minsup>.txt`
- ghi thống kê thực nghiệm ra file `stats_<algorithm>_<dataset>_<minsup>.txt`

Ba thuật toán dùng chung giao diện vào/ra để tiện so sánh tính đúng đắn, thời gian chạy, số lượng itemset, và mức sử dụng bộ nhớ.

## 3. Yêu cầu môi trường

- Julia 1.x
- Không cần package ngoài chuẩn Julia cho phần mã nguồn hiện tại

## 4. Cấu trúc thư mục

```text
FrequentDiscovery/
|-- README.md
|-- Project.toml
|-- dataset/
|   |-- benmark/
|   |   |-- accidents.txt
|   |   |-- chess.txt
|   |   |-- mushrooms.txt
|   |   |-- retail.txt
|   |   |-- T10I4D100K.txt
|   |-- toy/
|   |   |-- input1.txt
|   |   |-- input2.txt
|   |   |-- input3.txt
|   |   |-- input4.txt
|   |   |-- input5.txt
|-- src/
|   |-- main.jl
|   |-- algorithm/
|   |   |-- structures.jl
|   |   |-- utils.jl
|   |   |-- fpgrowth.jl
|   |   |-- projection_fpgrowth.jl
|   |   |-- adjacency_fpgrowth.jl
|   |-- experiment/
|       |-- exp_transaction_length.jl
|-- test/
|   |-- runtests.jl
|   |-- test_correctness.jl
|   |-- test_benchmark.jl
```

Ghi chú:

- Thư mục output không bắt buộc phải có sẵn; chương trình sẽ tự tạo nếu bạn truyền một thư mục output mới.
- Một số file output mẫu có thể được đặt ngay ở thư mục gốc để phục vụ việc so sánh nhanh.

## 5. Cách chạy chương trình

### 5.1. Chạy một thuật toán trên một file hoặc một thư mục dữ liệu

```powershell
julia src/main.jl -a classic dataset/benmark/chess.txt output 0.55
julia src/main.jl -a projection dataset/benmark/chess.txt output 0.55
julia src/main.jl -a adjacency dataset/benmark/chess.txt output 0.55
```

Nếu `input_path` là thư mục, chương trình sẽ chạy lần lượt trên toàn bộ file trong thư mục đó.

### 5.2. So sánh hai thuật toán trên cùng một bộ dữ liệu

```powershell
julia src/main.jl -c classic projection dataset/benmark/chess.txt output 0.55
```

Lệnh này sẽ chạy hai thuật toán, đọc lại file `stats_*.txt`, rồi in phần so sánh thời gian chạy, số lượng mẫu và bộ nhớ.

### 5.3. Chạy cả ba thuật toán trên cùng một bộ dữ liệu

```powershell
julia src/main.jl -ca dataset/benmark/chess.txt output 0.55
```

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

## 6. Luồng xử lý chung

Mọi thuật toán đều đi theo pipeline tổng quát sau:

1. `main.jl` phân tích tham số dòng lệnh bằng `parse_cli_args`.
2. Nếu cần ghi output, chương trình tạo thư mục output bằng `ensure_output_dir`.
3. Dữ liệu giao dịch được đọc bằng `read_spmf`.
4. Tên thuật toán được ánh xạ sang hàm thực thi bằng `resolve_algorithm`.
5. `minsup` đầu vào ở dạng tỉ lệ được đổi sang ngưỡng tuyệt đối:

```julia
max(1, ceil(Int, minsup * length(transactions)))
```

6. Thuật toán tương ứng được gọi để sinh frequent itemset.
7. Kết quả được ghi theo định dạng SPMF-like bằng `write_output`.
8. Thống kê runtime, memory và cấu trúc trung gian được ghi bằng `write_stats_output`.

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

Đây là bản baseline chuẩn nhất về mặt ý tưởng và phù hợp để dùng làm mốc so sánh.

### 8.2. `projection`

Biến thể `projection` không khai phá trực tiếp trên một FP-tree duy nhất, mà:

1. xác định thứ tự toàn cục của item
2. với mỗi item phổ biến, xây projected database
3. dựng FP-tree trên projected database
4. gọi lại cơ chế khai phá của bản `classic`

Biến thể này giúp thu hẹp dữ liệu cần xử lý trong mỗi nhánh khai phá cục bộ.

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
- `patterns`
- `runtime_ns`
- `nodes`
- `trees`
- `conditional_trees`
- `projections`
- `memory_baseline_bytes`
- `peak_working_set_bytes`

## 10. Kiểm thử tự động

Dự án có bộ unit test tự động trong thư mục `test/`. Chạy:

```powershell
julia --project=. test/runtests.jl
```

Bộ test hiện kiểm tra hai nhóm nội dung:

- `test_correctness.jl`: đối chiếu tính đúng đắn giữa `classic`, `projection`, và `adjacency` trên các bộ dữ liệu toy
- `test_benchmark.jl`: kiểm tra luồng `-b` khi so sánh trực tiếp hai file output

Mục tiêu là đảm bảo:

- ba thuật toán cho cùng kết quả trên cùng input toy
- hàm đọc dữ liệu loại bỏ item trùng trong cùng transaction
- luồng benchmark mới báo đúng số lượng itemset khớp và không khớp

## 11. Ghi chú thực thi

- Lệnh `-a` chạy một thuật toán trên một file hoặc toàn bộ file trong thư mục input
- Lệnh `-c` chạy hai thuật toán và đọc lại file `stats` để in phần so sánh
- Lệnh `-ca` sinh tiến trình riêng cho cả ba thuật toán
- Lệnh `-b` so sánh trực tiếp hai file output và in tỉ lệ itemset khớp nhau, không ghi thêm file benchmark

Nếu dùng README này cho báo cáo, bạn có thể tái sử dụng các mục 6, 7, 8 và 10 cho phần mô tả cài đặt và kiểm thử.
