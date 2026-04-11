"""
    request(client, method, path; headers=NVPair[], body=UInt8[]) → Response

Send an HTTP/2 request and wait for the response.
Pseudo-headers (`:method`, `:path`, `:scheme`, `:authority`) are
automatically constructed.
"""
function request(client::HTTP2Client, method::AbstractString, path::AbstractString;
                 headers::Vector{NVPair}=NVPair[], body::Vector{UInt8}=UInt8[])
    _check_open(client, "HTTP2Client")

    # Build pseudo-headers + custom headers
    all_headers = NVPair[
        NVPair(":method", String(method)),
        NVPair(":path", String(path)),
        NVPair(":scheme", "https"),
        NVPair(":authority", client.host),
    ]
    append!(all_headers, headers)

    # Convert to C-compatible nva
    nva = [to_nghttp2_nv(nv) for nv in all_headers]

    # Submit request
    stream_id = GC.@preserve all_headers nva begin
        nghttp2_submit_request2(client.session_ptr, C_NULL,
                                 pointer(nva), length(nva),
                                 C_NULL, C_NULL)
    end

    if stream_id < 0
        check_error(stream_id)
    end

    # Create stream state
    st = StreamState(stream_id)
    lock(client.ctx.lock) do
        client.ctx.streams[stream_id] = st
    end

    # Flush outgoing data
    try
        outdata = _session_send_all(client.session_ptr)
        if !isempty(outdata)
            write(client.tls_stream, outdata)
        end
    catch e
        lock(client.ctx.lock) do
            delete!(client.ctx.streams, stream_id)
        end
        rethrow()
    end

    # Wait for response
    resp = take!(st.done)
    return resp
end

"""
    request_stream(client, method, path; headers=NVPair[], body=UInt8[]) → (Channel{Response}, Channel{Vector{UInt8}})

Send an HTTP/2 request with streaming response body.
Returns a done channel and a body chunks channel.
"""
function request_stream(client::HTTP2Client, method::AbstractString, path::AbstractString;
                        headers::Vector{NVPair}=NVPair[], body::Vector{UInt8}=UInt8[])
    _check_open(client, "HTTP2Client")

    all_headers = NVPair[
        NVPair(":method", String(method)),
        NVPair(":path", String(path)),
        NVPair(":scheme", "https"),
        NVPair(":authority", client.host),
    ]
    append!(all_headers, headers)

    nva = [to_nghttp2_nv(nv) for nv in all_headers]

    stream_id = GC.@preserve all_headers nva begin
        nghttp2_submit_request2(client.session_ptr, C_NULL,
                                 pointer(nva), length(nva),
                                 C_NULL, C_NULL)
    end

    if stream_id < 0
        check_error(stream_id)
    end

    st = StreamState(stream_id; streaming=true)
    lock(client.ctx.lock) do
        client.ctx.streams[stream_id] = st
    end

    try
        outdata = _session_send_all(client.session_ptr)
        if !isempty(outdata)
            write(client.tls_stream, outdata)
        end
    catch e
        lock(client.ctx.lock) do
            delete!(client.ctx.streams, stream_id)
        end
        rethrow()
    end

    return (st.done, st.chunks)
end

"""
    shutdown!(client::HTTP2Client)

Initiate graceful shutdown by sending a GOAWAY frame and waiting
for all pending streams to complete.
"""
function shutdown!(client::HTTP2Client)
    _check_open(client, "HTTP2Client")
    nghttp2_submit_goaway(client.session_ptr, 0, 0)
    outdata = _session_send_all(client.session_ptr)
    if !isempty(outdata)
        try
            write(client.tls_stream, outdata)
        catch
        end
    end
    try
        wait(client.io_task)
    catch
    end
    close(client)
end

# --- Convenience methods ---

"""
    get(client, path; headers=NVPair[]) → Response

Send an HTTP/2 GET request.
"""
function Base.get(client::HTTP2Client, path::AbstractString; headers::Vector{NVPair}=NVPair[])
    request(client, "GET", path; headers=headers)
end

"""
    post(client, path; headers=NVPair[], body=UInt8[]) → Response

Send an HTTP/2 POST request.
"""
function post(client::HTTP2Client, path::AbstractString;
              headers::Vector{NVPair}=NVPair[], body::Vector{UInt8}=UInt8[])
    request(client, "POST", path; headers=headers, body=body)
end

function post(client::HTTP2Client, path::AbstractString, body::AbstractString;
              headers::Vector{NVPair}=NVPair[])
    request(client, "POST", path; headers=headers, body=Vector{UInt8}(body))
end

"""
    put(client, path; headers=NVPair[], body=UInt8[]) → Response
"""
function put(client::HTTP2Client, path::AbstractString;
             headers::Vector{NVPair}=NVPair[], body::Vector{UInt8}=UInt8[])
    request(client, "PUT", path; headers=headers, body=body)
end

"""
    delete(client, path; headers=NVPair[]) → Response
"""
function delete(client::HTTP2Client, path::AbstractString; headers::Vector{NVPair}=NVPair[])
    request(client, "DELETE", path; headers=headers)
end

"""
    patch(client, path; headers=NVPair[], body=UInt8[]) → Response
"""
function patch(client::HTTP2Client, path::AbstractString;
               headers::Vector{NVPair}=NVPair[], body::Vector{UInt8}=UInt8[])
    request(client, "PATCH", path; headers=headers, body=body)
end

"""
    head(client, path; headers=NVPair[]) → Response
"""
function head(client::HTTP2Client, path::AbstractString; headers::Vector{NVPair}=NVPair[])
    request(client, "HEAD", path; headers=headers)
end

"""
    options(client, path; headers=NVPair[]) → Response
"""
function options(client::HTTP2Client, path::AbstractString; headers::Vector{NVPair}=NVPair[])
    request(client, "OPTIONS", path; headers=headers)
end
