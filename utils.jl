function rename_key!(dict::Dict, old_key, new_key)
    if haskey(dict, old_key)
        value = dict[old_key]
        delete!(dict, old_key)
        dict[new_key] = value
    end
    return dict
end

