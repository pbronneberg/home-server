# Logic prototype

State the behavioral question visibly. Use one self-contained HTML file when
human exploration of a state model helps, or a small local CLI fixture when it
answers the question more directly. Keep logic separate from display; use pure
state transitions where suitable. Expose the state after each action.
Include reset, free exploration, and repeatable guided scenarios for the normal
case, awkward transition, and prohibited action. Use domain labels rather than
internal jargon. Keep dependencies and persistence out unless they are exactly
what the question tests. Record human reaction and the answer before handing
validated decisions to specification; the prototype is not production evidence.
