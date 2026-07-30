"""
    ServerStream <: IO

A server-side HTTP/2 stream presented to an incremental handler.

Subtypes `IO` so the handler needs no new vocabulary: `read`, `readavailable`,
`readbytes!`, `eof`, `write`, `isopen` and `close` mean what they already mean.

# Supported surface

Only the methods below are implemented. Anything else `Base` offers for `IO`
(`seek`, `readline`, `mark`, ...) is not meaningful on a stream of HTTP/2
frames and is left to fail rather than silently taking a generic path.

Request side: [`eof`](@ref), [`read`](@ref), [`readavailable`](@ref),
[`readbytes!`](@ref).
Response side: [`setstatus`](@ref), [`setheader`](@ref), [`write`](@ref),
[`settrailer`](@ref), [`close`](@ref).

!!! warning "`read(io, n)` returns *at most* `n` bytes"
    As with any `IO`, a short read is neither an error nor end-of-stream — it
    means that much was buffered. Loop until you have what you need, or the
    peer half-closes. Assuming otherwise caps every request at the HTTP/2
    flow-control window.
"""
mutable struct ServerStream <: IO
    id::Int32

    # Request side, fed by the on-data-chunk callback.
    request_buffer::Vector{UInt8}
    request_closed::Bool          # peer half-closed (END_STREAM received)

    # Response side, drained by the data provider.
    status::Union{Int,Nothing}
    headers::Vector{NVPair}
    response_buffer::Vector{UInt8}
    trailers::Vector{NVPair}
    handler_done::Bool

    lock::ReentrantLock
    cond::Threads.Condition
end

function ServerStream(id::Integer)
    l = ReentrantLock()
    ServerStream(Int32(id), UInt8[], false, nothing, NVPair[], UInt8[], NVPair[],
                 false, l, Threads.Condition(l))
end

# --- fed by the connection callbacks ---

"""
    push_request_data!(stream, bytes)

Append received DATA payload and wake anything blocked in `eof`/`read`.
"""
function push_request_data!(s::ServerStream, bytes::Vector{UInt8})
    lock(s.lock) do
        append!(s.request_buffer, bytes)
        notify(s.cond)
    end
    return nothing
end

"""
    close_request!(stream)

Mark the peer's send side as half-closed (END_STREAM received).
"""
function close_request!(s::ServerStream)
    lock(s.lock) do
        s.request_closed = true
        notify(s.cond)
    end
    return nothing
end

# --- request side (IO) ---

"""
    eof(stream::ServerStream) -> Bool

Block until request data is available or the peer half-closes. `true` only when
the buffer is drained *and* no more will arrive.
"""
function Base.eof(s::ServerStream)
    lock(s.lock) do
        while isempty(s.request_buffer) && !s.request_closed
            wait(s.cond)
        end
        return isempty(s.request_buffer) && s.request_closed
    end
end

"""
    readavailable(stream::ServerStream) -> Vector{UInt8}

Take everything currently buffered, blocking until there is something or the
peer half-closes.
"""
function Base.readavailable(s::ServerStream)
    lock(s.lock) do
        while isempty(s.request_buffer) && !s.request_closed
            wait(s.cond)
        end
        out = s.request_buffer
        s.request_buffer = UInt8[]
        return out
    end
end

"""
    read(stream::ServerStream, n::Integer) -> Vector{UInt8}

Read *at most* `n` bytes. See the warning on [`ServerStream`](@ref).
"""
function Base.read(s::ServerStream, n::Integer)
    lock(s.lock) do
        while isempty(s.request_buffer) && !s.request_closed
            wait(s.cond)
        end
        take = min(Int(n), length(s.request_buffer))
        out = s.request_buffer[1:take]
        deleteat!(s.request_buffer, 1:take)
        return out
    end
end

"""
    readbytes!(stream::ServerStream, b::Vector{UInt8}, nb=length(b)) -> Int

Fill `b` with at most `nb` bytes and return how many were written. The buffer
belongs to the caller, so a handler can read a stream of messages without
allocating per message.
"""
function Base.readbytes!(s::ServerStream, b::Vector{UInt8}, nb::Integer=length(b))
    chunk = read(s, nb)
    n = length(chunk)
    n > length(b) && resize!(b, n)
    copyto!(b, 1, chunk, 1, n)
    return n
end

# --- response side ---

"""
    setstatus(stream, status)

Stage the `:status` pseudo-header. Must be called before the first `write`.
"""
setstatus(s::ServerStream, status::Integer) = (lock(s.lock) do; s.status = Int(status) end; nothing)

"""
    setheader(stream, nv)

Stage a response header. Must be called before the first `write`.
"""
setheader(s::ServerStream, nv::NVPair) = (lock(s.lock) do; push!(s.headers, nv) end; nothing)
setheader(s::ServerStream, name::AbstractString, value::AbstractString) =
    setheader(s, NVPair(name, value))

"""
    settrailer(stream, nvs)

Stage the trailing HEADERS block. It is emitted after the body and closes the
stream, so the body itself will not carry END_STREAM.
"""
settrailer(s::ServerStream, nvs::Vector{NVPair}) =
    (lock(s.lock) do; append!(s.trailers, nvs) end; nothing)
settrailer(s::ServerStream, nv::NVPair) = settrailer(s, [nv])

"""
    write(stream::ServerStream, bytes) -> Int

Queue response body bytes. They are handed to nghttp2's data provider as it
asks for them rather than held until the handler returns.
"""
function Base.write(s::ServerStream, bytes::Vector{UInt8})
    lock(s.lock) do
        append!(s.response_buffer, bytes)
        notify(s.cond)
    end
    return length(bytes)
end

Base.unsafe_write(s::ServerStream, p::Ptr{UInt8}, n::UInt) =
    write(s, unsafe_wrap(Array, p, Int(n); own=false) |> copy)

Base.isopen(s::ServerStream) = lock(s.lock) do; !s.handler_done end

"""
    close(stream::ServerStream)

Mark the response as complete. The data provider then reports EOF instead of
deferring.
"""
function Base.close(s::ServerStream)
    lock(s.lock) do
        s.handler_done = true
        notify(s.cond)
    end
    return nothing
end

# --- read back by the data provider ---

response_status(s::ServerStream) = lock(s.lock) do; s.status end
response_headers(s::ServerStream) = lock(s.lock) do; copy(s.headers) end
response_trailers(s::ServerStream) = lock(s.lock) do; copy(s.trailers) end

"""
    take_response_data!(stream) -> Vector{UInt8}

Take everything queued so far, without blocking.
"""
function take_response_data!(s::ServerStream)
    lock(s.lock) do
        out = s.response_buffer
        s.response_buffer = UInt8[]
        return out
    end
end

"""
    response_complete(stream) -> Bool

`true` when the handler has finished and nothing is left to send. The data
provider uses this to choose between `NGHTTP2_DATA_FLAG_EOF` and
`NGHTTP2_ERR_DEFERRED`.
"""
response_complete(s::ServerStream) =
    lock(s.lock) do; s.handler_done && isempty(s.response_buffer) end
