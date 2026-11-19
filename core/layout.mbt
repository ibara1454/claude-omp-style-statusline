///|
const ChipBg = "#121212"

///|
const SeparatorFg = "#767676"

///|
fn begin_chip(out : Array[String]) -> Unit {
  let separator = if out.is_empty() { " " } else { " > " }
  add_span(out, separator, SeparatorFg, ChipBg)
}

///|
fn chip_label_cells(label : String, prefix_cells : Int32) -> Int32 {
  if label.is_empty() {
    0
  } else {
    prefix_cells + @unicodewidth.str_width(label)
  }
}

///|
fn clip_path(path : String, cells : Int32, limit : Int32) -> (String, Int32) {
  if cells <= limit {
    (path, cells)
  } else {
    let display = @displaytext.DisplayText(path)
    let cut = @displaytext.DisplayPosition::new(column=cells - limit + 1)
    let start = display.textual_position_at_or_after(cut)
    let dropped = display.display_position(start).column()
    ("…\{display.view(start, display.end())}", cells - dropped + 1)
  }
}

///|
fn append_git_count(
  out : Array[String],
  label : String,
  fg : String,
  leading_space : Bool,
) -> Unit {
  if !label.is_empty() {
    let text = if leading_space { " " + label } else { label }
    add_span(out, text, fg, ChipBg)
  }
}

///|
fn row_overflow(
  columns : Int32,
  group_cells : Int32,
  chips : Int32,
  gauge_cells : Int32,
) -> Int32 {
  let gap = if chips == 1 &&
    gauge_cells > 0 &&
    group_cells + gauge_cells > columns {
    1 // Keep the final chip and fall back to an unlabelled rule.
  } else {
    gauge_cells
  }
  group_cells + gap - columns
}

///|
pub fn render_row(
  columns : Int32,
  model : String,
  path : String,
  git : FixedArray[String],
  percent : Int32,
  window : Int32,
  cost_usd : Double,
) -> FixedArray[String] {
  guard columns > 0 else { return [] }
  let model = sanitize_status_text(model)
  let path = sanitize_status_text(path)
  let (branch, unstaged, staged, untracked) = match git {
    [branch, unstaged, staged, untracked] =>
      (
        sanitize_status_text(branch),
        sanitize_status_text(unstaged),
        sanitize_status_text(staged),
        sanitize_status_text(untracked),
      )
    _ => ("", "", "", "")
  }
  let cost = cost_label(cost_usd)
  let mut model_cells = chip_label_cells(model, 5)
  let path_width = @unicodewidth.str_width(path)
  let path_limit = path_width.min(40)
  let path_cells = if path.is_empty() { 0 } else { path_limit + 6 }
  let branch_cells = chip_label_cells(branch, 2)
  let unstaged_cells = chip_label_cells(
    unstaged,
    if branch_cells > 0 {
      1
    } else {
      0
    },
  )
  let staged_cells = chip_label_cells(
    staged,
    if branch_cells + unstaged_cells > 0 {
      1
    } else {
      0
    },
  )
  let untracked_cells = chip_label_cells(
    untracked,
    if branch_cells + unstaged_cells + staged_cells > 0 {
      1
    } else {
      0
    },
  )
  let git_label_cells = branch_cells +
    unstaged_cells +
    staged_cells +
    untracked_cells
  let mut git_cells = if git_label_cells == 0 { 0 } else { git_label_cells + 3 }
  let mut cost_cells = chip_label_cells(cost, 3)

  let window = window_label(window)
  let gauge_cells = gauge_min_width(percent, window)
  // Each chip accounts for three cells of group chrome: either the outer
  // two spaces and cap, or the separator and its spaces.
  let mut group_cells = model_cells + path_cells + git_cells + cost_cells
  let mut chips = (model_cells > 0).to_int() +
    (path_cells > 0).to_int() +
    (git_cells > 0).to_int() +
    (cost_cells > 0).to_int()
  let overflow = row_overflow(columns, group_cells, chips, gauge_cells)
  // The eight-cell path floor includes the folder and its space.
  let shrink = overflow.min(path_limit - 5).max(0)
  let (path, clipped_width) = clip_path(path, path_width, path_limit - shrink)
  group_cells -= path_limit - clipped_width

  if cost_cells > 0 &&
    row_overflow(columns, group_cells, chips, gauge_cells) > 0 {
    group_cells -= cost_cells
    cost_cells = 0
    chips -= 1
  }
  if git_cells > 0 && row_overflow(columns, group_cells, chips, gauge_cells) > 0 {
    group_cells -= git_cells
    git_cells = 0
    chips -= 1
  }
  if model_cells > 0 &&
    row_overflow(columns, group_cells, chips, gauge_cells) > 0 {
    group_cells -= model_cells
    model_cells = 0
    chips -= 1
  }
  guard chips > 0 && row_overflow(columns, group_cells, chips, gauge_cells) <= 0 else {
    return []
  }

  let out : Array[String] = []
  if model_cells > 0 {
    begin_chip(out)
    add_span(out, "◕ " + model, "#af5fff", ChipBg)
  }
  if path_cells > 0 {
    begin_chip(out)
    add_span(out, "📁 " + path, "#eeeeee", ChipBg)
  }
  if git_cells > 0 {
    begin_chip(out)
    if branch_cells > 0 {
      let fg = if git_label_cells == branch_cells {
        "#5faf5f"
      } else {
        "#ffaf5f"
      }
      add_span(out, "⑂ " + branch, fg, ChipBg)
    }
    append_git_count(out, unstaged, "#d7af5f", branch_cells > 0)
    append_git_count(out, staged, "#87af5f", branch_cells + unstaged_cells > 0)
    append_git_count(
      out,
      untracked,
      "#bcbcbc",
      branch_cells + unstaged_cells + staged_cells > 0,
    )
  }
  if cost_cells > 0 {
    begin_chip(out)
    add_span(out, cost, "#d7af87", ChipBg)
  }
  add_span(out, " ", SeparatorFg, ChipBg)
  add_span(out, "▶", SeparatorFg, "")
  append_gauge(out, columns - group_cells, percent, window)
  FixedArray::from_array(out)
}
