module VoronoiGame

using GtkObservables, Colors
using GtkObservables.Gtk4
using GtkObservables.Cairo
using LinearAlgebra

# Export all needed types and functions
export run_game, GameState, run_tests
export Punkt, Kante, Dreieck, Delaunay, GamePoint
export init_delaunay, create_triangle, find_triangle
export insert_point!, check_umkreis, flip!, recursive_flip!
export VoronoiDiagram, VoronoiRegion, calculate_voronoi_delaunay

# Include all submodules
include("datastructure.jl")
include("delaunay.jl") 
include("voronoi.jl")
include("visual.jl")

# Debug utilities
include("debug.jl")

# Test system
include("tests.jl")

"""
    run_game()
    
Starts the Voronoi game with GUI.
"""
function run_game()
    println("Starting Voronoi Game...")
    c = main()
    
    # Keep window open in non-interactive mode
    if !isinteractive()
        c.widget.toplevel.show()
        Gtk4.GLib.glib_main()
    end
    
    return c
end

end # module VoronoiGame