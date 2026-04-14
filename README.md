# FrequentDiscovery

Du an cai dat Frequent Itemset Mining bang Julia cho mon CSC14004.

## Cau truc du an

```text
FrequentDiscovery/
|-- Project.toml
|-- src/
|   |-- main.jl
|   |-- algorithm/
|   |   |-- structures.jl
|   |   |-- utils.jl
|   |   |-- fpgrowth.jl
|   |   |-- projection_fpgrowth.jl
|   |   |-- adjacency_fpgrowth.jl
|   |-- dataset/
|   |-- unit_tests/
|-- data/
|   |-- eventlog_demo/
|   |-- eventlog_output/
|-- notebooks/
|   |-- demo.ipynb
|-- docs/
|   |-- event_log_report.tex
```

## Yeu cau moi truong

- Julia >= 1.9
- Chay lenh trong thu muc `src`

## Cac che do CLI

Di chuyen vao thu muc `src` truoc khi chay:

```powershell
cd src
```

### 1) Che do `-a`: chay 1 thuat toan

```powershell
julia main.jl -a <algorithm> <input_path> <output_folder> <minsup>
```

- `input_path` co the la 1 file hoac 1 thu muc chua nhieu file.
- Chuong trinh se tao ket qua local cho tung file dau vao.

Vi du:

```powershell
julia main.jl -a classic dataset/mushrooms.txt output 0.3
julia main.jl -a projection dataset output 0.25
```

### 2) Che do `-c`: so sanh 2 thuat toan

```powershell
julia main.jl -c <alg1> <alg2> <input_file> <output_folder> <minsup>
```

Vi du:

```powershell
julia main.jl -c classic projection dataset/chess.txt output 0.3
```

### 3) Che do `-ca`: chay tat ca thuat toan

```powershell
julia main.jl -ca <input_file> <output_folder> <minsup>
```

Vi du:

```powershell
julia main.jl -ca dataset/retail.txt output 0.2
```

### 4) Che do `-b`: doi chieu output he thong va local

```powershell
julia main.jl -b <algorithm> <input_file> <output_folder> <minsup>
```

Che do nay can san file:

- `system_<base>_<minsup_label>.txt`
- `local_<algorithm>_<base>_<minsup_label>.txt`

## Ten thuat toan (alias)

- `classic` hoac `fpgrowth`
- `projection` hoac `projected_fpgrowth`
- `adjacency` hoac `adjacency_fpgrowth`

## Luu y ve minsup

Trong implementation hien tai, `minsup` duoc parse la `Float64` va hieu theo ty le.

- `0.30` = 30% so transaction
- Nguong support tuyet doi duoc tinh ben trong bang `round(Int, minsup * n_transactions)`

## Dinh dang input/output

- Input: moi dong la mot transaction, cac item la so nguyen, cach nhau boi khoang trang.
- Du lieu trung lap item trong cung transaction se duoc loai bo trong luc doc.
- Output: `item1 item2 ... #SUP: k`

## Notebook va bao cao

- Notebook demo ung dung event log: `notebooks/demo.ipynb`
- Du lieu input demo: `data/eventlog_demo/`
- Ket qua output demo: `data/eventlog_output/`
- Bao cao LaTeX cho phan ung dung: `docs/event_log_report.tex`
