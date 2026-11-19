///|
fn add_span(
  out : Array[String],
  text : String,
  fg : String,
  bg : String,
) -> Unit {
  if text != "" {
    out.push(text)
    out.push(fg)
    out.push(bg)
  }
}

///|
fn window_label(tokens : Int32) -> String {
  if tokens <= 0 {
    return ""
  }
  if tokens < 1000 {
    return tokens.to_string()
  }
  let (unit, suffix) = if tokens >= 1000000000 {
    (1000000000, "B")
  } else if tokens >= 1000000 {
    (1000000, "M")
  } else {
    (1000, "K")
  }
  let scaled = tokens.to_double() / unit.to_double()
  if scaled < 10.0 {
    let tenths = (scaled * 10.0).round().to_int()
    if tenths % 10 != 0 {
      return (tenths / 10).to_string() +
        "." +
        (tenths % 10).to_string() +
        suffix
    }
  }
  scaled.round().to_int().to_string() + suffix
}

///|
fn gauge_min_width(percent : Int32, window : String) -> Int32 {
  if window == "" {
    return 0
  }
  window.length() +
  2 +
  (if percent < 0 { 0 } else { percent.to_string().length() + 3 })
}

///|
fn append_gauge(
  out : Array[String],
  cells : Int32,
  percent : Int32,
  window : String,
) -> Unit {
  if cells <= 0 {
    return
  }
  let accent = "#af5fff"
  let dim = "#303030"
  if window == "" && percent < 0 {
    add_span(out, "─".repeat(cells), accent, "")
    return
  }
  let labelled = window != "" && cells >= gauge_min_width(percent, window)
  let scale = if labelled { cells - window.length() - 1 } else { cells }
  let pct = percent.clamp(min=0, max=100)
  let used = (scale.to_double() * pct.to_double() / 100.0)
    .round()
    .to_int()
    .clamp(min=1, max=scale)
  let label = if labelled && percent >= 0 { pct.to_string() + "%" } else { "" }
  // Keep one cell of rule on either side of the percentage when the scale is full.
  let before = if label == "" {
    used
  } else {
    used.min(scale - label.length() - 1)
  }
  add_span(out, "─".repeat(before), accent, "")
  add_span(out, label, accent, "")
  let after = before + label.length()
  if after < used {
    add_span(out, "─".repeat(used - after), accent, "")
  }
  add_span(out, "─".repeat(scale - used.max(after)), dim, "")
  if labelled {
    add_span(out, window, "#936fb7", "")
    add_span(out, "─", dim, "")
  }
}

///|
extern "js" fn fixed_cents(usd : Double) -> String =
  #| usd => usd.toFixed(2)

///|
fn cost_label(usd : Double) -> String {
  if usd >= 0.0 && usd.is_finite() {
    "~$" + fixed_cents(usd)
  } else {
    ""
  }
}
