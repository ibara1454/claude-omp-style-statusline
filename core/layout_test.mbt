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
    120,
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
test "paths use the available half, but a complete path needs no padding" {
  let path = "/abcdefghijklmnopqrst日本語abcdefghijklmnopqrst"
  let row = row_text(@core.render_row(92, "", "", path, [], -1, 0, -1.0))
  assert_true(
    row.has_prefix(" 📁 …hijklmnopqrst日本語abcdefghijklmnopqrst ▶"),
  )
  assert_eq(
    row_text(@core.render_row(120, "", "", path, [], -1, 0, -1.0)),
    " 📁 " + path + " ▶" + "─".repeat(67),
  )
}

///|
test "chips use their half in priority order and the path takes back freed space" {
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
  assert_eq(
    at(92),
    " ◕ xhigh > M > 📁 /abcdefghij > ⑂ b > ~$1.04 ▶" + "─".repeat(46),
  )
  assert_eq(
    at(81),
    " ◕ xhigh > M > 📁 …ghij > ⑂ b > ~$1.04 ▶" + "─".repeat(41),
  )
  assert_eq(
    at(79),
    " ◕ xhigh > M > 📁 /abcdefghij > ⑂ b ▶" + "─".repeat(42),
  )
  assert_eq(at(60), " ◕ xhigh > M > 📁 …bcdefghij ▶" + "─".repeat(30))
  assert_eq(at(48), " ◕ xhigh > 📁 …defghij ▶" + "─".repeat(24))
  assert_eq(at(40), " M > 📁 …bcdefghij ▶" + "─".repeat(20))
}

///|
test "a long repository and branch leave the odd column to the gauge" {
  let at = fn(git, cost) {
    row_text(
      @core.render_row(
        81, "", "", "~/work/checkout-service", git, 14, 272000, cost,
      ),
    )
  }
  let branch = "feature/checkout-retries"
  assert_eq(
    at([branch, "", "", ""], -1.0),
    " 📁 …vice > ⑂ feature/checkout-retries ▶─────14%" +
    "─".repeat(28) +
    "272K─",
  )
  assert_eq(
    at([branch, "*2", "+1", "?3"], 1.04),
    " 📁 ~/work/checkout-service > ~$1.04 ▶─────14%" +
    "─".repeat(30) +
    "272K─",
  )
}

///|
test "hiding a long branch expands the path instead of the window-only gauge" {
  let row = @core.render_row(
    100,
    "gpt-6-luna",
    "◌ unknown",
    "~/workspaces/claude-omp-style-statusline/pearlside",
    ["feature/status-line-context-width", "", "", ""],
    -1,
    272000,
    -1.0,
  )
  assert_eq(
    row_text(row),
    " ◌ unknown > gpt-6-luna > 📁 …atusline/pearlside ▶" +
    "─".repeat(45) +
    "272K─",
  )
}

///|
test "keep the smallest useful path suffix before falling back to just the gauge" {
  let at = fn(columns, path) {
    row_text(@core.render_row(columns, "", "", path, [], 14, 272000, -1.0))
  }
  let labels = "─14%──272K─"
  assert_eq(at(20, "checkout-service"), " 📁 …ce ▶" + labels)
  assert_eq(at(19, "checkout-service"), " 📁 …e ▶" + labels)
  assert_eq(at(19, "checkout-e\u0301"), " 📁 …e\u0301 ▶" + labels)
  assert_eq(at(19, "界"), " 📁 界 ▶" + labels)
  assert_eq(at(19, "checkout-界"), "──14%" + "─".repeat(9) + "272K─")
  assert_eq(
    at(18, "checkout-service"),
    "──14%" + "─".repeat(8) + "272K─",
  )
  assert_eq(at(11, ""), labels)
  let narrow = @core.render_row(10, "", "", "", [], 14, 272000, -1.0)
  assert_eq(row_text(narrow), "─".repeat(10))
  assert_eq(row_color(narrow, "─".repeat(9)), ("#303030", ""))
  assert_eq(row_text(@core.render_row(1, "", "", "", [], -1, 0, -1.0)), "─")
  assert_eq(at(0, "checkout-service"), "")
}

///|
test "cell clipping never keeps half of a Japanese wide character" {
  let japanese = "/日本語aaaa"
  let narrow = @core.render_row(32, "", "", japanese, [], -1, 0, -1.0)
  let wide = @core.render_row(34, "", "", japanese, [], -1, 0, -1.0)
  assert_eq(row_text(narrow), " 📁 …本語aaaa ▶" + "─".repeat(17))
  assert_eq(row_text(wide), " 📁 /日本語aaaa ▶" + "─".repeat(17))
}

///|
test "whole graphemes determine the actual path reservation" {
  let at = fn(columns, path) {
    row_text(@core.render_row(columns, "M", "", path, [], -1, 0, -1.0))
  }
  let jamo = "ᄀᄀᄀ" // One grapheme, six terminal cells.
  assert_eq(
    at(28, "/" + jamo + "abc"),
    " M > 📁 …abc ▶" + "─".repeat(14),
  )
  assert_eq(at(30, "/" + jamo), " 📁 /" + jamo + " ▶" + "─".repeat(17))
}

///|
test "a decomposed accent occupies one cell and stays attached to its base" {
  let row = @core.render_row(22, "", "", "/xxe\u0301abc", [], -1, 0, -1.0)
  assert_eq(row_text(row), " 📁 …e\u0301abc ▶" + "─".repeat(11))
}

///|
test "Arabic letters occupy separate terminal cells even if the font joins them" {
  let row = @core.render_row(
    22,
    "model",
    "",
    "/repo/لا",
    [],
    14,
    200000,
    -1.0,
  )
  assert_eq(row_text(row), " 📁 …o/لا ▶─14%──200K─")
}

///|
test "growing a row restores one intact two-cell ZWJ emoji" {
  let path = "/abc👩‍🔬qrst"
  let at = fn(columns) {
    row_text(@core.render_row(columns, "", "", path, [], -1, 0, -1.0))
  }
  assert_eq(at(24), " 📁 …qrst ▶" + "─".repeat(13))
  assert_eq(at(26), " 📁 …👩‍🔬qrst ▶" + "─".repeat(13))
  assert_eq(at(32), " 📁 /abc👩‍🔬qrst ▶" + "─".repeat(16))
}

///|
test "all runtime text is a single printable line" {
  let row = @core.render_row(
    180,
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
