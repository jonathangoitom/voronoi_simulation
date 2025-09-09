# tests.jl - Complete test system

using Test

export run_tests

"""
    run_tests()
    
Runs all tests for the VoronoiGame module.
"""
function run_tests()
    println("Running VoronoiGame Tests...")
    
    @testset "VoronoiGame Complete Test Suite" begin
        
        @testset "Basic Data Structure Tests" begin
            # Test Punkt creation
            p1 = Punkt(1.0, 2.0)
            p2 = Punkt(3.0, 4.0)
            @test p1.x == 1.0
            @test p1.y == 2.0
            @test !isapprox(p1, p2)
            @test isapprox(p1, Punkt(1.0, 2.0))
            
            # Test GamePoint
            gp = GamePoint(5.0, 6.0, 1)
            @test gp.x == 5.0
            @test gp.y == 6.0
            @test gp.player == 1
        end
        
        @testset "Triangle Orientation Tests" begin
            # Counter-clockwise
            a = Punkt(0.0, 0.0)
            b = Punkt(1.0, 0.0)
            c = Punkt(0.5, 1.0)
            @test triangle_orientation(a, b, c) > 0
            
            # Clockwise
            @test triangle_orientation(a, c, b) < 0
            
            # Collinear
            d = Punkt(2.0, 0.0)
            @test abs(triangle_orientation(a, b, d)) < 1e-10
        end
        
        @testset "Delaunay Initialization Tests" begin
            # Create simple triangle
            a = Punkt(0.0, 0.0)
            b = Punkt(2.0, 0.0)
            c = Punkt(1.0, 2.0)
            
            D = init_delaunay(a, b, c)
            @test length(D.triangles) == 1
            @test D.bounding_triangle !== nothing
            
            # Check triangle structure
            tri = first(D.triangles)
            @test tri.edge !== nothing
            @test tri.edge.next !== nothing
            @test tri.edge.next.next !== nothing
            @test tri.edge.next.next.next === tri.edge  # Should loop back
        end
        
        @testset "Triangle Creation Tests" begin
            a = Punkt(0.0, 0.0)
            b = Punkt(1.0, 0.0)
            c = Punkt(0.5, 1.0)
            
            tri = create_triangle(a, b, c)
            
            # Check all edges exist and are properly linked
            @test tri.edge !== nothing
            @test tri.edge.next !== nothing
            @test tri.edge.prev !== nothing
            @test tri.edge.face === tri
            
            # Check circular linking
            @test tri.edge.next.next.next === tri.edge
            @test tri.edge.prev.prev.prev === tri.edge
        end
        
        @testset "Point Location Tests" begin
            # Simple triangle containing origin
            a = Punkt(-1.0, -1.0)
            b = Punkt(2.0, -1.0)
            c = Punkt(0.5, 2.0)
            
            D = init_delaunay(a, b, c)
            
            # Point inside triangle
            p_inside = Punkt(0.5, 0.5)
            found_tri = find_triangle(p_inside, D)
            @test found_tri !== nothing
            
            # Point outside
            p_outside = Punkt(10.0, 10.0)
            found_tri_outside = find_triangle(p_outside, D)
            @test found_tri_outside === nothing
        end
        
        @testset "Point Insertion Tests" begin
            # Start with bounding triangle
            margin = 300.0
            p1 = Punkt(-margin, -margin)
            p2 = Punkt(400.0, -margin)
            p3 = Punkt(50.0, 400.0)
            
            D = init_delaunay(p1, p2, p3)
            initial_count = length(D.triangles)
            
            # Insert a point
            new_point = Punkt(50.0, 50.0)
            insert_point!(new_point, D)
            
            # Should have more triangles now
            @test length(D.triangles) > initial_count
            
            # Insert another point
            second_point = Punkt(25.0, 75.0)
            insert_point!(second_point, D)
            @test length(D.triangles) >= 4  # At least some triangles
        end
        
        @testset "Circumcircle Tests" begin
            # Create a simple triangle
            a = Punkt(0.0, 0.0)
            b = Punkt(2.0, 0.0)
            c = Punkt(1.0, 2.0)
            
            tri = create_triangle(a, b, c)
            center = circumcenter(tri)
            
            @test center !== nothing
            
            # All triangle vertices should be equidistant from circumcenter
            if center !== nothing
                dist_a = sqrt((center.x - a.x)^2 + (center.y - a.y)^2)
                dist_b = sqrt((center.x - b.x)^2 + (center.y - b.y)^2)
                dist_c = sqrt((center.x - c.x)^2 + (center.y - c.y)^2)
                
                @test isapprox(dist_a, dist_b, atol=1e-10)
                @test isapprox(dist_b, dist_c, atol=1e-10)
            end
        end
        
        @testset "Voronoi Diagram Tests" begin
            # Test with simple points
            game_points = [
                GamePoint(25.0, 25.0, 1),
                GamePoint(75.0, 25.0, 2),
                GamePoint(25.0, 75.0, 1),
                GamePoint(75.0, 75.0, 2)
            ]
            
            voronoi = calculate_voronoi_delaunay(game_points)
            @test length(voronoi.regions) == 4
            
            # Each region should have the correct player
            for region in voronoi.regions
                matching_point = nothing
                for gp in game_points
                    if isapprox(region.center, Punkt(gp.x, gp.y))
                        matching_point = gp
                        break
                    end
                end
                @test matching_point !== nothing
                @test region.player == matching_point.player
            end
        end
        
        @testset "Polygon Area Tests" begin
            # Simple square
            square = [
                Punkt(0.0, 0.0),
                Punkt(2.0, 0.0),
                Punkt(2.0, 2.0),
                Punkt(0.0, 2.0)
            ]
            @test isapprox(polygon_area(square), 4.0, atol=1e-10)
            
            # Triangle
            triangle = [
                Punkt(0.0, 0.0),
                Punkt(2.0, 0.0),
                Punkt(1.0, 2.0)
            ]
            @test isapprox(polygon_area(triangle), 2.0, atol=1e-10)
        end
        
        @testset "Game State Tests" begin
            game = GameState()
            @test game.current_player == 1
            @test length(game.points) == 0
            
            # Place a point
            success = place_point!(game, 50.0, 50.0)
            @test success
            @test length(game.points) == 1
            @test game.current_player == 2  # Should switch
            
            # Try to place too close
            success2 = place_point!(game, 50.5, 50.5)  # Too close
            @test !success2  # Should fail
            @test length(game.points) == 1  # No new point
        end
        
        @testset "Area Calculation Tests" begin
            game = GameState()
            
            # Empty game should have 50/50 split
            areas = calculate_player_areas(game)
            @test areas[1] == 50.0
            @test areas[2] == 50.0
            
            # Add some points
            place_point!(game, 25.0, 50.0)  # Player 1
            place_point!(game, 75.0, 50.0)  # Player 2
            
            areas2 = calculate_player_areas(game)
            @test areas2[1] + areas2[2] ≈ 100.0
        end
    end
    
    println("✅ All tests completed!")
end