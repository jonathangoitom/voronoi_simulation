# delaunay.jl - Cleaned core implementation

#=
using Pkg
Pkg.activate(".")
using VoronoiGame
VoronoiGame.run_game()
=#

using LinearAlgebra

export insert_point!, check_umkreis, flip!, recursive_flip!

# Global tolerance constant
const TOL = 1e-10


"""
    check_umkreis(e::Kante) -> Bool
Checks if circumcircle of triangle containing edge e contains the opposite point.
"""
function check_umkreis(e::Kante)::Bool
    e.twin === nothing && return true
    e.twin.face === nothing && return true
    
    # Get the four points
    a = e.origin
    b = e.next.origin  
    c = e.next.next.origin
    
    # Find opposite point in twin triangle
    twin_vertices = (e.twin.origin, e.twin.next.origin, e.twin.next.next.origin)
    d = first(v for v in twin_vertices if v != a && v != b)
    
    # Don't flip bounding edges
    bounding_vertices = (Punkt(-300.0, -300.0), Punkt(400.0, -300.0), Punkt(50.0, 400.0))
    (a in bounding_vertices && b in bounding_vertices) && return true
    
    # Circumcircle test using determinant
    mat = [
        a.x   a.y   a.x^2 + a.y^2   1;
        b.x   b.y   b.x^2 + b.y^2   1;
        c.x   c.y   c.x^2 + c.y^2   1;
        d.x   d.y   d.x^2 + d.y^2   1;
    ]
    
    det_val = det(mat)
    result = det_val <= TOL
    debug_println("Circumcircle check for edge ($a, $b): det = $det_val ($(result ? "Delaunay" : "NOT Delaunay"))")
    
    return result
end


"""
    rebuild_all_twins!(D::Delaunay)
Rebuilds twin connections efficiently.
O(n)
"""
function rebuild_all_twins!(D::Delaunay)
    # Clear existing twins
    for tri in D.triangles
        for edge in (tri.edge, tri.edge.next, tri.edge.next.next)
            edge.twin = nothing
        end
    end
    
    # Find matching edges
    edge_dict = Dict{Tuple{Punkt,Punkt}, Kante}()
    for tri in D.triangles
        for edge in (tri.edge, tri.edge.next, tri.edge.next.next)
            key = (edge.origin, edge.next.origin)
            if haskey(edge_dict, reverse(key))
                twin_edge = edge_dict[reverse(key)]
                edge.twin = twin_edge
                twin_edge.twin = edge
            else
                edge_dict[key] = edge
            end
        end
    end
end

"""
    flip!(e::Kante, D::Delaunay)
Performs edge flip operation.
O(n)
"""
function flip!(e::Kante, D::Delaunay)
    if e.twin === nothing || e.twin.face === nothing
        debug_println("Skipping flip: no twin or face for edge ($(e.origin), $(e.next.origin))")
        return
    end
    
    # Get quadrilateral points
    a = e.origin
    b = e.next.origin
    c = e.next.next.origin
    twin_vertices = (e.twin.origin, e.twin.next.origin, e.twin.next.next.origin)
    d = first(v for v in twin_vertices if v != a && v != b)
    
    if d === nothing
        debug_println("Skipping flip: couldn't find opposite point for edge ($(e.origin), $(e.next.origin))")
        return
    end
    
    debug_println("Flipping edge: ($a, $b) in quadrilateral: $a, $c, $b, $d")
    
    # Remove old triangles
    old_tri1, old_tri2 = e.face, e.twin.face
    delete!(D.triangles, old_tri1)
    delete!(D.triangles, old_tri2)
    
    # Create new triangles with proper orientation
    T1 = create_triangle(a, c, d)
    T2 = create_triangle(b, d, c)  # Note order change for consistent orientation
    
    push!(D.triangles, T1, T2)
    
    # Rebuild twin connections
    rebuild_all_twins!(D)
    
    # Validate after flip
    validate_delaunay(D)
    print_triangulation(D)
end

"""
    recursive_flip!(e::Kante, D::Delaunay)
"""
function recursive_flip!(e::Kante, D::Delaunay)
    debug_println("\nChecking edge for flipping: ($(e.origin), $(e.next.origin))")
    
    if !check_umkreis(e)
        debug_println("Circumcircle condition FAILED - flipping edge ($(e.origin), $(e.next.origin))")
        
        flip!(e, D)
        
        # Find new edges to check
        a = e.origin
        b = e.next.origin
        c = e.next.next.origin
        twin_vertices = [e.twin.origin, e.twin.next.origin, e.twin.next.next.origin]
        d = first(v for v in twin_vertices if v != a && v != b)
        
        # Recursively check new edges
        for (p1, p2) in [(a, c), (b, d), (c, d), (a, d)]
            new_edge = find_edge(p1, p2, D)
            if new_edge !== nothing
                debug_println("Recursively checking new edge: ($p1, $p2)")
                recursive_flip!(new_edge, D)
            end
        end
    else
        debug_println("Circumcircle condition satisfied - keeping edge ($(e.origin), $(e.next.origin))")
    end
end

"""
    find_edge(a::Punkt, b::Punkt, D::Delaunay) -> Union{Kante, Nothing}
Finds edge between two points.
"""
function find_edge(a::Punkt, b::Punkt, D::Delaunay)
    for tri in D.triangles
        for edge in (tri.edge, tri.edge.next, tri.edge.next.next)
            if isapprox(edge.origin, a) && isapprox(edge.next.origin, b)
                return edge
            end
        end
    end
    return nothing
end

"""
    insert_point!(p::Punkt, D::Delaunay)
Inserts point into Delaunay triangulation.
O(n²)
"""
function insert_point!(p::Punkt, D::Delaunay)
    # Check for duplicate
    for tri in D.triangles
        a, b, c = tri.edge.origin, tri.edge.next.origin, tri.edge.next.next.origin
        (isapprox(p, a) || isapprox(p, b) || isapprox(p, c)) && return
    end

    # Find containing triangle
    tri = find_triangle(p, D)
    tri === nothing && return
    
    # Get vertices
    a, b, c = tri.edge.origin, tri.edge.next.origin, tri.edge.next.next.origin
    
    # Create new triangles
    new_tris = [create_triangle(a, b, p), create_triangle(b, c, p), create_triangle(c, a, p)]
    
    # Update triangulation
    delete!(D.triangles, tri)
    union!(D.triangles, new_tris)
    rebuild_all_twins!(D)

    debug_println("Point inserted: $p")
    validate_delaunay(D)
    print_triangulation(D)
    
    # Check edges for flipping
    for edge in [(a,b), (b,c), (c,a)]
        e = find_edge(edge..., D)
        if e !== nothing
            debug_println("Checking edge after insertion: ($(edge[1]), $(edge[2]))")
            recursive_flip!(e, D)
        end
    end
end