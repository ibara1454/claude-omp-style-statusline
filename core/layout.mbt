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
fn terminal_cells(text : String) -> Int32 {
  for unit in text.code_units() {
    if unit > 127 {
      // Terminals allocate cells per grapheme, not per typographic ligature.
      let mut cells = 0
      for cluster in @segmentation.graphemes(text) {
        cells += @unicodewidth.str_width(cluster)
      }
      return cells
    }
  }
  text.length()
}

///|
fn chip_label_cells(label : String, prefix_cells : Int32) -> Int32 {
  if label.is_empty() {
    0
  } else {
    prefix_cells + terminal_cells(label)
  }
}

///|
fn fit_chip(cells : Int32, available : Int32) -> Int32 {
  if cells <= available {
    cells
  } else {
    0
  }
}

///|
// Keep the shortest useful suffix if none fits; callers decide whether to hide it.
fn clip_path(path : String, cells : Int32, limit : Int32) -> (Int32, Int32) {
  if cells <= limit {
    return (0, cells)
  }
  let mut remaining = cells
  let mut start = 0
  for cluster in @segmentation.graphemes(path) {
    let next = remaining - @unicodewidth.str_width(cluster)
    if next == 0 {
      break
    }
    remaining = next
    start += cluster.length()
    if remaining < limit {
      break
    }
  }
  if cells - remaining <= 1 {
    (0, cells)
  } else {
    (start, remaining + 1)
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
pub fn render_row(
  columns : Int32,
  model : String,
  effort : String,
  path : String,
  git : FixedArray[String],
  percent : Int32,
  window : Int32,
  cost_usd : Double,
) -> FixedArray[String] {
  guard columns > 0 else { return [] }
  let effort = match effort {
    "low" => "○ low"
    "medium" => "◔ medium"
    "high" => "◑ high"
    "xhigh" => "◕ xhigh"
    "max" => "● max"
    _ => sanitize_status_text(effort)
  }
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

  let window = window_label(window)
  let chip_budget = (columns / 2)
    .min(columns - gauge_min_width(percent, window))
    .max(0)
  let path_width = terminal_cells(path)
  let path_chrome = if path_width > 0 { 6 } else { 0 }
  let effort_cells = chip_label_cells(effort, 3)
  let model_cells = chip_label_cells(model, 3)
  let git_cells = if git_label_cells > 0 { git_label_cells + 3 } else { 0 }
  let cost_cells = chip_label_cells(cost, 3)
  let all_chips = effort_cells + model_cells + git_cells + cost_cells
  let path_budget = chip_budget - path_chrome
  // Measure the actual suffix: a five-cell allowance need not use five cells.
  let preferred_limit = (path_budget - all_chips).max(5)
  let (offset, reserved) = clip_path(path, path_width, preferred_limit)
  let available = path_budget - reserved
  let effort_cells = fit_chip(effort_cells, available)
  let model_cells = fit_chip(model_cells, available - effort_cells)
  let available = available - effort_cells - model_cells
  let git_cells = fit_chip(git_cells, available)
  let cost_cells = fit_chip(cost_cells, available - git_cells)
  let other_cells = effort_cells + model_cells + git_cells + cost_cells
  let limit = path_budget - other_cells
  let (path_offset, path_cells) = if limit == preferred_limit {
    (offset, reserved)
  } else {
    clip_path(path, path_width, limit)
  }
  let show_path = path_cells > 0 && path_cells <= limit
  let group_cells = other_cells +
    (if show_path { path_cells + path_chrome } else { 0 })

  let out : Array[String] = []
  if effort_cells > 0 {
    begin_chip(out)
    add_span(out, effort, "#af5fff", ChipBg)
  }
  if model_cells > 0 {
    begin_chip(out)
    add_span(out, model, "#af5fff", ChipBg)
  }
  if show_path {
    begin_chip(out)
    let label = if path_offset == 0 {
      "📁 " + path
    } else {
      "📁 …" + path[path_offset:].to_owned()
    }
    add_span(out, label, "#eeeeee", ChipBg)
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
  if group_cells > 0 {
    add_span(out, " ", SeparatorFg, ChipBg)
    add_span(out, "▶", SeparatorFg, "")
  }
  append_gauge(out, columns - group_cells, percent, window)
  FixedArray::from_array(out)
}
