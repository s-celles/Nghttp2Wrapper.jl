"""
    ConnectionPool(; max_per_host=6, idle_timeout=60.0)

A pool of HTTP/2 client connections with automatic reuse and keep-alive.

# Examples
```julia
pool = ConnectionPool()
response = pool_get(pool, "https://nghttp2.org/")
close(pool)
```
"""
mutable struct ConnectionPool
    connections::Dict{String,Vector{HTTP2Client}}
    max_per_host::Int
    idle_timeout::Float64
    timestamps::Dict{UInt64,Float64}
    lock::ReentrantLock
    isopen::Bool
end

function ConnectionPool(; max_per_host::Integer=6, idle_timeout::Real=60.0)
    ConnectionPool(
        Dict{String,Vector{HTTP2Client}}(),
        Int(max_per_host),
        Float64(idle_timeout),
        Dict{UInt64,Float64}(),
        ReentrantLock(),
        true
    )
end

function Base.close(pool::ConnectionPool)
    if pool.isopen
        pool.isopen = false
        lock(pool.lock) do
            for (_, clients) in pool.connections
                for c in clients
                    try; close(c); catch; end
                end
            end
            empty!(pool.connections)
            empty!(pool.timestamps)
        end
    end
    return nothing
end

Base.isopen(pool::ConnectionPool) = pool.isopen

function Base.show(io::IO, pool::ConnectionPool)
    state = pool.isopen ? "open" : "closed"
    n = lock(pool.lock) do
        sum(length(v) for v in values(pool.connections); init=0)
    end
    print(io, "ConnectionPool($(state), $(n) connections)")
end

"""
    acquire(pool, host; port=443, verify_peer=true) → HTTP2Client

Get a client from the pool. Reuses an idle connection if available,
otherwise creates a new one.
"""
function acquire(pool::ConnectionPool, host::AbstractString;
                 port::Integer=443, verify_peer::Bool=true)
    _check_open(pool, "ConnectionPool")
    key = "$(host):$(port)"
    now = time()

    cached = lock(pool.lock) do
        if haskey(pool.connections, key)
            clients = pool.connections[key]
            while !isempty(clients)
                c = pop!(clients)
                if isopen(c)
                    id = objectid(c)
                    ts = get(pool.timestamps, id, now)
                    if (now - ts) < pool.idle_timeout
                        delete!(pool.timestamps, id)
                        return c
                    else
                        try; close(c); catch; end
                        delete!(pool.timestamps, id)
                    end
                end
            end
        end
        return nothing
    end

    if cached !== nothing
        return cached
    end

    # No idle client available — create new
    return HTTP2Client(host; port=port, verify_peer=verify_peer)
end

"""
    release(pool, client) → Nothing

Return a client to the pool for reuse.
"""
function release(pool::ConnectionPool, client::HTTP2Client)
    if !pool.isopen || !isopen(client)
        try; close(client); catch; end
        return nothing
    end

    key = "$(client.host):$(client.port)"
    lock(pool.lock) do
        clients = get!(Vector{HTTP2Client}, pool.connections, key)
        if length(clients) < pool.max_per_host
            push!(clients, client)
            pool.timestamps[objectid(client)] = time()
        else
            try; close(client); catch; end
        end
    end
    return nothing
end

"""
    pool_request(pool, method, url; headers=NVPair[], body=UInt8[]) → Response

Make a request using a pooled connection. The URL is parsed to extract
host, port, and path. The connection is automatically acquired and released.
"""
function pool_request(pool::ConnectionPool, method::AbstractString, url::AbstractString;
                      headers::Vector{NVPair}=NVPair[], body::Vector{UInt8}=UInt8[])
    uri = URIs.URI(url)
    host = uri.host
    port = isempty(uri.port) ? (uri.scheme == "https" ? 443 : 80) : parse(Int, uri.port)
    path = isempty(uri.path) ? "/" : uri.path
    if !isempty(uri.query)
        path = path * "?" * uri.query
    end

    client = acquire(pool, host; port=port)
    try
        resp = request(client, method, path; headers=headers, body=body)
        release(pool, client)
        return resp
    catch e
        try; close(client); catch; end
        rethrow()
    end
end

"""
    pool_get(pool, url; headers=NVPair[]) → Response

Make a GET request using a pooled connection.
"""
function pool_get(pool::ConnectionPool, url::AbstractString;
                  headers::Vector{NVPair}=NVPair[])
    pool_request(pool, "GET", url; headers=headers)
end

"""
    pool_post(pool, url; headers=NVPair[], body=UInt8[]) → Response

Make a POST request using a pooled connection.
"""
function pool_post(pool::ConnectionPool, url::AbstractString;
                   headers::Vector{NVPair}=NVPair[], body::Vector{UInt8}=UInt8[])
    pool_request(pool, "POST", url; headers=headers, body=body)
end
