///|
test "model chip leaves a cell on each side of the name" {
  inspect(@core.model_label("gpt-example"), content=" gpt-example ")
}
