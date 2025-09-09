# datastructure.jl - Refactored version

export Punkt, Kante, Dreieck, Delaunay, GamePoint
export init_delaunay, create_triangle, find_triangle
export triangle_orientation

# Basic point type
struct Punkt
    x::Float64
    y::Float64
end

# Game point type
mutable struct GamePoint
    x::Float64
    y::Float64
    player::Int
end

# Abstract face type for DCEL
abstract type Face end

# Edge in DCEL structure
mutable struct Kante
    origin::Punkt
    twin::Union{Kante,Nothing}
    next::Union{Kante, Nothing}
    prev::Union{Kante, Nothing}
    face::Union{Face, Nothing}
    
    Kante(origin::Punkt) = new(origin, nothing, nothing, nothing, nothing)
end

# Triangle face
mutable struct Dreieck <: Face
    edge::Kante
end

# Delaunay triangulation structure
mutable struct Delaunay
    triangles::Set{Dreieck}
    bounding_triangle::Dreieck
end

"""
    init_delaunay(a::Punkt, b::Punkt, c::Punkt) -> Delaunay
Creates initial Delaunay triangulation from three points.
"""
function init_delaunay(a::Punkt, b::Punkt, c::Punkt)
    T0 = create_triangle(a, b, c)
    tris = Set{Dreieck}()
    push!(tris, T0)
    return Delaunay(tris, T0)
end

"""
    create_triangle(a::Punkt, b::Punkt, c::Punkt) -> Dreieck
Creates a triangle with proper DCEL structure and CCW orientation.
""" 
function create_triangle(a::Punkt, b::Punkt, c::Punkt)::Dreieck
    # Ensure counter-clockwise orientation
    if triangle_orientation(a, b, c) < 0
        b, c = c, b
    end

    # Create edges
    edge1 = Kante(a)  # a -> b
    edge2 = Kante(b)  # b -> c  
    edge3 = Kante(c)  # c -> a

    # Create triangle
    T = Dreieck(edge1)

    # Set face references
    edge1.face = T
    edge2.face = T
    edge3.face = T

    # Link edges (counter-clockwise)
    edge1.next = edge2
    edge2.next = edge3
    edge3.next = edge1
    
    edge1.prev = edge3
    edge2.prev = edge1
    edge3.prev = edge2

    # Twins set to nothing (connected later)
    edge1.twin = nothing
    edge2.twin = nothing  
    edge3.twin = nothing
    
    return T
end

"""
    find_triangle(p::Punkt, D::Delaunay) -> Union{Dreieck, Nothing}
Finds triangle containing point p using orientation method.
"""
function find_triangle(p::Punkt, D::Delaunay)
    for tri in D.triangles
        a = tri.edge.origin
        b = tri.edge.next.origin
        c = tri.edge.next.next.origin

        # Point-in-triangle test using orientations
        o1 = triangle_orientation(a, b, p)
        o2 = triangle_orientation(b, c, p)
        o3 = triangle_orientation(c, a, p)
        
        if (o1 >= 0 && o2 >= 0 && o3 >= 0) || (o1 <= 0 && o2 <= 0 && o3 <= 0)
            return tri
        end
    end
    return nothing
end

"""
    triangle_orientation(a::Punkt, b::Punkt, c::Punkt)
Computes orientation of three points (positive = CCW, negative = CW).
"""
function triangle_orientation(a::Punkt, b::Punkt, c::Punkt)
    return (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
end

import Base.isapprox
function isapprox(p1::Punkt, p2::Punkt; atol::Real=1e-10)
    return isapprox(p1.x, p2.x, atol=atol) && isapprox(p1.y, p2.y, atol=atol)
end