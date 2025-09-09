# debug.jl - Debugging utilities

export debug_println, validate_delaunay, print_triangulation

# Set to false to disable
const DEBUG = false

function debug_println(args...)
    if DEBUG
        println(args...)
    end
end

function validate_delaunay(D::Delaunay)
    return
    debug_println("\nValidating Delaunay triangulation...")
    valid = true
    
    # Check triangle connectivity
    for tri in D.triangles
        edges = [tri.edge, tri.edge.next, tri.edge.next.next]
        for (i, e) in enumerate(edges)
            next_e = edges[i % 3 + 1]
            prev_e = edges[(i + 1) % 3 + 1]
            
            if e.next !== next_e
                debug_println("ERROR: Edge $(e.origin)->$(e.next.origin) next should be $(next_e.origin)->$(next_e.next.origin)")
                valid = false
            end
            if e.prev !== prev_e
                debug_println("ERROR: Edge $(e.origin)->$(e.next.origin) prev should be $(prev_e.origin)->$(prev_e.next.origin)")
                valid = false
            end
            if e.face !== tri
                debug_println("ERROR: Edge $(e.origin)->$(e.next.origin) face mismatch")
                valid = false
            end
        end
    end
    
    # Check twin pointers
    edge_count = 0
    twin_mismatch = 0
    for tri in D.triangles
        for e in (tri.edge, tri.edge.next, tri.edge.next.next)
            edge_count += 1
            if e.twin !== nothing
                if e.twin.twin !== e
                    debug_println("ERROR: Twin pointer not symmetric for edge ($(e.origin), $(e.next.origin))")
                    valid = false
                    twin_mismatch += 1
                end
            end
        end
    end
    
    if valid
        debug_println("Validation passed: $edge_count edges, $(length(D.triangles)) triangles")
    else
        debug_println("Validation FAILED: $twin_mismatch twin mismatches")
    end
    return valid
end

function print_triangulation(D::Delaunay)
    debug_println("\nCurrent triangulation ($(length(D.triangles)) triangles):")
    for tri in D.triangles
        a = tri.edge.origin
        b = tri.edge.next.origin
        c = tri.edge.next.next.origin
        debug_println("  Triangle: $a, $b, $c")
        for edge in (tri.edge, tri.edge.next, tri.edge.next.next)
            twin_info = edge.twin === nothing ? "none" : 
                "($(edge.twin.origin)->$(edge.twin.next.origin))"
            debug_println("    Edge: $(edge.origin)->$(edge.next.origin) | twin: $twin_info")
        end
    end
end