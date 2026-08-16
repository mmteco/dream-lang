enum Color:
    Red
    Green
    Blue

let color = Color.Green
let result = match color:
    Color.Red: 1
    Color.Green: 2
    Color.Blue: 0
print(result)
