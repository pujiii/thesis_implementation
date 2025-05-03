using CSV, DataFrames, Statistics, Plots

function plot_macro_graph(filepath::String)
    # Load raw data
    df = CSV.read(filepath, DataFrame)

    # Get the baseline for normalization (mean for num_macros = 0)
    baseline = mean(df.expanded[df.num_macros .== 0])

    # Normalize expanded values
    df.expanded .= df.expanded ./ baseline

    # Group + aggregate
    grouped = combine(groupby(df, :num_macros)) do subdf
        mean_val = mean(subdf.expanded)
        std_val = std(subdf.expanded)
        (; num_macros = subdf.num_macros[1], mean = mean_val, stderr = std_val)
    end

    # Plot with ribbon
    p = plot(
        grouped.num_macros, grouped.mean;
        ribbon = grouped.stderr,
        seriestype = :line,
        markershape = :circle,
        color = :red,
        linewidth = 2,
        label = "",
        fillalpha = 0.2,
        markerstrokecolor = :red,
        markercolor = :red,
        legend = false
    )

    # Labels & aesthetics
    xlabel!(p, "#macros")
    ylabel!(p, "normalized expanded 1")
    title!(p, "what number of macro-actions")
    # grid!(:both)
    xlims!(minimum(grouped.num_macros) - 0.5, maximum(grouped.num_macros) + 0.5)

    # Save it, queen
    savefig(p, "results.png")
end


plot_macro_graph("output_experiments/2025-05-02_165237.csv")