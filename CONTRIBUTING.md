# Contributing

Thank you! There are three ways to help.

- **Report a problem** with a plugin: open an issue with the *Plugin bug* form. Say which plugin and version, in which program
  (and its version), and what you did.
- **Suggest a plugin** you would like: the *Plugin idea* form.
- **Send a plugin or a fix**: a pull request. Read the [guide for authors](docs/GUIDE.md) first.

## A pull request

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
