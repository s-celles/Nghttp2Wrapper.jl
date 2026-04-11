"""
    nghttp2_check_header_name(name) → Bool

Check if `name` is a valid HTTP header field name.
"""
function nghttp2_check_header_name(name::Vector{UInt8})
    rv = ccall((:nghttp2_check_header_name, libnghttp2), Cint,
               (Ptr{UInt8}, Csize_t), name, length(name))
    return rv != 0
end

function nghttp2_check_header_name(name::AbstractString)
    nghttp2_check_header_name(Vector{UInt8}(name))
end

"""
    nghttp2_check_header_value(value) → Bool

Check if `value` is a valid HTTP header field value.
"""
function nghttp2_check_header_value(value::Vector{UInt8})
    rv = ccall((:nghttp2_check_header_value, libnghttp2), Cint,
               (Ptr{UInt8}, Csize_t), value, length(value))
    return rv != 0
end

function nghttp2_check_header_value(value::AbstractString)
    nghttp2_check_header_value(Vector{UInt8}(value))
end

"""
    nghttp2_check_authority(authority) → Bool

Check if `authority` is a valid HTTP/2 authority component.
"""
function nghttp2_check_authority(authority::Vector{UInt8})
    rv = ccall((:nghttp2_check_authority, libnghttp2), Cint,
               (Ptr{UInt8}, Csize_t), authority, length(authority))
    return rv != 0
end

function nghttp2_check_authority(authority::AbstractString)
    nghttp2_check_authority(Vector{UInt8}(authority))
end

"""
    nghttp2_check_path(path) → Bool

Check if `path` is a valid HTTP/2 path.
"""
function nghttp2_check_path(path::Vector{UInt8})
    rv = ccall((:nghttp2_check_path, libnghttp2), Cint,
               (Ptr{UInt8}, Csize_t), path, length(path))
    return rv != 0
end

function nghttp2_check_path(path::AbstractString)
    nghttp2_check_path(Vector{UInt8}(path))
end

"""
    nghttp2_check_method(method) → Bool

Check if `method` is a valid HTTP method.
"""
function nghttp2_check_method(method::Vector{UInt8})
    rv = ccall((:nghttp2_check_method, libnghttp2), Cint,
               (Ptr{UInt8}, Csize_t), method, length(method))
    return rv != 0
end

function nghttp2_check_method(method::AbstractString)
    nghttp2_check_method(Vector{UInt8}(method))
end
