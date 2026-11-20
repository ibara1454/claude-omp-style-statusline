///|
fn row_text(row : FixedArray[String]) -> String {
  let text = StringBuilder()
  for i = 0; i < row.length(); i = i + 3 {
    text.write_string(row[i])
  }
  text.to_string()
}

///|
fn row_color(row : FixedArray[String], label : String) -> (String, String) {
  for i = 0; i < row.length(); i = i + 3 {
    if row[i].contains(label) {
      return (row[i + 1], row[i + 2])
    }
  }
  ("", "")
}

///|
test "wide row keeps the screenshot order and chip styling" {
  let row = @core.render_row(
    90,
    "Opus",
    "xhigh",
    "~/work/app",
    ["main", "*2", "+1", "?3"],
    14,
    272000,
    1.04,
  )
  assert_true(
    row_text(row).has_prefix(
      " ◕ xhigh > Opus > 📁 ~/work/app > ⑂ main *2 +1 ?3 > ~$1.04 ▶",
    ),
  )
  assert_eq(row_color(row, "Opus"), ("#af5fff", "#121212"))
  assert_eq(row_color(row, "~/work/app"), ("#eeeeee", "#121212"))
  assert_eq(row_color(row, "main"), ("#ffaf5f", "#121212"))
  assert_eq(row_color(row, "~$1.04"), ("#d7af87", "#121212"))
  assert_eq(row_color(row, ">"), ("#767676", "#121212"))
  assert_eq(row_color(row, "▶"), ("#767676", ""))
  assert_true(row_color(row, "*2").0 != row_color(row, "+1").0)
  assert_true(row_color(row, "?3").0 != row_color(row, "+1").0)
  assert_true(row_color(row, "?3").0 != row_color(row, "*2").0)
}

///|
test "wide paths keep at most forty cells from their final components" {
  let path = "/abcdefghijklmnopqrst日本語abcdefghijklmnopqrst"
  let row = row_text(@core.render_row(80, "", "", path, [], -1, 0, -1.0))
  assert_true(
    row.has_prefix(" 📁 …hijklmnopqrst日本語abcdefghijklmnopqrst ▶"),
  )
}

///|
test "shrinking hides cost, git, model, then effort, preserving the path last" {
  let at = fn(columns) {
    row_text(
      @core.render_row(
        columns,
        "M",
        "xhigh",
        "/abcdefghij",
        ["b", "", "", ""],
        -1,
        0,
        1.04,
      ),
    )
  }
  assert_eq(at(46), " ◕ xhigh > M > 📁 /abcdefghij > ⑂ b > ~$1.04 ▶")
  assert_eq(at(45), " ◕ xhigh > M > 📁 …bcdefghij > ⑂ b > ~$1.04 ▶")
  assert_eq(at(40), " ◕ xhigh > M > 📁 …ghij > ⑂ b > ~$1.04 ▶")
  assert_true(at(39).has_prefix(" ◕ xhigh > M > 📁 …ghij > ⑂ b ▶"))
  assert_eq(at(31), " ◕ xhigh > M > 📁 …ghij > ⑂ b ▶")
  assert_true(at(30).has_prefix(" ◕ xhigh > M > 📁 …ghij ▶"))
  assert_eq(at(25), " ◕ xhigh > M > 📁 …ghij ▶")
  assert_true(at(24).has_prefix(" ◕ xhigh > 📁 …ghij ▶"))
  assert_eq(at(21), " ◕ xhigh > 📁 …ghij ▶")
  assert_true(at(20).has_prefix(" 📁 …ghij ▶"))
  assert_eq(at(11), " 📁 …ghij ▶")
  assert_eq(at(10), "")
  assert_eq(at(0), "")
}

///|
test "the rule reserves eleven cells for both labels but not at the expense of the final chip" {
  let wide = row_text(
    @core.render_row(27, "M", "", "/abcde", [], 14, 272000, -1.0),
  )
  assert_true(wide.has_prefix(" M > 📁 /abcde ▶"))
  assert_true(wide.contains("14%"))
  assert_true(wide.contains("272K"))
  let narrow = row_text(
    @core.render_row(26, "M", "", "/abcde", [], 14, 272000, -1.0),
  )
  assert_true(narrow.has_prefix(" M > 📁 …bcde ▶"))
  assert_true(narrow.contains("14%"))
  assert_true(narrow.contains("272K"))
  let last = row_text(
    @core.render_row(22, "", "", "/abcde", [], 14, 272000, -1.0),
  )
  assert_true(last.has_prefix(" 📁 /abcde ▶"))
  assert_false(last.contains("%"))
  assert_false(last.contains("272K"))
}

///|
test "cell clipping never keeps half of a Japanese wide character" {
  let japanese = "/日本語aaaa"
  let narrow = @core.render_row(16, "", "", japanese, [], -1, 0, -1.0)
  let wide = @core.render_row(17, "", "", japanese, [], -1, 0, -1.0)
  assert_eq(row_text(narrow), " 📁 …本語aaaa ▶─")
  assert_eq(row_text(wide), " 📁 /日本語aaaa ▶")
}

///|
test "a decomposed accent occupies one cell and stays attached to its base" {
  let row = @core.render_row(11, "", "", "/xxe\u0301abc", [], -1, 0, -1.0)
  assert_eq(row_text(row), " 📁 …e\u0301abc ▶")
}

///|
test "Arabic letters occupy separate terminal cells even if the font joins them" {
  let row = @core.render_row(
    12,
    "model",
    "",
    "/repo/لا",
    [],
    14,
    200000,
    -1.0,
  )
  assert_eq(row_text(row), " 📁 …o/لا ▶─")
}

///|
test "growing a row restores one intact two-cell ZWJ emoji" {
  let path = "/abc👩‍🔬qrst"
  let at = fn(columns) {
    row_text(@core.render_row(columns, "", "", path, [], -1, 0, -1.0))
  }
  assert_eq(at(12), " 📁 …qrst ▶─")
  assert_eq(at(13), " 📁 …👩‍🔬qrst ▶")
  assert_eq(at(16), " 📁 /abc👩‍🔬qrst ▶")
}

///|
test "all runtime text is a single printable line" {
  let row = @core.render_row(
    90,
    "Opus\u0007\u202eX\u202c\u001b[31m",
    "",
    "~/a\r\nb\u2028c",
    ["topic\u2029end", "*1\u009b[3m", "", ""],
    -1,
    0,
    -1.0,
  )
  assert_true(
    row_text(row).has_prefix(
      " Opus X [31m > 📁 ~/a  b c > ⑂ topic end *1 [3m ▶",
    ),
  )
}
