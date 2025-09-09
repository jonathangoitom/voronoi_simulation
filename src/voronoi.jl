# voronoi.jl - Fixed version with proper area calculation

using LinearAlgebra

export VoronoiDiagram, VoronoiRegion, calculate_voronoi_delaunay

struct VoronoiRegion
    center::Punkt
    vertices::Vector{Punkt}
    player::Int
end

struct VoronoiDiagram
    regions::Vector{VoronoiRegion}
end

"""
    circumcenter(triangle::Dreieck) -> Union{Punkt, Nothing}
Computes circumcenter of a triangle.
"""
function circumcenter(t::Dreieck)
    a, b, c = t.edge.origin, t.edge.next.origin, t.edge.next.next.origin
    
    # Degenerate check
    if isapprox(a, b) || isapprox(b, c) || isapprox(c, a)
        debug_println("Degenerate triangle: $a, $b, $c")
        return nothing
    end
    
    # Calculate differences
    d = 2 * ((a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)))
    
    if abs(d) < TOL
        debug_println("Degenerate triangle (collinear): $a, $b, $c")
        return nothing
    end
    
    # Calculate circumcenter coordinates
    ux = (a.x^2 + a.y^2) * (b.y - c.y) +
         (b.x^2 + b.y^2) * (c.y - a.y) +
         (c.x^2 + c.y^2) * (a.y - b.y)
    
    uy = (a.x^2 + a.y^2) * (c.x - b.x) +
         (b.x^2 + b.y^2) * (a.x - c.x) +
         (c.x^2 + c.y^2) * (b.x - a.x)
    
    return Punkt(ux / d, uy / d)
end

"""
    calculate_voronoi_delaunay(game_points::Vector{GamePoint})::VoronoiDiagram
Calculate Voronoi diagram using Delaunay triangulation.
O(n²)
"""
function calculate_voronoi_delaunay(game_points::Vector{GamePoint})::VoronoiDiagram
    if isempty(game_points)
        return VoronoiDiagram(VoronoiRegion[])
    end
    
    # Create Delaunay triangulation
    field_size = 100.0  # Default field size
    margin = field_size * 3.0
    p1 = Punkt(-margin, -margin)
    p2 = Punkt(field_size + margin, -margin)
    p3 = Punkt(field_size/2, field_size + margin)
    
    D = init_delaunay(p1, p2, p3)
    
    # Insert game points
    for game_point in game_points
        p = Punkt(game_point.x, game_point.y)
        insert_point!(p, D)
    end
    
    return delaunay_to_voronoi(D, game_points, field_size)
end

"""
    delaunay_to_voronoi(D::Delaunay, game_points::Vector{GamePoint}, field_size::Float64)::VoronoiDiagram
Convert Delaunay triangulation to Voronoi diagram.
"""
function delaunay_to_voronoi(D::Delaunay, game_points::Vector{GamePoint}, field_size::Float64)::VoronoiDiagram
    regions = VoronoiRegion[]
    voronoi_vertices = Dict{Dreieck, Punkt}()
    
    # Precompute circumcenters
    for triangle in D.triangles
        center = circumcenter(triangle)
        center !== nothing && (voronoi_vertices[triangle] = center)
    end

    # Create a map from points to their player
    point_to_player = Dict{Punkt, Int}()
    for p in game_points
        point_to_player[Punkt(p.x, p.y)] = p.player
    end
    
    # Map points to their adjacent triangles
    point_tri_map = Dict{Punkt, Vector{Dreieck}}()
    for p in keys(point_to_player)
        point_tri_map[p] = Dreieck[]
    end
    
    for triangle in D.triangles
        a, b, c = triangle.edge.origin, triangle.edge.next.origin, triangle.edge.next.next.origin
        for p in (a, b, c)
            if haskey(point_tri_map, p)
                push!(point_tri_map[p], triangle)
            end
        end
    end

    # Create regions
    for (p, player) in point_to_player
        triangles = get(point_tri_map, p, [])
        vertices = Punkt[]
        
        for tri in triangles
            center = get(voronoi_vertices, tri, nothing)
            center !== nothing && push!(vertices, center)
        end

        # Sort vertices around the point
        if !isempty(vertices)
            sort!(vertices, by=v -> atan(v.y - p.y, v.x - p.x))
            region = VoronoiRegion(p, vertices, player)
            push!(regions, region)
        end
    end
    
    return VoronoiDiagram(regions)
end

function polygon_area(vertices::Vector{Punkt})::Float64
    n = length(vertices)
    n < 3 && return 0.0
    area = 0.0
    for i in 1:n
        j = i % n + 1
        area += vertices[i].x * vertices[j].y - vertices[j].x * vertices[i].y
    end
    return abs(area) / 2.0
end