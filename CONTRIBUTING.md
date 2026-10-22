# Contributing

Thank you! There are three ways to help.

- **Report a problem** with a plugin: open an issue with the *Plugin bug* form. Say which plugin and version, in which program
  (and its version), and what you did.
- **Suggest a plugin** you would like: the *Plugin idea* form.
- **Send a plugin or a fix**: a pull request. Read the [guide for authors](docs/GUIDE.md) first.

## From zero to a pull request

The short way. Each step is explained in the [guide](docs/GUIDE.md).

1. **Start from a template.** Copy the one that fits from [`templates/`](templates) (`generator`, `importer`,
   `postprocessor` or `pack`) to a folder named like your plugin's `id`, for example `my-plugin`. The `id` in `plugin.json`
   must equal the folder name.
2. **Try it in a program.** Put the folder in the programs' plugins folder (Settings → Plugins… → *Open plugins folder*),
   press **Reload plugins**. A plugin with a mistake is listed with the reason. ([Guide, section 1](docs/GUIDE.md#1-your-first-plugin-in-five-minutes))
3. **Fill in the files.** `plugin.json` (with `license`), a `README.md` (what it does, one example), a `CHANGELOG.md` with
   a first line, and for an importer a small `tests/sample.<extension>`.
4. **Run the check.** Without a program: `cargo run -p base-core --example check_plugins -- <folder with your plugin folder>`
   in a checkout of [baseCreator](https://github.com/michalsarna/baseCreator) (the version in
   [`.baseCreator-version`](.baseCreator-version)). The CI runs the same. ([Guide, section 8](docs/GUIDE.md#8-testing))
5. **Open the pull request.** Fork this repository, add the folder under `plugins/`, push, and open a pull request. The form
   is a checklist: tick what is true. One plugin per pull request.
6. **Wait for the CI and the review.** If the CI is red, the log says which plugin and which script failed. A reviewer reads
   the scripts, then merges. After the merge the list is rebuilt and published; everybody gets your plugin in
   *Settings → Plugins… → Official plugins → Check for updates*, with no new version of the programs.

Not sure yet? Open a *Plugin idea* issue first and say what you plan.

Changing a plugin that is already on the list: the same way, and **raise `version`** (and add a line to `CHANGELOG.md`); the
CI refuses a changed plugin with an old version.

## A pull request (the rules)

1. Fork, create a branch, change or add a folder under `plugins/`. The folder is named like the plugin's `id`.
2. **Raise `version` in `plugin.json`** when you change anything in a plugin, and add a line to its `CHANGELOG.md`.
3. Run the check (see the guide, section "Testing") — the CI runs it too and must be green.
4. Fill in the pull request form. One plugin per pull request makes review quick.

What is reviewed: that it does what it says, that the scripts are readable and small, that it respects the
[rules](docs/GUIDE.md#9-rules-and-safety), that the licence is clear, and that the numbers it makes are sensible for a machine.

Plugins for one program are welcome (`programs` in the manifest); the list shows everything to everybody.

## Problems in the programs

A bug in LightCreator, MillCreator or PenCreator or in the Plugins window itself belongs to
that program's repository; the plugin system is in [baseCreator](https://github.com/michalsarna/baseCreator/issues).

## Security

Found a plugin that does something it should not, or a way around the sandbox? Please do **not** open a public issue; see
[SECURITY.md](SECURITY.md).
