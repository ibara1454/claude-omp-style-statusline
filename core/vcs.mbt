///|
// shortcut: only known POSIX scratch roots, extend the host inputs for custom temp directories.
let other_scratch_roots : FixedArray[String] = [
  "/var/tmp", "/private/tmp", "/private/var/tmp",
]

///|
fn relative_to_path_root(path : StringView, root : StringView) -> StringView? {
  if path.strip_prefix(root) is Some(suffix) {
    if suffix.is_empty() {
      Some(suffix)
    } else {
      suffix.strip_prefix("/")
    }
  } else {
    None
  }
}

///|
fn is_status_line_control(c : Char) -> Bool {
  c.is_control() || c is ('\u2028' | '\u2029')
}

///|
fn is_status_bidi_control(c : Char) -> Bool {
  c
  is ('\u061c'
  | '\u200e'..<='\u200f'
  | '\u202a'..<='\u202e'
  | '\u2066'..<='\u206f')
}

///|
fn sanitize_status_text(text : StringView) -> String {
  guard text.find_by(c => is_status_line_control(c) || is_status_bidi_control(c))
    is Some(start) else {
    return text.to_owned()
  }
  let out = StringBuilder(capacity=text.length())
  out.write_view(text[:start])
  for c in text[start:] {
    if !is_status_bidi_control(c) {
      out.write_char(if is_status_line_control(c) { ' ' } else { c })
    }
  }
  out.to_string()
}

///|
fn shorten_vcs_path(cwd : String, home : String) -> StringView {
  let home_path = if home.is_empty() {
    None
  } else {
    relative_to_path_root(cwd[:], home.trim_end(chars="/"))
  }
  let mut scratch = relative_to_path_root(cwd[:], "/tmp")
  if scratch is None && home_path is Some(path) {
    scratch = relative_to_path_root(path, "tmp")
  }
  if scratch is None {
    for root in other_scratch_roots {
      if relative_to_path_root(cwd[:], root) is Some(path) {
        scratch = Some(path)
        break
      }
    }
  }
  if scratch is Some(path) {
    if !path.is_empty() {
      return path
    }
  } else {
    if home_path is Some(path) {
      if path.strip_prefix("Projects/") is Some(rest) && !rest.is_empty() {
        return rest
      }
      if path.strip_prefix("repos/") is Some(rest) && !rest.is_empty() {
        return rest
      }
    }
    if cwd.strip_prefix("/work/") is Some(path) && !path.is_empty() {
      return path
    }
  }
  match home_path {
    Some(path) => if path.is_empty() { "~" } else { "~/\{path}" }
    None => cwd[:]
  }
}

///|
pub fn format_path(cwd : String, home : String) -> String {
  sanitize_status_text(shorten_vcs_path(cwd, home))
}

///|
pub fn parse_status(raw : String) -> FixedArray[String] {
  if !raw.has_suffix("\u0000") {
    return []
  }
  let mut branch : StringView = ""
  let mut staged = 0
  let mut unstaged = 0
  let mut untracked = 0
  let mut needs_origin = false
  for record in raw.split("\u0000") {
    // A rename/copy's second NUL-delimited field is a path, not another record.
    if needs_origin {
      if record.is_empty() {
        return []
      }
      needs_origin = false
      continue
    }
    if record.strip_prefix("# branch.head ") is Some(name) {
      branch = name
    }
    if record is ['1' | '2', ' ', x, y, ' ', ..] {
      needs_origin = record.has_prefix("2 ")
      if x != '.' {
        staged += 1
      }
      if y != '.' {
        unstaged += 1
      }
    } else if record.has_prefix("u ") {
      // Unmerged XY describes merge heads, not staged changes.
      unstaged += 1
    } else if record.has_prefix("? ") {
      untracked += 1
    }
  }
  let label = if branch.equal_to_string("(detached)") {
    "detached"
  } else {
    sanitize_status_text(branch)
  }
  if label.is_blank() {
    return []
  }
  [
    label,
    if unstaged == 0 {
      ""
    } else {
      "*\{unstaged}"
    },
    if staged == 0 {
      ""
    } else {
      "+\{staged}"
    },
    if untracked == 0 {
      ""
    } else {
      "?\{untracked}"
    },
  ]
}
