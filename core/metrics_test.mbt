///|
fn metrics_row(percent : Int32, window : Int32, usd : Double) -> String {
  row_text(
    @core.render_row(90, "model", "", "~/repo", [], percent, window, usd),
  )
}

///|
test "the rule labels known usage, but not an unknown or compacted window's fill" {
  let known = metrics_row(14, 272000, -1.0)
  assert_true(known.contains("─14%"))
  assert_true(known.has_suffix("272K─"))
  let unknown = metrics_row(-1, 272000, -1.0)
  assert_false(unknown.contains("%"))
  assert_true(unknown.has_suffix("272K─"))
  assert_true(metrics_row(0, 272000, -1.0).contains("─0%"))
  assert_false(metrics_row(-1, 0, -1.0).contains("0K"))
}

///|
test "estimated dollars precede the rule and unavailable estimates leave no cost" {
  assert_true(metrics_row(0, 272000, 1.04).contains("~$1.04"))
  assert_true(metrics_row(0, 272000, 0.0).contains("~$0.00"))
  assert_false(metrics_row(0, 272000, -1.0).contains("$"))
  assert_false(metrics_row(0, 272000, 1.04).contains("(+"))
}

///|
test "a full million-token window keeps both labels and the final rule cell" {
  let full = metrics_row(100, 1500000, -1.0)
  assert_true(full.has_suffix("100%─1.5M─"))
  assert_true(metrics_row(1, 1000000, -1.0).has_suffix("1M─"))
  assert_true(metrics_row(10, 8192, -1.0).has_suffix("8.2K─"))
}
