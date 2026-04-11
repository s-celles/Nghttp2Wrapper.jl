struct Nghttp2Info
    age::Cint
    version_num::Cint
    version_str::Cstring
    proto_str::Cstring
end

struct Nghttp2Nv
    name::Ptr{UInt8}
    value::Ptr{UInt8}
    namelen::Csize_t
    valuelen::Csize_t
    flags::UInt8
end

struct Nghttp2SettingsEntry
    settings_id::Int32
    value::UInt32
end
