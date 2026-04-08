module MemoryTracking

using ..Structures: MiningStats

export reset_memory_tracking!, sample_memory!, memory_tracking_supported

struct PROCESS_MEMORY_COUNTERS_EX
    cb::UInt32
    PageFaultCount::UInt32
    PeakWorkingSetSize::Csize_t
    WorkingSetSize::Csize_t
    QuotaPeakPagedPoolUsage::Csize_t
    QuotaPagedPoolUsage::Csize_t
    QuotaPeakNonPagedPoolUsage::Csize_t
    QuotaNonPagedPoolUsage::Csize_t
    PagefileUsage::Csize_t
    PeakPagefileUsage::Csize_t
    PrivateUsage::Csize_t
end

memory_tracking_supported() = Sys.iswindows()

function empty_process_memory_counters()
    return PROCESS_MEMORY_COUNTERS_EX(
        UInt32(sizeof(PROCESS_MEMORY_COUNTERS_EX)),
        UInt32(0),
        zero(Csize_t),
        zero(Csize_t),
        zero(Csize_t),
        zero(Csize_t),
        zero(Csize_t),
        zero(Csize_t),
        zero(Csize_t),
        zero(Csize_t),
        zero(Csize_t),
    )
end

function read_process_memory()
    if !memory_tracking_supported()
        return nothing
    end

    handle = ccall((:GetCurrentProcess, "kernel32"), Ptr{Cvoid}, ())
    counters = Ref(empty_process_memory_counters())
    success = ccall(
        (:GetProcessMemoryInfo, "psapi"),
        Int32,
        (Ptr{Cvoid}, Ref{PROCESS_MEMORY_COUNTERS_EX}, UInt32),
        handle,
        counters,
        UInt32(sizeof(PROCESS_MEMORY_COUNTERS_EX)),
    )

    if success == 0
        return nothing
    end

    data = counters[]
    return Int(data.WorkingSetSize)
end

function reset_memory_tracking!(stats::MiningStats)
    stats.peak_working_set_bytes = 0

    sample = read_process_memory()
    if sample === nothing
        return stats
    end

    stats.peak_working_set_bytes = sample
    return stats
end

function sample_memory!(stats::Nothing)
    return nothing
end

function sample_memory!(stats::MiningStats)
    sample = read_process_memory()
    if sample === nothing
        return nothing
    end

    stats.peak_working_set_bytes = max(stats.peak_working_set_bytes, sample)
    return nothing
end

end
