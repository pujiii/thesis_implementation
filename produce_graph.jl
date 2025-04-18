using DataFrames, Plots, Statistics

# Parses the new output format
function parse_baking_file(filename)
    df = DataFrame(condition=String[], problem=String[], time=Float64[], macros=Int[])
    max_macro = 0
    for line in eachline(filename)
        if occursin("baking:", line)
            # Before training
            matches = eachmatch(r"\(\"(.*?)\", \"(.*?)\", (.*?)\)", line)
            for m in matches
                push!(df, (
                    condition = "before training",
                    problem = m.captures[2],
                    time = parse(Float64, m.captures[3]),
                    macros = 0
                ))
            end
        elseif occursin("baking (", line)
            # After training
            macros_match = match(r"baking \((\d+) macros\):", line)
            macros = parse(Int, macros_match.captures[1])
            max_macro = max(max_macro, macros)
            matches = eachmatch(r"\(\"(.*?)\", \"(.*?)\", (.*?)\)", line)
            for m in matches
                push!(df, (
                    condition = "after training",
                    problem = m.captures[2],
                    time = parse(Float64, m.captures[3]),
                    macros = macros
                ))
            end
        end
    end
    return df, max_macro
end

# Aggregate total time for plotting
function total_time_per_macro(df, max_macro)
    base = combine(groupby(df[df.condition .== "before training", :], :problem), :time => mean => :base_time)
    base_total = sum(base.base_time)
    
    after = combine(groupby(df[df.condition .== "after training", :], [:macros]), :time => sum => :total_time)
    after.condition = ["after training" for _ in 1:nrow(after)]

    # Repeat before training line across macro counts
    before = DataFrame(macros = 0:max_macro, total_time = fill(base_total, max_macro + 1))
    before.condition = ["before training" for _ in 1:nrow(before)]

    return vcat(before, after)
end

# Plotting, with our hot flat line 💋
function plot_macro_vs_time(df)
    plt = plot()
    grouped = groupby(df, :condition)
    for g in grouped
        plot!(plt, g.macros, g.total_time,
              label = g.condition[1],
              marker = :circle,
              linewidth = 2)
    end
    xlabel!("Number of Macro Actions")
    ylabel!("Total Time (s)")
    title!("Macro Count vs Total Time to Solve All Problems")
    return plt
end

# Main glam routine
data, max_macro = parse_baking_file("output_experiments.txt")
agg = total_time_per_macro(data, max_macro)
plott = plot_macro_vs_time(agg)
savefig(plott, "baking_macros_flatline.png")
