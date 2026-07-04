// tak — Takeuchi function: tak(x,y,z) = x>y ? tak(tak(x-1,y,z),
// tak(y-1,z,x), tak(z-1,x,y)) : z, evaluated at tak(32,16,8). Faithful
// port of reference/cases/tak (oracle 9). Three recursive calls chained
// as binds, all three feeding the final recursive call.
import std/io

pub event tak { x: i64, y: i64, z: i64 } -> i64

tak = if(x > y)
| then |> tak(x: x - 1, y, z): t1 |> tak(x: y - 1, y: z, z: x): t2 |> tak(x: z - 1, y: x, z: y): t3 |> tak(x: t1, y: t2, z: t3): v -> v
| else -> z

tak(x: 32, y: 16, z: 8): r |> std/io:print.ln("{{ r:d }}")
