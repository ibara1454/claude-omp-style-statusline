///|
test "format_path shortens only paths within the supplied home" {
  inspect(@core.format_path("/home/me", "/home/me"), content="~")
  inspect(
    @core.format_path("/home/me/src/app", "/home/me/"),
    content="~/src/app",
  )
  inspect(
    @core.format_path("/home/me-too/src", "/home/me"),
    content="/home/me-too/src",
  )
  inspect(@core.format_path("/somewhere/src", ""), content="/somewhere/src")
}

///|
test "format_path keeps relative paths under OMP project and scratch roots" {
  let home = "/home/me"
  inspect(
    @core.format_path("/home/me/Projects/team/app", home),
    content="team/app",
  )
  inspect(
    @core.format_path("/home/me/repos/team/app", home),
    content="team/app",
  )
  inspect(@core.format_path("/work/team/app", home), content="team/app")
  inspect(
    @core.format_path("/workshop/team/app", home),
    content="/workshop/team/app",
  )
  inspect(@core.format_path("/home/me/Projects", home), content="~/Projects")
  inspect(@core.format_path("/tmp", home), content="/tmp")
  inspect(@core.format_path("/tmp/team/app", home), content="team/app")
  inspect(@core.format_path("/var/tmp/team/app", home), content="team/app")
  inspect(@core.format_path("/private/tmp/team/app", home), content="team/app")
  inspect(
    @core.format_path("/private/var/tmp/team/app", home),
    content="team/app",
  )
  inspect(@core.format_path("/home/me/tmp/team/app", home), content="team/app")
  inspect(
    @core.format_path("/tmp-example/team/app", home),
    content="/tmp-example/team/app",
  )
}

///|
test "parse_status shows normal and unborn branches and labels detached HEAD" {
  assert_eq(@core.parse_status("# branch.head feature/日本語\u0000"), [
    "feature/日本語", "", "", "",
  ])
  assert_eq(
    @core.parse_status("# branch.oid (initial)\u0000# branch.head new\u0000"),
    ["new", "", "", ""],
  )
  assert_eq(@core.parse_status("# branch.head (detached)\u0000"), [
    "detached", "", "", "",
  ])
}

///|
test "parse_status hides unavailable or incomplete porcelain" {
  assert_eq(@core.parse_status(""), [])
  assert_eq(@core.parse_status("# branch.head partial"), [])
  assert_eq(@core.parse_status("# branch.head \u0000"), [])
  assert_eq(@core.parse_status("? no-branch\u0000"), [])
}

///|
test "parse_status counts staged paths in the index column" {
  assert_eq(
    @core.parse_status(
      "# branch.head main\u00001 M. N... 100644 100644 100644 abc def staged file\u0000",
    ),
    ["main", "", "+1", ""],
  )
}

///|
test "parse_status counts unstaged paths independently of staged paths" {
  let raw = "# branch.head main\u0000" +
    "1 .M N... 100644 100644 100644 abc def only unstaged\u0000" +
    "1 MM N... 100644 100644 100644 abc def also staged\u0000"
  assert_eq(@core.parse_status(raw), ["main", "*2", "+1", ""])
}

///|
test "parse_status counts NUL-terminated untracked paths without treating newlines as records" {
  let raw = "# branch.head main\u0000" +
    "? a file with spaces\u0000? a name with\n? what looks like a record\u0000" +
    "! ignored\u0000"
  assert_eq(@core.parse_status(raw), ["main", "", "", "?2"])
}

///|
test "parse_status counts renames and conflicts once per dirty column and skips rename source paths" {
  let rename = "2 R. N... 100644 100644 100644 abc def R100 new name\u0000"
  let branch = "# branch.head main\u0000"
  let conflict = "u UU N... 100644 100644 100644 100644 abc def abc conflict\u0000"
  let raw = branch +
    rename +
    "? old name\u0000" +
    rename +
    "\nold name\u0000" +
    conflict
  assert_eq(@core.parse_status(raw), ["main", "*1", "+3", ""])
  assert_eq(@core.parse_status(branch + rename), [])
}

///|
test "path and branch display neutralize terminal and bidi controls without splitting emoji" {
  inspect(
    @core.format_path(
      "/home/me/Projects/team\nsale\u001b[31m\u009b\u2028/a\u202eb\u202c👩‍💻",
      "/home/me",
    ),
    content="team sale [31m  /ab👩‍💻",
  )
  assert_eq(
    @core.parse_status(
      "# branch.head topic\u0007/\u200f日本語\u2029👩‍💻\u0000",
    ),
    ["topic /日本語 👩‍💻", "", "", ""],
  )
  assert_eq(@core.parse_status("# branch.head \u202e\u202c\u0000"), [])
}
