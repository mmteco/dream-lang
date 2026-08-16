enum Message:
    Text(str)
    Code(int)
    Empty

let message = Message.Code(42)
let result = match message:
    Message.Code(code): code
    Message.Text(_): 1
    Message.Empty: 0
print(result)

enum Measurement:
    Value(float)
    Empty

let measurement = Measurement.Value(2.5)
let measurement_result = match measurement:
    Measurement.Value(value): value
    Measurement.Empty: 0.0
print(measurement_result)

let text_message = Message.Text("ok")
let text_result = match text_message:
    Message.Text(value): len(value)
    Message.Code(_): -1
    Message.Empty: -1
print(text_result)

enum Switch:
    On(bool)
    Off

let switch_value = Switch.On(true)
let switch_result = match switch_value:
    Switch.On(value): if value: 1 else: 0
    Switch.Off: -1
print(switch_result)
