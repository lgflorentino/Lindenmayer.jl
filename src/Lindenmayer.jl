"""
An LSystem, or Lindenmayer system, is a set of rules that
can define recursive patterns.

You can define an L-System like this:

```
koch = LSystem(["F" => "F+F--F+F"], "F")
```

and use Luxor to draw it like this:

```
drawLSystem(koch, forward=30, turn=45, iterations=6)
```

See `help?> LSystem` and `help?> ?>LSystem` for more.
"""
module Lindenmayer

export drawLSystem, LSystem

using Luxor
using OrderedCollections
using Colors

"""
A Lindenmayer system is a set of rules that can build
recursive patterns. In Lindenmayer.jl, an LSystem structure consists
of:

- Rules: a set of search and replace strings

- Seed: a string that defines the initial state for the system

- State: the current state (initially empty, added when the system is evaluated)

You can define an L-System like this:

```
using Lindenmayer
koch = LSystem(["F" => "F+F--F+F"], "F")
```

This says: there's just one rule; search for "F" and replace with "F+F--F+F" for
each iteration. The starting "seed" is the initial state
consisting of just a single "F".

# Extended help

To draw the LSystem we use Luxor.jl's Turtle, which
interprets the characters in the rule as instructions or
commands. For example, "F" converts to `Luxor.Forward()``, "+"
rotates clockwise, "-" rotates counterclockwise, and so on.

```
drawLSystem(LSystem(["F" => "5F+F--F+Ftt"], "F"),
    startingx = -400,
    forward = 4,
    turn = 80,
    iterations = 6)
```

Keyword options for `drawLSystem` include:

```
forward=15,
turn=45,
iterations=6,
filename="/tmp/lsystem.pdf",
width=1000,
height=1000,
startingpen=(0.3, 0.6, 0.8), # starting color RGB
startingx=0,
startingy=0,
startingorientation=0,
showpreview=true
```

The following characters are recognized in LSystem rules.

F - step Forward

G - same as F

B - step backwards

V - same as B

f - half a step forward

b - turn 180° and take half a step forward

U - lift the pen (stop drawing)

D - pen down (start drawing)

`+` - turn by angle

`-` - turn backwards by angle

r - turn randomly by 10° 15° 30° 45° or 60°

T - change the hue at random

t - shift the hue by 5°

c - randomize the saturation

O - choose a random opacity value

l - increase the step size by 1

s - decrease the step size by 1

5 - set line width to 5

4 - set line width to 4

3 - set line width to 3

2 - set line width to 2

1 - set line width to 1

n - set line width to 0.5

o - draw a circle with radius step/4

q - draw a square with side length step/4

`@` - turn 5°

`&` - turn -5°

[ - push the current state on the stack

] - pop the current state off the stack

`*` - execute the arbitrary function passed as `asteriskfunction()`
```


"""
mutable struct LSystem
    rules::OrderedDict{String,String}
    state::Array{UInt16,1}
    initial_state::Array{UInt16,1}
end

function LSystem(rules::Dict, state_as_string)
    return LSystem(rules,
        string_to_array(state_as_string),
        string_to_array(state_as_string))
end

LSystem(rules::Tuple, state_as_string) =
    begin
        LSystem(OrderedDict(rules),
        string_to_array(state_as_string),
        string_to_array(state_as_string))
    end

# for compatibility with older versions
LSystem(rules::Vector{Pair{String,String}}, state_as_string) =
    begin
        LSystem(OrderedDict(rules),
            string_to_array(state_as_string),
            string_to_array(state_as_string))
    end

    function string_to_array(str::String)
    return [Int(Char(x)) for x in collect(str)]
end

function array_to_string(arr::Array{UInt16,1})
    return join(string.(Char.(collect(arr))))
end

"""
    evaluate(ls::LSystem, iterations=1)

Apply the rules in the LSystem to the initial state repeatedly. The ls.state array holds
the result.
"""
function evaluate(ls::LSystem, iterations=1)
    next_state = Array{UInt16, 1}()
    for i in 1:iterations
        @debug "iteration $i"
        for j in 1:length(ls.state) # each character in state
            s = string(Char(ls.state[j]))
            if haskey(ls.rules, s)
                #  replace it using the rule
                value = ls.rules[s]
                if ! isempty(value)
                    varr = string_to_array(value)
                    push!(next_state, varr...)
                end
            else # keep it in
                push!(next_state, ls.state[j])
            end
        end
        @debug array_to_string(ls.state)
        ls.state = next_state
        next_state = Array{UInt16, 1}()
    end
end

"""
    render(ls::LSystem, t::Turtle, stepdistance, rotangle;
        asteriskfunction=(t) -> ())

Once the LSystem has been evaluated, the state (in `LSystem.state`) can
be drawn.

- `ls` is the LSystem to be rendered

- `t` is a Luxor turtle

- `stepdistance` is the Forward distance

- `rotangle` is the Turn angle
"""
function render(ls::LSystem, t::Turtle, stepdistance, rotangle;
        asteriskfunction=(t) -> ())
    counter = 1
    # set the color before we start
    Pencolor(t, t.pencolor...)
    for a in ls.state
        command = string(Char(a))
        if command =="F"
            Forward(t, stepdistance)
        elseif command =="G"
            Forward(t, stepdistance)
        elseif command =="B"
            Turn(t, 180)
            Forward(t, stepdistance)
            Turn(t, 180)
        elseif command =="V"
            Turn(t, 180)
            Forward(t, stepdistance)
            Turn(t, 180)
        elseif command =="f"
            Forward(t, stepdistance/2)
        elseif command =="b"
            Turn(t, 180)
            Forward(t, stepdistance/2)
        elseif command =="U"
            Penup(t)
        elseif command =="D"
            Pendown(t)
        elseif command =="+"
            Turn(t, rotangle)
        elseif command =="-"
            Turn(t, -rotangle)
        elseif command =="r"
            rotangle = [10, 15, 30, 45, 60][rand(1:end)]
        elseif command =="T"
            randomhue()
        elseif command =="t"
            HueShift(t, 5) # shift hue round the Hue scale (0-360)
        elseif command =="c"
            Randomize_saturation(t) # shift saturation
        elseif command =="O"
            Pen_opacity_random(t)
        elseif command =="l"
            stepdistance = stepdistance + 1 # larger
        elseif command =="s"
            stepdistance = stepdistance - 1 # smaller
        elseif command =="9"
            Penwidth(t, 9)
        elseif command =="8"
            Penwidth(t, 8)
        elseif command =="7"
            Penwidth(t, 7)
        elseif command =="6"
            Penwidth(t, 6)
        elseif command =="5"
            Penwidth(t, 5)
        elseif command =="4"
            Penwidth(t, 4)
        elseif command =="3"
            Penwidth(t, 3)
        elseif command =="2"
            Penwidth(t, 2)
        elseif command =="1"
            Penwidth(t, 1)
        elseif command =="n"
            Penwidth(t, 0.5)
        elseif command =="@"
            Turn(t, 5)
        elseif command =="&"
            Turn(t, -5)
        elseif command =="o"
            Circle(t, stepdistance/4)
        elseif command =="q"
            Rectangle(t, stepdistance/4, stepdistance/4)
        elseif command =="["
            Push(t) # push
        elseif command =="]"
            Pop(t)   # pop
        elseif command == "*"
            asteriskfunction(t)
        end
        counter += 1
    end
    counter
end

"""
    drawLSystem(lsystem::LSystem ;
           # optional settings:
           forward=15,
           turn=45,
           iterations=10,
           filename="lsystem.png",
           width=800,
           height=800,
           startingpen=(0.3, 0.6, 0.8), # starting color RGB
           startingx=0,
           startingy=0,
           startingorientation=0,
           showpreview=true,
           backgroundcolor = colorant"black",
           asteriskfunction = (t::Luxor.Turtle) -> ())

Draw a Lindenmayer system. `lsystem` is the definition of a
L-System (rules followed by initial state).

For example:

```
newsystem = LSystem(Dict("F" => "AGCFCGAT", "G" => "CFAGAFC"), "F")
```

You can change or add rules like this:

```
newsystem.rules["F"] = "OFO"
```

You can vary the line width using Turtle commands "1" ... "9" to select the appropriate line width (in
points), or "n" to choose a narrow 0.5.

"""
function drawLSystem(lsystem::LSystem;
        forward=15,
        turn=45,
        iterations=6,
        filename="lsystem.png",
        width=800,
        height=800,
        startingpen=(0.3, 0.6, 0.8), # starting color RGB
        startingx=0,
        startingy=0,
        startingorientation=0, # -pi/2 means turtle points North on the page (although that's negative y...)
        showpreview=true,
        backgroundcolor = colorant"black",
        asteriskfunction = (t::Turtle) -> ()
        )

    # use the stored initial state, because the state will grow
    lsystem.state = lsystem.initial_state
    t = Turtle(0, 0, true, startingorientation, startingpen)
    if filename isa String 
        d = Drawing(width, height, "$filename")
    else
        d = Drawing(width, height, filename)
    end
    origin()
    background(backgroundcolor)
    setline(1)
    setlinecap("round")
    setopacity(0.9)
    fontsize(2)
    translate(startingx, startingy)
    @debug "starting to evaluate LSystem..."
    evaluate(lsystem, iterations)
    @debug "...evaluated LSystem, now starting to render to file $(filename)..."
    counter = render(lsystem, t, forward, turn, asteriskfunction = asteriskfunction)
    @debug "...executed $counter graphical instructions"
    finish()
    @debug "...saved in file $(filename)..."
    if showpreview
        return d
    else
        return (commands = counter, file = filename)
    end
end

end # module
