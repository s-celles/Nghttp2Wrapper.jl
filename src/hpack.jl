"""
    nghttp2_hd_deflate_new(max_deflate_dynamic_table_size=4096) → (Cint, Ptr{Cvoid})

Create a new HPACK deflater (compressor).
"""
function nghttp2_hd_deflate_new(max_deflate_dynamic_table_size::Integer=4096)
    deflater_ptr = Ref{Ptr{Cvoid}}(C_NULL)
    rv = ccall((:nghttp2_hd_deflate_new, libnghttp2), Cint,
               (Ptr{Ptr{Cvoid}}, Csize_t), deflater_ptr, max_deflate_dynamic_table_size)
    return (rv, deflater_ptr[])
end

"""
    nghttp2_hd_deflate_del(deflater)

Free an HPACK deflater.
"""
function nghttp2_hd_deflate_del(deflater::Ptr{Cvoid})
    ccall((:nghttp2_hd_deflate_del, libnghttp2), Cvoid, (Ptr{Cvoid},), deflater)
    return nothing
end

"""
    nghttp2_hd_deflate_hd2(deflater, buf, buflen, nva, nvlen) → Cssize_t

Compress headers into `buf`. Returns the number of bytes written,
or a negative error code.
"""
function nghttp2_hd_deflate_hd2(deflater::Ptr{Cvoid}, buf::Vector{UInt8},
                                 nva::Vector{Nghttp2Nv})
    ccall((:nghttp2_hd_deflate_hd2, libnghttp2), Cssize_t,
          (Ptr{Cvoid}, Ptr{UInt8}, Csize_t, Ptr{Nghttp2Nv}, Csize_t),
          deflater, buf, length(buf), nva, length(nva))
end

function nghttp2_hd_deflate_hd2(deflater::Ptr{Cvoid}, buf::Ptr{UInt8}, buflen::Integer,
                                 nva::Ptr{Nghttp2Nv}, nvlen::Integer)
    ccall((:nghttp2_hd_deflate_hd2, libnghttp2), Cssize_t,
          (Ptr{Cvoid}, Ptr{UInt8}, Csize_t, Ptr{Nghttp2Nv}, Csize_t),
          deflater, buf, buflen, nva, nvlen)
end

"""
    nghttp2_hd_inflate_new() → (Cint, Ptr{Cvoid})

Create a new HPACK inflater (decompressor).
"""
function nghttp2_hd_inflate_new()
    inflater_ptr = Ref{Ptr{Cvoid}}(C_NULL)
    rv = ccall((:nghttp2_hd_inflate_new, libnghttp2), Cint,
               (Ptr{Ptr{Cvoid}},), inflater_ptr)
    return (rv, inflater_ptr[])
end

"""
    nghttp2_hd_inflate_del(inflater)

Free an HPACK inflater.
"""
function nghttp2_hd_inflate_del(inflater::Ptr{Cvoid})
    ccall((:nghttp2_hd_inflate_del, libnghttp2), Cvoid, (Ptr{Cvoid},), inflater)
    return nothing
end

"""
    nghttp2_hd_inflate_hd2(inflater, nv_out, inflate_flags, data, datalen, in_final) → Cssize_t

Decompress headers from `data`. On each call, check `inflate_flags`
for `NGHTTP2_HD_INFLATE_EMIT` (header available in `nv_out`) and
`NGHTTP2_HD_INFLATE_FINAL` (decompression complete).
"""
function nghttp2_hd_inflate_hd2(inflater::Ptr{Cvoid}, nv_out::Ref{Nghttp2Nv},
                                 inflate_flags::Ref{Cint},
                                 data::Ptr{UInt8}, datalen::Integer, in_final::Integer)
    ccall((:nghttp2_hd_inflate_hd2, libnghttp2), Cssize_t,
          (Ptr{Cvoid}, Ptr{Nghttp2Nv}, Ptr{Cint}, Ptr{UInt8}, Csize_t, Cint),
          inflater, nv_out, inflate_flags, data, datalen, in_final)
end
