"""
    Nghttp2Error <: Exception

Exception thrown when an nghttp2 C function returns an error code.

# Fields
- `code::Cint` — the nghttp2 error code
- `msg::String` — human-readable error description
- `fatal::Bool` — true if the error is fatal (unrecoverable)
"""
struct Nghttp2Error <: Exception
    code::Cint
    msg::String
    fatal::Bool
end

"""
    Nghttp2Error(code::Integer)

Construct an `Nghttp2Error` from an error code, automatically
filling the message and fatal flag.
"""
function Nghttp2Error(code::Integer)
    Nghttp2Error(Cint(code), nghttp2_strerror(code), nghttp2_is_fatal(code))
end

function Base.showerror(io::IO, e::Nghttp2Error)
    fatal_str = e.fatal ? " [FATAL]" : ""
    print(io, "Nghttp2Error($(e.code)): $(e.msg)$(fatal_str)")
end

"""
    check_error(rv::Integer)

Check an nghttp2 return value. If negative, throw `Nghttp2Error`.
Otherwise return `rv`.
"""
function check_error(rv::Integer)
    if rv < 0
        throw(Nghttp2Error(rv))
    end
    return rv
end
