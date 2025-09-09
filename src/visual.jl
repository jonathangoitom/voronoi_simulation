# visual.jl - GUI and visualization

using GtkObservables, Colors
using GtkObservables.Gtk4
using GtkObservables.Cairo

export GameState, main

mutable struct GameState
    points::Vector{GamePoint}
    current_player::Int
    field_size::Float64
    max_points_per_player::Int
    
    GameState() = new(GamePoint[], 1, 100.0, 10) 
end


"""
    draw_game_state(ctx, game::GameState, show_triangulation, show_voronoi)
Main drawing function.
"""
function draw_game_state(ctx, game, show_triangulation, show_voronoi)
    # Background and grid
    set_source_rgb(ctx, 1, 1, 1)
    paint(ctx)
    draw_grid(ctx)
    
    # Voronoi regions
    show_voronoi && !isempty(game.points) && draw_voronoi_regions(ctx, game)
    
    # Delaunay triangulation
    show_triangulation && length(game.points) >= 3 && draw_triangulation(ctx, game)
    
    # Game points
    draw_points(ctx, game)
    
    # UI elements
    draw_ui(ctx, game, show_triangulation)
end

"""
    draw_grid(ctx)

Draws coordinate grid.
"""
function draw_grid(ctx)
    set_source_rgba(ctx, 0.8, 0.8, 0.8, 0.8)
    set_line_width(ctx, 0.3)
    
    # Vertical lines
    for i in 1:9
        x = 5 + i * 10
        move_to(ctx, x, 5)
        line_to(ctx, x, 95)
        stroke(ctx)
    end
    
    # Horizontal lines
    for i in 1:9
        y = 5 + i * 10
        move_to(ctx, 5, y)
        line_to(ctx, 95, y)
        stroke(ctx)
    end
end

"""
    draw_triangulation(ctx, game::GameState)

Draws Delaunay triangulation with circumcircles.
"""
function draw_triangulation(ctx, game::GameState)
    try
        D = create_delaunay_from_gamestate(game)
        
        triangle_count = 0
        rect = (0.0, 0.0, game.field_size, game.field_size)
        
        for triangle in D.triangles
            a = triangle.edge.origin
            b = triangle.edge.next.origin
            c = triangle.edge.next.next.origin
            
            if is_triangle_visible(a, b, c, game.field_size)
                # Draw triangle with clipped edges
                set_source_rgba(ctx, 0, 0.7, 0, 0.8)
                set_line_width(ctx, 0.8)
                
                # Clip and draw each edge
                draw_clipped_edge(ctx, a, b, rect, game.field_size)
                draw_clipped_edge(ctx, b, c, rect, game.field_size)
                draw_clipped_edge(ctx, c, a, rect, game.field_size)
                
                triangle_count += 1
            end
        end
        
        # Status (unchanged)
        set_source_rgb(ctx, 0, 0.5, 0)
        set_font_size(ctx, 1.5)
        move_to(ctx, 5, 98)
        show_text(ctx, "🔺 $triangle_count triangles")
        
    catch e
        set_source_rgb(ctx, 1, 0, 0)
        set_font_size(ctx, 1.5)
        move_to(ctx, 5, 98)
        show_text(ctx, "❌ Triangulation Error")
    end
end

"""
    draw_clipped_edge(ctx, p1::Punkt, p2::Punkt, rect::Tuple, field_size::Float64)
Draws an edge clipped to the game area rectangle.
"""
function draw_clipped_edge(ctx, p1::Punkt, p2::Punkt, rect::Tuple, field_size::Float64)
    xmin, ymin, xmax, ymax = rect
    
    # Check if both points are outside the same edge
    if (p1.x < xmin && p2.x < xmin) || (p1.x > xmax && p2.x > xmax) ||
       (p1.y < ymin && p2.y < ymin) || (p1.y > ymax && p2.y > ymax)
        return  # Skip drawing
    end
    
    # Clip edge to rectangle
    clipped = clip_segment_to_rect(p1, p2, rect)
    if clipped !== nothing
        q1, q2 = clipped
        (x1, y1) = convert_coords(q1, field_size)
        (x2, y2) = convert_coords(q2, field_size)
        
        move_to(ctx, x1, y1)
        line_to(ctx, x2, y2)
        stroke(ctx)
    end
end

"""
    clip_segment_to_rect(p1::Punkt, p2::Punkt, rect::Tuple) -> Union{Tuple{Punkt,Punkt}, Nothing}
Clips a line segment to a rectangle using Liang-Barsky algorithm.
"""
function clip_segment_to_rect(p1::Punkt, p2::Punkt, rect::Tuple)
    xmin, ymin, xmax, ymax = rect
    dx = p2.x - p1.x
    dy = p2.y - p1.y
    
    # Calculate intersection parameters
    t0 = 0.0
    t1 = 1.0
    
    # Left/Right edges
    if dx != 0
        t_left = (xmin - p1.x)/dx
        t_right = (xmax - p1.x)/dx
        t0 = max(t0, min(t_left, t_right))
        t1 = min(t1, max(t_left, t_right))
    elseif p1.x < xmin || p1.x > xmax
        return nothing  # Vertical line outside
    end
    
    # Top/Bottom edges - FIX: Changed order to properly handle bottom edge
    if dy != 0
        t_bottom = (ymin - p1.y)/dy  # This is the critical fix
        t_top = (ymax - p1.y)/dy
        t0 = max(t0, min(t_bottom, t_top))
        t1 = min(t1, max(t_bottom, t_top))
    elseif p1.y < ymin || p1.y > ymax
        return nothing  # Horizontal line outside
    end
    
    if t0 <= t1
        q1 = Punkt(p1.x + t0*dx, p1.y + t0*dy)
        q2 = Punkt(p1.x + t1*dx, p1.y + t1*dy)
        return (q1, q2)
    end
    return nothing
end

"""
    draw_circumcircle(ctx, triangle::Dreieck, field_size::Float64)

Draws circumcircle for a triangle.
"""
function draw_circumcircle(ctx, triangle::Dreieck, field_size::Float64)
    circumcenter_point = circumcenter(triangle)
    
    if circumcenter_point !== nothing
        a = triangle.edge.origin
        radius_game = sqrt((circumcenter_point.x - a.x)^2 + (circumcenter_point.y - a.y)^2)
        
        if radius_game < field_size * 5  # Reasonable radius
            (center_x, center_y) = convert_coords(circumcenter_point, field_size)
            radius_canvas = (radius_game / field_size) * 90
            
            # Check if circle is visible
            if center_x + radius_canvas >= 0 && center_x - radius_canvas <= 100 &&
               center_y + radius_canvas >= 0 && center_y - radius_canvas <= 100
                
                set_source_rgba(ctx, 1, 0, 0, 0.3)
                set_line_width(ctx, 0.5)
                arc(ctx, center_x, center_y, radius_canvas, 0, 2π)
                stroke(ctx)
            end
        end
    end
end

"""
    draw_points(ctx, game::GameState)

Draws game points with labels.
"""
function draw_points(ctx, game::GameState)
    for (i, point) in enumerate(game.points)
        canvas_x = 5 + (point.x / game.field_size) * 90
        canvas_y = 5 + (point.y / game.field_size) * 90
        
        # Point color
        if point.player == 1
            set_source_rgb(ctx, 1, 0, 0)  # Red
        else
            set_source_rgb(ctx, 0, 0, 1)  # Blue
        end
        
        # Draw point
        arc(ctx, canvas_x, canvas_y, 2.0, 0, 2π)
        fill(ctx)
        
        # Point number
        set_source_rgb(ctx, 1, 1, 1)
        select_font_face(ctx, "Sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_BOLD)
        set_font_size(ctx, 1.5)
        move_to(ctx, canvas_x - 0.5, canvas_y + 0.5)
        show_text(ctx, string(i))
    end
end

"""
    draw_ui(ctx, game::GameState, show_triangulation::Bool)

Draws UI elements.
"""
function draw_ui(ctx, game::GameState, show_triangulation::Bool)
    set_source_rgb(ctx, 0, 0, 0)
    set_font_size(ctx, 1.8)
    
    # Current player
    move_to(ctx, 5, 2)
    show_text(ctx, "Aktueller Spieler: $(game.current_player)")
    
    # Legend
    move_to(ctx, 40, 2)
    show_text(ctx, "Spieler Rot: Rot, Spieler Blau: Blau")
    
    # Point counts
    player1_count = count(p -> p.player == 1, game.points)
    player2_count = count(p -> p.player == 2, game.points)
    
    move_to(ctx, 70, 98)
    show_text(ctx, "Spieler Rot: $player1_count/$(game.max_points_per_player)")
    move_to(ctx, 70, 100)
    show_text(ctx, "Spieler Blau: $player2_count/$(game.max_points_per_player)")

    # Calculate and display player area percentages
    player_percentages = calculate_player_areas(game)
    p1_perc = round(player_percentages[1], digits=1)
    p2_perc = round(player_percentages[2], digits=1)
    
    # Move down a bit to avoid overlapping with existing text
    move_to(ctx, 85, 98)
    show_text(ctx, "Rot: $p1_perc%")
    move_to(ctx, 85, 100)
    show_text(ctx, "Blau: $p2_perc%")
end

"""
    convert_coords(p::Punkt, field_size::Float64) -> Tuple{Float64, Float64}

Converts game coordinates to canvas coordinates.
"""
function convert_coords(p::Punkt, field_size::Float64)
    return (5 + 90p.x/field_size, 5 + 90p.y/field_size)
end

"""
    is_triangle_visible(a::Punkt, b::Punkt, c::Punkt, field_size::Float64) -> Bool

Checks if triangle should be drawn.
"""
function is_triangle_visible(a::Punkt, b::Punkt, c::Punkt, field_size::Float64)
    # Show triangles that have at least one game point
    for p in [a, b, c]
        if p.x >= 0 && p.x <= field_size && p.y >= 0 && p.y <= field_size
            return true
        end
    end
    return false
end

"""
    create_delaunay_from_gamestate(game::GameState) -> Delaunay

Creates Delaunay triangulation from game state.
"""
function create_delaunay_from_gamestate(game::GameState)
    # Large bounding triangle
    margin = game.field_size * 3.0
    p1 = Punkt(-margin, -margin)
    p2 = Punkt(game.field_size + margin, -margin)
    p3 = Punkt(game.field_size/2, game.field_size + margin)
    
    D = init_delaunay(p1, p2, p3)
    
    # Insert game points
    for game_point in game.points
        p = Punkt(game_point.x, game_point.y)
        try
            insert_point!(p, D)
        catch e
            @warn "Point insertion error: $e"
        end
    end
    
    return D
end

"""
    place_point!(game::GameState, x::Float64, y::Float64) -> Bool

Adds a point to the game if valid.
"""
function place_point!(game::GameState, x::Float64, y::Float64)
    # Check player limit
    player_points = count(p -> p.player == game.current_player, game.points)
    if player_points >= game.max_points_per_player
        return false
    end
    
    # Check minimum distance
    min_distance = 2.0
    for existing_point in game.points
        distance = sqrt((x - existing_point.x)^2 + (y - existing_point.y)^2)
        if distance < min_distance
            return false
        end
    end
    
    # Add point
    new_point = GamePoint(x, y, game.current_player)
    push!(game.points, new_point)
    
    # Switch player
    game.current_player = 3 - game.current_player
    
    return true
end

"""
    draw_voronoi_regions(ctx, game::GameState)
Draws clipped Voronoi regions.
"""
function draw_voronoi_regions(ctx, game::GameState)
    voronoi = calculate_voronoi_delaunay(game.points)
    # Player-specific colors with transparency
    colors = Dict(
        1 => (1, 0.5, 0.5, 0.5),  # Red with transparency
        2 => (0.5, 0.5, 1, 0.5)   # Blue with transparency
    )
    
    # Draw filled regions first
    for region in voronoi.regions
        clipped = clip_polygon_to_rect(region.vertices, (0.0, 0.0, game.field_size, game.field_size))
        length(clipped) < 3 && continue
        
        # Set player-specific color
        color = colors[region.player]
        set_source_rgba(ctx, color...)
        
        # Draw polygon
        (x, y) = convert_coords(clipped[end], game.field_size)
        move_to(ctx, x, y)
        for v in clipped
            (x, y) = convert_coords(v, game.field_size)
            line_to(ctx, x, y)
        end
        close_path(ctx)
        fill(ctx)
    end
    
    # Draw black boundaries on top
    set_source_rgb(ctx, 0, 0, 0)
    set_line_width(ctx, 0.8)
    for region in voronoi.regions
        # Use the same clipping as for filled regions
        clipped = clip_polygon_to_rect(region.vertices, (0.0, 0.0, game.field_size, game.field_size))
        length(clipped) < 3 && continue
        
        (x, y) = convert_coords(clipped[end], game.field_size)
        move_to(ctx, x, y)
        for v in clipped
            (x, y) = convert_coords(v, game.field_size)
            line_to(ctx, x, y)
        end
        close_path(ctx)
        stroke(ctx)
    end
end

"""
    main()

Main GUI function.
"""
function main()
    game = Observable(GameState())
    show_triangulation = Observable(false)
    show_voronoi = Observable(true)
    
    # Window setup
    win = GtkWindow("Voronoi-Spiel", 900, 700)
    vbox = GtkBox(:v)
    win[] = vbox
    
    # Add point limit control with dropdown
    control_box = GtkBox(:h)
    points_label = GtkLabel("Punkte pro Spieler:")
    points_dropdown = GtkDropDown(["5", "10", "20"])
    set_gtk_property!(points_dropdown, :selected, 1)  # Default to 10 (second option)
    
    push!(control_box, points_label)
    push!(control_box, points_dropdown)
    
    # Buttons
    button_box = GtkBox(:h)
    btn_reset = GtkButton("Spiel zurücksetzen")
    btn_undo = GtkButton("Letzten Punkt entfernen")
    btn_toggle_triangulation = GtkButton("🔺 TRIANGULATION AUSBLENDEN")
    btn_toggle_voronoi = GtkButton("VORONOI ANZEIGEN")
    
    push!(button_box, btn_reset)
    push!(button_box, btn_undo)
    push!(button_box, btn_toggle_triangulation)
    push!(button_box, btn_toggle_voronoi)

    # Canvas
    c = canvas(UserUnit)
    frame = GtkFrame(c)
    
    push!(vbox, control_box)
    push!(vbox, button_box)
    push!(vbox, frame)
    
    # Dropdown change handler
    signal_connect(points_dropdown, "notify::selected-item") do widget, others...
        selected = get_gtk_property(points_dropdown, :selected, Int)
        max_points = [5, 10, 20][selected + 1]  # +1 because Julia is 1-based
        new_game = deepcopy(game[])
        new_game.max_points_per_player = max_points
        game[] = new_game
    end
    
    # Reset button handler
    signal_connect(btn_reset, "clicked") do widget
        selected = get_gtk_property(points_dropdown, :selected, Int)
        max_points = [5, 10, 20][selected + 1]
        game[] = GameState()
        game[].max_points_per_player = max_points
    end
    
    # Keep all other signal connections the same
    signal_connect(btn_undo, "clicked") do widget
        if !isempty(game[].points)
            new_game = deepcopy(game[])
            pop!(new_game.points)
            new_game.current_player = 3 - new_game.current_player
            game[] = new_game
        end
    end
    
    signal_connect(btn_toggle_triangulation, "clicked") do widget
        show_triangulation[] = !show_triangulation[]
        btn_toggle_triangulation.label = show_triangulation[] ? 
            "🔺 TRIANGULATION AUSBLENDEN" : "🔺 TRIANGULATION ANZEIGEN"
    end

    signal_connect(btn_toggle_voronoi, "clicked") do widget
        show_voronoi[] = !show_voronoi[]
        btn_toggle_voronoi.label = show_voronoi[] ? "VORONOI AUSBLENDEN" : "VORONOI ANZEIGEN"
    end
    
    # Mouse click handling (unchanged)
    on(c.mouse.buttonpress) do btn
        if btn.button == 1 && btn.modifiers == 0
            canvas_x = Float64(btn.position.x)
            canvas_y = Float64(btn.position.y)
            
            if 5 <= canvas_x <= 95 && 5 <= canvas_y <= 95
                game_x = ((canvas_x - 5) / 90) * game[].field_size
                game_y = ((canvas_y - 5) / 90) * game[].field_size
                
                new_game = deepcopy(game[])
                if place_point!(new_game, game_x, game_y)
                    game[] = new_game
                end
            end
        end
    end
    
    # Drawing (unchanged)
    redraw = draw(c, game, show_triangulation, show_voronoi) do cnvs, game_state, show_tri, show_vor
        set_coordinates(cnvs, BoundingBox(0, 100, 0, 100))
        ctx = getgc(cnvs)
        draw_game_state(ctx, game_state, show_tri, show_vor)
    end
    
    show(win)
    return (canvas=c, game=game, window=win)
end

"""
    calculate_player_areas(game::GameState) -> Dict{Int, Float64}

Calculate the Voronoi area controlled by each player within the game field.
"""
function calculate_player_areas(game::GameState)
    if isempty(game.points)
        return Dict(1 => 50.0, 2 => 50.0)
    end
    
    voronoi = calculate_voronoi_delaunay(game.points)
    field_area = game.field_size * game.field_size
    player_areas = Dict(1 => 0.0, 2 => 0.0)
    
    for region in voronoi.regions
        clipped = clip_polygon_to_rect(region.vertices, (0.0, 0.0, game.field_size, game.field_size))
        length(clipped) < 3 && continue
        
        # Calculate area using shoelace formula
        area = polygon_area(clipped)
        player_areas[region.player] += area
    end
    
    # Normalize and convert to percentages
    total_area = sum(values(player_areas))
    player_percentages = Dict{Int, Float64}()
    
    if total_area > 0
        for (player, area) in player_areas
            player_percentages[player] = (area / total_area) * 100
        end
    else
        player_percentages = Dict(1 => 50.0, 2 => 50.0)
    end
    
    return player_percentages
end

# Add this new clipping function
function clip_polygon_to_rect(poly::Vector{Punkt}, rect::Tuple{Float64,Float64,Float64,Float64})
    # rect: (xmin, ymin, xmax, ymax)
    # Clip against each edge: left, right, bottom, top
    edges = [
        (:left, rect[1]), 
        (:right, rect[3]), 
        (:bottom, rect[2]), 
        (:top, rect[4])
    ]
    
    output = poly
    for (edge_type, edge_val) in edges
        input = output
        output = Punkt[]
        isempty(input) && continue
        
        s = input[end]
        for p in input
            if edge_type == :left
                if p.x >= edge_val
                    if s.x < edge_val
                        push!(output, Punkt(edge_val, s.y + (p.y - s.y) * (edge_val - s.x) / (p.x - s.x)))
                    end
                    push!(output, p)
                elseif s.x >= edge_val
                    push!(output, Punkt(edge_val, s.y + (p.y - s.y) * (edge_val - s.x) / (p.x - s.x)))
                end
            elseif edge_type == :right
                if p.x <= edge_val
                    if s.x > edge_val
                        push!(output, Punkt(edge_val, s.y + (p.y - s.y) * (edge_val - s.x) / (p.x - s.x)))
                    end
                    push!(output, p)
                elseif s.x <= edge_val
                    push!(output, Punkt(edge_val, s.y + (p.y - s.y) * (edge_val - s.x) / (p.x - s.x)))
                end
            elseif edge_type == :bottom
                if p.y >= edge_val
                    if s.y < edge_val
                        push!(output, Punkt(s.x + (p.x - s.x) * (edge_val - s.y) / (p.y - s.y), edge_val))
                    end
                    push!(output, p)
                elseif s.y >= edge_val
                    push!(output, Punkt(s.x + (p.x - s.x) * (edge_val - s.y) / (p.y - s.y), edge_val))
                end
            elseif edge_type == :top
                if p.y <= edge_val
                    if s.y > edge_val
                        push!(output, Punkt(s.x + (p.x - s.x) * (edge_val - s.y) / (p.y - s.y), edge_val))
                    end
                    push!(output, p)
                elseif s.y <= edge_val
                    push!(output, Punkt(s.x + (p.x - s.x) * (edge_val - s.y) / (p.y - s.y), edge_val))
                end
            end
            s = p
        end
    end
    return output
end