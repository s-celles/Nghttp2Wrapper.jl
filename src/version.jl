"""
    nghttp2_version(least_version=0) → Ptr{Nghttp2Info}

Return a pointer to the nghttp2 library version information.
If `least_version` is not 0, returns `C_NULL` if the library version
is less than the specified version.
"""
function nghttp2_version(least_version::Integer=0)
    ccall((:nghttp2_version, libnghttp2), Ptr{Nghttp2Info}, (Cint,), least_version)
end

"""
    nghttp2_strerror(lib_error_code) → String

Return a human-readable string describing the given nghttp2 error code.
"""
function nghttp2_strerror(lib_error_code::Integer)
    ptr = ccall((:nghttp2_strerror, libnghttp2), Cstring, (Cint,), lib_error_code)
    return unsafe_string(ptr)
end

"""
    nghttp2_is_fatal(lib_error_code) → Bool

Return `true` if the given error code is fatal.
"""
function nghttp2_is_fatal(lib_error_code::Integer)
    rv = ccall((:nghttp2_is_fatal, libnghttp2), Cint, (Cint,), lib_error_code)
    return rv != 0
end
