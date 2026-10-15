# Security policy

Plugins run scripts inside the programs. The programs run them in a sandbox (no files, network, system or machine) and check
what they return, and the official list only downloads files from this site and checks their SHA-256. Still, please report:

- a plugin in this list that does something other than it says, or tries to get around the limits;
- a way for a script to escape the sandbox or to send controller commands;
- a way to make the programs install something that is not what the list says.

Use **GitHub's private vulnerability reporting** (Security tab → *Report a vulnerability*) or the contact in the profile
of [@michalsarna](https://github.com/michalsarna). A plugin that is found harmful is removed from the list at once and the
next list build drops it; people who installed it are told in the issue tracker.
